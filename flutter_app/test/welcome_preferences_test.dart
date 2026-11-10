import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hervoice/app/app.dart';
import 'package:hervoice/core/welcome_preferences.dart';

import 'mobile_flow_test.dart' show MobileFixture;

void main() {
  test('welcome marker persists across preference instances without clearing other keys', () async {
    final values = <String, String>{'draft-key-existing': 'keep'};
    WelcomePreferences preferences() => WelcomePreferences(
      read: (key) async => values[key],
      write: (key, value) async {
        values[key] = value;
      },
    );
    expect(await preferences().hasSeenWelcome(), isFalse);
    await preferences().markSeen();
    expect(await preferences().hasSeenWelcome(), isTrue);
    expect(values['draft-key-existing'], 'keep');
  });
  test('preference failures do not block access or reset storage', () async {
    final preferences = WelcomePreferences(
      read: (_) async => throw StateError('Fixture storage failure'),
      write: (_, value) async => throw StateError('Fixture storage failure'),
    );
    expect(await preferences.hasSeenWelcome(), isFalse);
    await preferences.markSeen();
  });
  testWidgets(
    'leaving Welcome records completion and reaches connected sign-in',
    (tester) async {
      var marked = false;
      // An unauthenticated connected store is required for the public entry flow.
      final store = MobileFixture();
      await tester.pumpWidget(
        HerVoiceApp(
          store: store,
          initialLocation: '/welcome',
          onWelcomeComplete: () async {
            marked = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(marked, isTrue);
      expect(find.byType(TextFormField), findsNWidgets(2));
    },
  );
}
