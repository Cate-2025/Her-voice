import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/demo_store.dart';
import 'package:hervoice/features/auth/email_access_screen.dart';

class EmailFixture extends ReportStore {
  final requests = <List<String>>[];
  @override
  Future<void> requestEmailCode(String email, String purpose) async {
    requests.add([email, purpose]);
  }

  @override
  Future<void> completeEmailCode(
    String email,
    String purpose,
    String code,
    String password,
  ) async {
    requests.add([email, purpose, code, password]);
  }
}

void main() {
  testWidgets(
    'email registration verifies before account completion and enforces password length',
    (tester) async {
      final store = EmailFixture();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(home: EmailAccessScreen(store: store, reset: false)),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'person@independent.example',
      );
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      expect(store.requests.single, ['person@independent.example', 'register']);
      await tester.enterText(find.byType(TextFormField).at(1), '12345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.ensureVisible(find.text('Verify and save password'));
      await tester.tap(find.text('Verify and save password'));
      await tester.pumpAndSettle();
      expect(store.requests.length, 1);
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'fictional-password',
      );
      await tester.tap(find.text('Verify and save password'));
      await tester.pumpAndSettle();
      expect(store.requests.last, [
        'person@independent.example',
        'register',
        '12345678',
        'fictional-password',
      ]);
      expect(find.text('Email verified. You can now sign in.'), findsOneWidget);
    },
  );
  testWidgets(
    'password reset ends with accurate success and no new-code form',
    (tester) async {
      final store = EmailFixture();
      await tester.pumpWidget(
        MaterialApp(home: EmailAccessScreen(store: store, reset: true)),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'person@example.test',
      );
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '12345678');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'fictional-password',
      );
      await tester.ensureVisible(find.text('Verify and save password'));
      await tester.tap(find.text('Verify and save password'));
      await tester.pumpAndSettle();
      expect(store.requests.last[1], 'reset');
      expect(
        find.text('Password updated. Sign in with your new password.'),
        findsOneWidget,
      );
      expect(find.text('Send verification code'), findsNothing);
      expect(find.text('Email verified. You can now sign in.'), findsNothing);
    },
  );
}
