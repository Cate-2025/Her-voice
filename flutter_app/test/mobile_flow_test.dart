import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/report_store.dart';

import 'widget_test.dart' show render, tapVisible;

class MobileFixture extends ReportStore {
  MobileFixture({
    this.durable = true,
    this.pending = false,
    this.failSave = false,
  }) : super(isConnected: true);
  final bool durable, pending, failSave;
  int saves = 0;
  @override
  bool get authenticated => true;
  @override
  bool get durableDrafts => durable;
  @override
  String get draftStorageStatus => durable
      ? 'Drafts are encrypted on this device.'
      : 'Drafts are held in this session only.';
  @override
  bool get submissionPending => pending;
  @override
  bool draftPending(String id) => pending;
  @override
  Future<void> flushDrafts() async {
    saves++;
    if (failSave) throw StateError('Fixture storage unavailable');
  }
}

class ShellStatusFixture extends MobileFixture {
  String? storageIssue;
  int refreshes = 0;
  @override
  String? get draftStorageError => storageIssue;
  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> flushDrafts() async {
    storageIssue = null;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'routine storage status is quiet and refresh remains in account menu',
    (tester) async {
      final store = ShellStatusFixture();
      await render(tester, store: store);
      expect(find.text(store.draftStorageStatus), findsNothing);
      expect(find.text('PROTOTYPE'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      await tester.tap(find.byTooltip('Account and privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh records and updates'));
      await tester.pumpAndSettle();
      expect(store.refreshes, 1);
    },
  );
  testWidgets('storage failure remains visible and can be retried', (
    tester,
  ) async {
    final store = ShellStatusFixture()
      ..storageIssue = 'Draft could not be saved.';
    await render(tester, store: store);
    expect(find.text('Draft could not be saved.'), findsOneWidget);
    await tapVisible(tester, find.text('Retry saving draft'));
    expect(find.text('Draft could not be saved.'), findsNothing);
  });

  testWidgets(
    'Android Back moves review to editor to records to home and flushes draft',
    (tester) async {
      final store = MobileFixture();
      store.startDraft()
        ..narrative = 'Fictional event'
        ..subject = 'Fictional staff'
        ..occurredAt = DateTime(2026, 10, 1);
      await render(tester, route: '/review', store: store);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('narrative-field')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Drafts'), findsOneWidget);
      expect(store.saves, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Your dashboard'), findsOneWidget);
    },
  );
  testWidgets('Back preserves the editor when its draft cannot be saved', (
    tester,
  ) async {
    final store = MobileFixture(failSave: true)..startDraft();
    await render(tester, route: '/document', store: store);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('narrative-field')), findsOneWidget);
    expect(
      find.textContaining('Your draft could not be saved'),
      findsOneWidget,
    );
  });
  testWidgets('pending review has no Edit action and Back returns to records', (
    tester,
  ) async {
    final store = MobileFixture(pending: true);
    store.startDraft()
      ..narrative = 'Fictional event'
      ..subject = 'Fictional staff'
      ..occurredAt = DateTime(2026, 10, 1);
    await render(tester, route: '/review', store: store);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Edit'))
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('You can still go back and make changes'),
      findsNothing,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('Review saved submission'), findsOneWidget);
    await tapVisible(tester, find.text('Review saved submission'));
    expect(find.text('Your incident'), findsOneWidget);
  });
  testWidgets(
    'records explain durable storage without claiming a pending report is unsubmitted',
    (tester) async {
      final store = MobileFixture(pending: true)..startDraft();
      await render(tester, route: '/records', store: store);
      expect(
        find.text(
          'Drafts and pending submissions are encrypted on this device. Sign in to the same account to continue.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('retained only during'), findsNothing);
      expect(find.textContaining('Not submitted'), findsNothing);
    },
  );
  testWidgets(
    'connected evidence details do not describe a disconnected preview',
    (tester) async {
      final store = MobileFixture();
      store.cases.add(
        PreviewCase(
          id: 'fixture-case',
          date: DateTime(2026, 10, 1),
          status: 'Submitted',
          narrative: 'Fictional event',
          location: '',
          events: [],
          attachments: [const Attachment('fictional.pdf', 1024)],
        ),
      );
      await render(tester, route: '/cases/fixture-case', store: store);
      expect(find.text('Report evidence'), findsOneWidget);
      expect(
        find.text('Preview metadata only. No files were uploaded.'),
        findsNothing,
      );
      expect(
        find.text(
          'These are the evidence files listed on your submitted report.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('home resumes a pending submission directly in review', (
    tester,
  ) async {
    final store = MobileFixture(pending: true);
    store.startDraft()
      ..narrative = 'Fictional event'
      ..subject = 'Fictional staff'
      ..occurredAt = DateTime(2026, 10, 1);
    await render(tester, store: store);
    await tapVisible(tester, find.text('Review saved submission'));
    expect(find.text('Your incident'), findsOneWidget);
    expect(find.byKey(const Key('narrative-field')), findsNothing);
  });
  testWidgets('incident fields have persistent accessible labels', (
    tester,
  ) async {
    final store = MobileFixture()..startDraft();
    await render(tester, route: '/document', store: store);
    // EditableText semantics should retain a label after text replaces the hint.
    await tester.enterText(
      find.byKey(const Key('narrative-field')),
      'Fictional narrative',
    );
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.decoration?.labelText, 'What happened?');
  });
  testWidgets(
    'connected editor remains scrollable with large text and keyboard inset',
    (tester) async {
      final store = MobileFixture()..startDraft();
      await render(
        tester,
        route: '/document',
        store: store,
        width: 320,
        height: 640,
        scale: 1.8,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('narrative-field')));
      expect(find.byKey(const Key('page-scroll')), findsOneWidget);
    },
  );
}
