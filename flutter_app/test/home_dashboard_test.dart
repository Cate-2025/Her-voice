import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/report_store.dart';

import 'widget_test.dart' show render, tapVisible;

class DraftStateStore extends ReportStore {
  DraftStateStore({this.durable = false, this.pending = false});
  final bool durable, pending;
  @override
  bool get durableDrafts => durable;
  @override
  bool draftPending(String id) => pending;
}

void main() {
  for (final durable in [false, true]) {
    testWidgets('home explains draft retention with durable=$durable', (
      tester,
    ) async {
      final store = DraftStateStore(durable: durable)..startDraft();
      addTearDown(store.dispose);
      await render(tester, store: store);
      expect(
        find.text(
          durable
              ? 'Not submitted · encrypted on this device'
              : 'Not submitted · kept for this app session',
        ),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Continue draft'));
      expect(find.byType(TextFormField), findsWidgets);
    });
  }
  testWidgets('pending submission does not claim it is unsubmitted', (
    tester,
  ) async {
    final store = DraftStateStore(durable: true, pending: true)..startDraft();
    addTearDown(store.dispose);
    await render(tester, store: store);
    expect(find.text('Continue your submission'), findsOneWidget);
    expect(find.textContaining('Not submitted'), findsNothing);
  });
  testWidgets('empty home explains where records will appear', (tester) async {
    final store = ReportStore();
    addTearDown(store.dispose);
    await render(tester, store: store);
    expect(
      find.text(
        'No records yet. Your drafts and submitted reports will appear here.',
      ),
      findsOneWidget,
    );
    await tapVisible(tester, find.byKey(const Key('new-incident')));
    expect(store.drafts, hasLength(1));
  });
}
