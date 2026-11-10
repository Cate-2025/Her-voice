import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';
import 'package:hervoice/core/encrypted_draft_vault.dart';

void main() {
  late Directory directory;
  late Map<String, String> keys;
  EncryptedDraftVault vault() => EncryptedDraftVault(
    directory: directory,
    readKey: (key) async => keys[key],
    writeKey: (key, value) async {
      keys[key] = value;
    },
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hervoice-vault-');
    keys = {};
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('encrypted drafts and bytes survive restart, isolate accounts, reject missing keys', () async {
    final storage = vault();
    await storage.save('server|one', {
      'version': 1,
      'private': 'fictional sensitive narrative',
    });
    await storage.putFile(
      'server|one',
      'attachment',
      Uint8List.fromList(utf8.encode('private attachment')),
    );
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      expect(
        utf8.decode(file.readAsBytesSync(), allowMalformed: true),
        isNot(contains('private')),
      );
    }
    final reopened = vault();
    expect(
      (await reopened.load('server|one'))!['private'],
      'fictional sensitive narrative',
    );
    expect(await reopened.load('server|two'), isNull);
    expect(
      utf8.decode(await reopened.readFile('server|one', 'attachment')),
      'private attachment',
    );
    keys.clear();
    await expectLater(vault().load('server|one'), throwsA(isA<StateError>()));
  });

  test(
    'temporary key read failure can be retried without restarting',
    () async {
      await vault().save('scope', {'version': 1, 'private': 'Keep me'});
      var fail = true;
      var writes = 0;
      final reopened = EncryptedDraftVault(
        directory: directory,
        readKey: (key) async {
          if (fail) {
            fail = false;
            throw StateError('Temporarily unavailable');
          }
          return keys[key];
        },
        writeKey: (key, value) async {
          writes++;
        },
      );
      await expectLater(reopened.load('scope'), throwsStateError);
      expect((await reopened.load('scope'))!['private'], 'Keep me');
      expect(writes, 0);
    },
  );

  test(
    'temporary key write failure can be retried without restarting',
    () async {
      var fail = true;
      final storage = EncryptedDraftVault(
        directory: directory,
        readKey: (key) async => keys[key],
        writeKey: (key, value) async {
          if (fail) {
            fail = false;
            throw StateError('Temporarily unavailable');
          }
          keys[key] = value;
        },
      );
      final state = {'version': 1, 'private': 'Keep me'};
      await expectLater(storage.save('scope', state), throwsStateError);
      await storage.save('scope', state);
      expect(await vault().load('scope'), state);
    },
  );

  test('modified ciphertext cannot be loaded', () async {
    await vault().save('scope', {
      'version': 1,
      'private': 'must not be modified',
    });
    final name = digest.sha256.convert(utf8.encode('state')).toString();
    final file = directory
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere((f) => f.path.endsWith(name));
    final bytes = await file.readAsBytes();
    bytes[15] ^= 1;
    await file.writeAsBytes(bytes);
    await expectLater(vault().load('scope'), throwsA(anything));
  });

  test('lost create response recovers same operation and encrypted attachment after restart', () async {
    var account = 'one', fail = true;
    final operations = <String>[];
    var uploads = 0;
    http.Response json(Object value) => http.Response(jsonEncode(value), 200);
    ConnectedStore store() => ConnectedStore(
      ApiClient(
        'http://test/api/v1',
        client: MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/login')) return json({'access_token': 'test'});
          if (path.endsWith('/me')) {
            return json({'id': account, 'role': 'student'});
          }
          if (path.endsWith('/mine') || path.endsWith('/notifications')) {
            return json([]);
          }
          if (path.endsWith('/drafts')) {
            operations.add(r.body);
            if (fail) {
              fail = false;
              throw http.ClientException('lost response');
            }
            return json({'id': 'saved-report'});
          }
          if (r.method == 'PUT') {
            uploads++;
            expect(utf8.decode(r.bodyBytes), '%PDF-fixture');
            return json({});
          }
          return json({
            'id': 'saved-report',
            'status': 'submitted',
            'subject_staff_ref': 'Fictional staff',
            'created_at': '2026-10-17T12:00:00Z',
            'timeline': [
              {
                'occurred_at': '2026-10-16T12:00:00Z',
                'narrative': 'Fictional incident',
              },
            ],
            'evidence': [],
          });
        }),
      ),
      vault: vault(),
    );
    final first = store();
    await first.login('one', 'fictional');
    final draft = first.startDraft()
      ..subject = 'Fictional staff'
      ..narrative = 'Original incident'
      ..occurredAt = DateTime(2026, 10, 16);
    await first.addAttachment(
      draft,
      'example.pdf',
      Uint8List.fromList(utf8.encode('%PDF-fixture')),
    );
    await first.flushDrafts();
    await expectLater(first.submit(), throwsA(isA<ApiException>()));
    first.dispose();
    final next = store();
    account = 'two';
    await next.login('two', 'fictional');
    expect(next.drafts, isEmpty);
    account = 'one';
    await next.login('one', 'fictional');
    expect(next.submissionPending, true);
    expect(next.active!.attachments.single.name, 'example.pdf');
    await next.submit();
    expect(operations.length, 2);
    expect(operations[0], operations[1]);
    expect(uploads, 1);
    expect(next.drafts, isEmpty);
    next.dispose();
    final third = store();
    await third.login('one', 'fictional');
    expect(third.drafts, isEmpty);
    third.dispose();
  });

  test('storage failure blocks sending a new submission', () async {
    var creates = 0;
    http.Response json(Object value) => http.Response(jsonEncode(value), 200);
    final store = ConnectedStore(
      ApiClient(
        'http://test',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'access_token': 'test'});
          }
          if (r.url.path.endsWith('/me')) {
            return json({'id': 'one', 'role': 'student'});
          }
          if (r.url.path.endsWith('/drafts')) creates++;
          return json([]);
        }),
      ),
      vault: FailingVault(directory),
    );
    await store.login('one', 'fictional');
    store.startDraft()
      ..subject = 'Fictional staff'
      ..narrative = 'Keep local'
      ..occurredAt = DateTime(2026, 10, 17);
    await expectLater(store.submit(), throwsA(isA<ApiException>()));
    expect(creates, 0);
    expect(store.draftStorageStatus, contains('could not be saved'));
    store.dispose();
  });

  test(
    'sign out hides but retains encrypted drafts for same account',
    () async {
      http.Response json(Object v) => http.Response(jsonEncode(v), 200);
      final client = ApiClient(
        'http://test',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'access_token': 'test'});
          }
          if (r.url.path.endsWith('/me')) {
            return json({'id': 'one', 'role': 'student'});
          }
          return json([]);
        }),
      );
      final store = ConnectedStore(client, vault: vault());
      await store.login('one', 'fictional');
      store.startDraft().narrative = 'Keep me encrypted';
      await store.flushDrafts();
      store.signOut();
      expect(store.drafts, isEmpty);
      await store.login('one', 'fictional');
      expect(store.drafts.single.narrative, 'Keep me encrypted');
      store.dispose();
    },
  );
}

class FailingVault extends EncryptedDraftVault {
  FailingVault(Directory directory) : super(directory: directory);
  @override
  Future<void> save(String scope, Map<String, dynamic> state) async {
    throw FileSystemException('fictional storage full');
  }
}
