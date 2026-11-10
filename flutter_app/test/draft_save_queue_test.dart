import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/draft_save_queue.dart';
import 'package:hervoice/core/draft_vault.dart';

class SlowVault implements DraftVault {
  final writes = <(String, int)>[];
  final release = Completer<void>();
  bool failFirst = false;
  @override
  Future<void> save(String scope, Map<String, dynamic> state) async {
    writes.add((scope, state['revision'] as int));
    if (writes.length == 1) {
      await release.future;
      if (failFirst) throw StateError('storage full');
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String scope) async => null;
  @override
  Future<void> putFile(String scope, String id, Uint8List bytes) async {}
  @override
  Future<Uint8List> readFile(String scope, String id) async => Uint8List(0);
  @override
  Future<void> removeFile(String scope, String id) async {}
}

void main() {
  test(
    '200 edits while disk is busy retain latest state using two writes',
    () async {
      final vault = SlowVault(), saves = <Future<void>>[];
      final queue = DraftSaveQueue(vault);
      for (var i = 0; i < 200; i++) {
        saves.add(queue.save('account-one', {'revision': i}));
      }
      expect(vault.writes, [('account-one', 0)]);
      var flushed = false;
      final flush = queue
          .save('account-one', {'revision': 200})
          .then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(flushed, false);
      vault.release.complete();
      await Future.wait([...saves, flush]);
      expect(vault.writes, [('account-one', 0), ('account-one', 200)]);
      expect(flushed, true);
    },
  );

  test(
    'account boundaries are never coalesced and a failed write can recover',
    () async {
      final vault = SlowVault()..failFirst = true;
      final queue = DraftSaveQueue(vault);
      final first = queue.save('one', {'revision': 1});
      final failed = expectLater(first, throwsStateError);
      final second = queue.save('two', {'revision': 2});
      final third = queue.save('one', {'revision': 3});
      vault.release.complete();
      await failed;
      await Future.wait([second, third, queue.idle]);
      expect(vault.writes, [('one', 1), ('two', 2), ('one', 3)]);
    },
  );
}
