import 'dart:async';

import 'draft_vault.dart';

/// Serialises writes and coalesces queued snapshots for the same account scope.
/// An active write is never changed. Each caller completes only after its
/// snapshot, or a newer snapshot in that scope, has been saved successfully.
class DraftSaveQueue {
  DraftSaveQueue(this.vault);
  final DraftVault vault;
  final _jobs = <_Save>[];
  bool _running = false;
  Future<void> _idle = Future.value();
  Future<void> get idle => _idle;

  Future<void> save(String scope, Map<String, dynamic> snapshot) {
    final completion = Completer<void>();
    if (_jobs.isNotEmpty && _jobs.last.scope == scope) {
      _jobs.last.snapshot = snapshot;
      _jobs.last.waiters.add(completion);
    } else {
      _jobs.add(_Save(scope, snapshot, completion));
    }
    if (!_running) {
      _running = true;
      _idle = _drain();
    }
    return completion.future;
  }

  Future<void> _drain() async {
    while (_jobs.isNotEmpty) {
      final job = _jobs.removeAt(0);
      try {
        await vault.save(job.scope, job.snapshot);
        for (final waiter in job.waiters) {
          waiter.complete();
        }
      } catch (error, stack) {
        for (final waiter in job.waiters) {
          waiter.completeError(error, stack);
        }
      }
    }
    _running = false;
  }
}

class _Save {
  _Save(this.scope, this.snapshot, Completer<void> waiter) : waiters = [waiter];
  final String scope;
  Map<String, dynamic> snapshot;
  final List<Completer<void>> waiters;
}
