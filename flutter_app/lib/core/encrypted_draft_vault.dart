import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'draft_vault.dart';

class EncryptedDraftVault implements DraftVault {
  EncryptedDraftVault({
    this.directory,
    Future<String?> Function(String)? readKey,
    Future<void> Function(String, String)? writeKey,
  }) : _readKey = readKey ?? _readProtectedKey,
       _writeKey = writeKey ?? _writeProtectedKey;
  final Directory? directory;
  final Future<String?> Function(String) _readKey;
  final Future<void> Function(String, String) _writeKey;
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  static Future<String?> _readProtectedKey(String key) =>
      _secure.read(key: key);
  static Future<void> _writeProtectedKey(String key, String value) =>
      _secure.write(key: key, value: value);
  final _cipher = AesGcm.with256bits();
  final _keys = <String, Future<SecretKey>>{};

  String _hash(String value) =>
      digest.sha256.convert(utf8.encode(value)).toString();
  Future<Directory> _root(String scope) async {
    final base = directory ?? await getApplicationSupportDirectory();
    return Directory('${base.path}/draft-vault/${_hash(scope)}')
        .create(recursive: true);
  }

  Future<SecretKey> _key(String scope, {required bool existing}) async {
    final pending = _keys.putIfAbsent(scope, () async {
      final name = 'draft-key-v1-${_hash(scope)}';
      final stored = await _readKey(name);
      if (stored != null) return SecretKey(base64Decode(stored));
      if (existing) throw StateError('Saved data key unavailable');
      final key = await _cipher.newSecretKey();
      await _writeKey(name, base64Encode(await key.extractBytes()));
      return key;
    });
    try {
      return await pending;
    } catch (_) {
      // A temporary Keystore failure must not poison every subsequent retry.
      if (identical(_keys[scope], pending)) _keys.remove(scope);
      rethrow;
    }
  }

  Future<Uint8List?> _read(String scope, String name) async {
    final file = File('${(await _root(scope)).path}/${_hash(name)}');
    if (!await file.exists()) return null;
    final raw = await file.readAsBytes();
    final box = SecretBox.fromConcatenation(
      raw,
      nonceLength: 12,
      macLength: 16,
    );
    return Uint8List.fromList(
      await _cipher.decrypt(
        box,
        secretKey: await _key(scope, existing: true),
        aad: utf8.encode('$scope:$name'),
      ),
    );
  }

  Future<void> _write(String scope, String name, List<int> bytes) async {
    final root = await _root(scope);
    final target = File('${root.path}/${_hash(name)}');
    final key = await _key(scope, existing: await target.exists());
    final box = await _cipher.encrypt(
      bytes,
      secretKey: key,
      aad: utf8.encode('$scope:$name'),
    );
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(box.concatenation(), flush: true);
    await temp.rename(
      target.path,
    ); // Atomic replacement on Android's filesystem.
  }

  @override
  Future<Map<String, dynamic>?> load(String scope) async {
    final bytes = await _read(scope, 'state');
    if (bytes == null) return null;
    final state = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (state['version'] != 1) throw StateError('Unsupported draft format');
    return state;
  }

  @override
  Future<void> save(String scope, Map<String, dynamic> state) =>
      _write(scope, 'state', utf8.encode(jsonEncode(state)));
  @override
  Future<void> putFile(String scope, String id, Uint8List bytes) =>
      _write(scope, 'file:$id', bytes);
  @override
  Future<Uint8List> readFile(String scope, String id) async =>
      await _read(scope, 'file:$id') ??
      (throw StateError('Saved attachment unavailable'));
  @override
  Future<void> removeFile(String scope, String id) async {
    final file = File('${(await _root(scope)).path}/${_hash('file:$id')}');
    if (await file.exists()) await file.delete();
  }
}
