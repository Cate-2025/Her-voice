import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/app/app.dart';
import 'package:hervoice/core/demo_store.dart';

Future<void> render(
  WidgetTester tester, {
  String route = '/home',
  double width = 390,
  double scale = 1,
  double height = 900,
  ReportStore? store,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(HerVoiceApp(store: store, initialLocation: route));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    for (final family in ['Lora', 'Manrope']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  for (final width in [390.0, 1440.0]) {
    for (final route in [
      '/home',
      '/records',
      '/updates',
      '/support',
      '/document',
      '/review',
      '/cases/HV-DEMO-024',
      '/welcome',
      '/signin',
    ]) {
      testWidgets('$route fits ${width.toInt()}px layout', (tester) async {
        final store = DemoStore()..openDraft('draft-example');
        await render(tester, route: route, width: width, store: store);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final route in [
    '/home',
    '/records',
    '/document',
    '/review',
    '/support',
    '/cases/HV-DEMO-024',
  ]) {
    testWidgets('$route supports large text on a narrow phone', (tester) async {
      final store = DemoStore()..openDraft('draft-example');
      await render(tester, route: route, width: 320, scale: 1.8, store: store);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'connected routes require sign-in and never seed fictional cases',
    (tester) async {
      final store = connectedStore();
      addTearDown(store.dispose);
      await render(tester, route: '/records', store: store);
      expect(find.text('Sign in'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'fictional-password',
      );
      await tapVisible(tester, find.text('Sign in'));
      expect(find.text('Welcome to your space.'), findsOneWidget);
      expect(find.text('HV-DEMO-024'), findsNothing);
      expect(find.text('PROTOTYPE'), findsOneWidget);
    },
  );

  testWidgets(
    'connected submission requires consent and shows server confirmation',
    (tester) async {
      final store = connectedStore();
      addTearDown(store.dispose);
      await store.login('student@example.test', 'fictional-password');
      store.startDraft()
        ..subject = 'Fictional staff'
        ..narrative = 'Fictional incident.'
        ..occurredAt = DateTime(2026, 10, 14);
      await render(tester, route: '/review', store: store);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('preview-submit')))
            .onPressed,
        isNull,
      );
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Submit report'));
      expect(find.text('REPORT SUBMITTED'), findsOneWidget);
      expect(store.cases.single.id, 'report-1');
      expect(find.text('DEMO JOURNEY COMPLETE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed connected submission retains draft and offers retry', (
    tester,
  ) async {
    final store = connectedStore(failSubmit: true);
    addTearDown(store.dispose);
    await store.login('student@example.test', 'fictional-password');
    store.startDraft()
      ..subject = 'Fictional staff'
      ..narrative = 'Fictional incident.'
      ..occurredAt = DateTime(2026, 10, 14);
    await render(tester, route: '/review', store: store);
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tapVisible(tester, find.text('Submit report'));
    expect(find.byKey(const Key('submission-error')), findsOneWidget);
    expect(store.active!.narrative, 'Fictional incident.');
    expect(store.cases, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('preview-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('sidebar fits a landscape desktop window', (tester) async {
    await render(tester, width: 1024, height: 400, scale: 1.8);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Support'));
    expect(find.text('Support, on your terms.'), findsOneWidget);
  });

  testWidgets('direct review cannot submit an incomplete draft', (
    tester,
  ) async {
    final store = DemoStore()..startDraft();
    await render(tester, route: '/review', store: store);
    await tapVisible(tester, find.byType(CheckboxListTile));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('preview-submit')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.text('Keep editing'));
    expect(find.byKey(const Key('narrative-field')), findsOneWidget);
    expect(store.cases.length, 2);
  });

  testWidgets('sidebar remains usable in a short window with enlarged text', (
    tester,
  ) async {
    await render(tester, width: 1280, height: 600, scale: 1.8);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('My records'));
    expect(find.text('Your words, kept together.'), findsOneWidget);
  });

  testWidgets(
    'unfinished draft saves and reopens without claiming submission',
    (tester) async {
      final store = DemoStore();
      await render(tester, store: store);
      await tapVisible(tester, find.byKey(const Key('new-incident')));
      await tester.enterText(
        find.byKey(const Key('narrative-field')),
        'Fictional draft text.',
      );
      await tapVisible(tester, find.byKey(const Key('save-draft')));
      expect(find.text('Draft kept for this preview session.'), findsOneWidget);
      expect(find.text('Your words, kept together.'), findsOneWidget);
      expect(store.cases.length, 2);
      expect(store.drafts.first.narrative, 'Fictional draft text.');
      await tapVisible(tester, find.text('Continue draft').first);
      expect(find.text('Fictional draft text.'), findsOneWidget);
    },
  );

  testWidgets(
    'incident date, review consent and demo submission work end to end',
    (tester) async {
      final store = DemoStore();
      await render(tester, store: store);
      await tapVisible(tester, find.byKey(const Key('new-incident')));
      await tester.enterText(
        find.byKey(const Key('narrative-field')),
        'Fictional end-to-end incident.',
      );
      await tester.enterText(
        find.byKey(const Key('subject-field')),
        'Fictional subject',
      );
      await tapVisible(tester, find.byKey(const Key('date-picker')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(store.active?.occurredAt, isNotNull);
      await tapVisible(tester, find.byKey(const Key('editor-next')));
      expect(find.text('Add evidence, if you choose'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('editor-next')));
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('preview-submit')),
      );
      expect(button.onPressed, isNull);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.byKey(const Key('preview-submit')));
      expect(find.text('DEMO JOURNEY COMPLETE'), findsOneWidget);
      expect(store.cases.length, 3);
      expect(store.cases.first.narrative, 'Fictional end-to-end incident.');
      expect(store.cases.first.subject, 'Fictional subject');
      expect(store.cases.first.occurredAt, isNotNull);
      await tapVisible(tester, find.text('View preview case'));
      expect(find.text('Case progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('file selection and removal retain metadata without uploading', (
    tester,
  ) async {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = FakePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
    final store = DemoStore()..openDraft('draft-example');
    await render(tester, route: '/document', store: store);
    await tapVisible(tester, find.byKey(const Key('editor-next')));
    await tapVisible(tester, find.text('Choose files'));
    expect(store.active!.attachments.single.name, 'fictional.pdf');
    expect(find.text('fictional.pdf'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Remove fictional.pdf'));
    expect(store.active!.attachments, isEmpty);
  });

  testWidgets(
    'unsupported files are rejected even if the picker returns them',
    (tester) async {
      final original = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = FakePicker(name: 'fictional.exe');
      addTearDown(() => FileSelectorPlatform.instance = original);
      final store = DemoStore();
      await render(tester, route: '/document', store: store);
      await tapVisible(tester, find.byKey(const Key('editor-next')));
      await tapVisible(tester, find.text('Choose files'));
      expect(store.active!.attachments, isEmpty);
      expect(
        find.text('Choose a JPG, PNG, PDF, MP3, or M4A file.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('deleting a draft requires explicit confirmation', (
    tester,
  ) async {
    final store = DemoStore();
    await render(tester, route: '/records', store: store);
    await tapVisible(tester, find.byTooltip('Delete draft'));
    await tapVisible(tester, find.text('Keep draft'));
    expect(store.drafts.length, 1);
    await tapVisible(tester, find.byTooltip('Delete draft'));
    await tapVisible(tester, find.text('Delete draft'));
    expect(store.drafts, isEmpty);
    expect(
      find.text('No drafts right now. Start whenever you feel ready.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'unknown case shows recovery action instead of invented details',
    (tester) async {
      await render(tester, route: '/cases/does-not-exist');
      expect(find.text('Case not available.'), findsOneWidget);
      await tapVisible(tester, find.text('Back to my records'));
      expect(find.text('Your words, kept together.'), findsOneWidget);
    },
  );
}

class FakePicker extends FileSelectorPlatform {
  FakePicker({this.name = 'fictional.pdf'});
  final String name;
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => [
    XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: name,
      path: name,
      mimeType: 'application/pdf',
    ),
  ];
}

ConnectedStore connectedStore({bool failSubmit = false}) => ConnectedStore(
  ApiClient(
    'http://test/api/v1',
    client: MockClient((request) async {
      Object value;
      final path = request.url.path;
      if (path.endsWith('/login')) {
        value = {'access_token': 'token'};
      } else if (path.endsWith('/me')) {
        value = {'id': 'student', 'role': 'student'};
      } else if (path.endsWith('/mine') || path.endsWith('/notifications')) {
        value = [];
      } else if (path.endsWith('/submit') && failSubmit) {
        return http.Response('{}', 503);
      } else {
        value = {
          'id': 'report-1',
          'status': 'submitted',
          'subject_staff_ref': 'Fictional staff',
          'created_at': '2026-10-15T12:00:00Z',
          'submitted_at': '2026-10-15T12:00:00Z',
          'timeline': [
            {
              'occurred_at': '2026-10-14T12:00:00Z',
              'narrative': 'Fictional incident.',
            },
          ],
          'evidence': [],
        };
      }
      return http.Response(jsonEncode(value), 200);
    }),
  ),
);
