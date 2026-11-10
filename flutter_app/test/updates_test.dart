import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';
import 'package:hervoice/core/demo_store.dart';
import 'package:hervoice/features/updates/updates_screen.dart';

void main() {
  test(
    'bulk read changes only after server confirmation; failures retain unread',
    () async {
      var fail = true;
      final notice = {
        'id': 'notice',
        'body': 'A neutral update',
        'created_at': '2026-10-17T10:00:00Z',
        'read_at': null,
      };
      final store = ConnectedStore(
        ApiClient(
          'http://test/api/v1',
          client: MockClient((request) async {
            final path = request.url.path;
            Object data = [];
            if (path.endsWith('/login')) data = {'access_token': 'test'};
            if (path.endsWith('/me')) {
              data = {'id': 'student', 'role': 'student'};
            }
            if (path.endsWith('/notifications')) data = [notice];
            if (path.endsWith('/read-all')) {
              if (fail) return http.Response('{}', 500);
              data = [
                {...notice, 'read_at': '2026-10-17T11:00:00Z'},
              ];
            }
            return http.Response(jsonEncode(data), 200);
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.login('student@example.test', 'fictional');
      await store.readAllUpdates();
      expect(store.updates.single.read, false);
      expect(store.error, isNotNull);
      fail = false;
      await store.readAllUpdates();
      expect(store.updates.single.read, true);
      expect(store.error, isNull);
    },
  );

  testWidgets('mark all read clears preview unread and disables the action', (
    tester,
  ) async {
    final store = DemoStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: UpdatesScreen(store: store)),
        ),
      ),
    );
    await tester.tap(find.text('Mark all as read'));
    await tester.pump();
    expect(store.updateRead, true);
    expect(find.text('All updates read'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Mark all as read'),
          )
          .onPressed,
      isNull,
    );
  });

  test('case labels retain reference separately from a readable date', () {
    final item = PreviewCase(
      id: 'opaque-reference',
      date: DateTime(2026, 10, 17, 14, 5),
      status: 'Submitted',
      narrative: 'Example',
      location: 'Example',
      events: [],
    );
    expect(item.title, 'Report · 17 Oct 2026');
    expect(item.submittedLabel, 'Submitted at 14:05');
    expect(item.id, 'opaque-reference');
  });
}
