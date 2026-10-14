import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
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
  DemoStore? store,
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
