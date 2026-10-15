import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';

Map<String, dynamic> detail(String id, {String status = 'submitted'}) => {
  'id': id,
  'status': status,
  'subject_staff_ref': 'Fictional staff',
  'created_at': '2026-10-15T12:00:00Z',
  'submitted_at': '2026-10-15T12:00:00Z',
  'timeline': [
    {'occurred_at': '2026-10-14T12:00:00Z', 'narrative': 'Fictional incident.'},
  ],
  'evidence': [],
};
http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

void main() {
  test(
    'connected store has no fictional records and isolates accounts',
    () async {
      var account = 'one';
      final store = ConnectedStore(
        ApiClient(
          'http://test/api/v1',
          client: MockClient((r) async {
            if (r.url.path.endsWith('/login')) {
              return json({'access_token': 'token'});
            }
            if (r.url.path.endsWith('/me')) {
              return json({'id': account, 'role': 'student'});
            }
            return json([]);
          }),
        ),
      );
      addTearDown(store.dispose);
      expect(store.cases, isEmpty);
      expect(store.drafts, isEmpty);
      await store.login('one@example.test', 'fictional-password');
      store.startDraft().narrative = 'Account one only';
      account = 'two';
      await store.login('two@example.test', 'fictional-password');
      expect(store.drafts, isEmpty);
      expect(store.active, isNull);
      store.startDraft();
      store.signOut();
      expect(store.authenticated, isFalse);
      expect(store.drafts, isEmpty);
    },
  );

  test(
    'lost draft response retries identical payload and produces one case',
    () async {
      final payloads = <String>[];
      var creates = 0;
      final store = ConnectedStore(
        ApiClient(
          'http://test/api/v1',
          client: MockClient((r) async {
            final path = r.url.path;
            if (path.endsWith('/login')) return json({'access_token': 'token'});
            if (path.endsWith('/me')) {
              return json({'id': 'student', 'role': 'student'});
            }
            if (path.endsWith('/mine') || path.endsWith('/notifications')) {
              return json([]);
            }
            if (path.endsWith('/drafts')) {
              payloads.add(r.body);
              if (++creates == 1) throw http.ClientException('response lost');
              return json({'id': 'report-1'}, 201);
            }
            return json(detail('report-1'));
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.login('student@example.test', 'fictional-password');
      final draft = store.startDraft()
        ..subject = 'Fictional staff'
        ..narrative = 'Original narrative'
        ..occurredAt = DateTime(2026, 10, 14, 15);
      await expectLater(store.submit(), throwsA(isA<ApiException>()));
      expect(store.submissionPending, isTrue);
      store.deleteDraft(draft.id);
      expect(store.drafts, contains(draft));
      draft.narrative = 'Changed after request';
      final report = await store.submit();
      expect(report.id, 'report-1');
      expect(payloads[0], payloads[1]);
      expect(store.cases.length, 1);
      expect(store.drafts, isEmpty);
      expect(
        (jsonDecode(payloads.first)['timeline'][0]['occurred_at'] as String)
            .endsWith('Z'),
        isTrue,
      );
    },
  );

  test(
    'expired session retains drafts for same account without invented data',
    () async {
      var expired = false;
      final store = ConnectedStore(
        ApiClient(
          'http://test/api/v1',
          client: MockClient((r) async {
            if (r.url.path.endsWith('/login')) {
              return json({'access_token': 'token'});
            }
            if (r.url.path.endsWith('/me')) {
              return json({'id': 'student', 'role': 'student'});
            }
            if (expired) return json({'detail': 'expired'}, 401);
            return json([]);
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.login('student@example.test', 'fictional-password');
      store.startDraft().narrative = 'Keep this draft';
      expired = true;
      await store.refresh();
      expect(store.authenticated, isFalse);
      expect(store.error, contains('expired'));
      expired = false;
      await store.login('student@example.test', 'fictional-password');
      expect(store.drafts.single.narrative, 'Keep this draft');
      expect(store.cases, isEmpty);
    },
  );

  test('officer cannot sign into student client', () async {
    final store = ConnectedStore(
      ApiClient(
        'http://test/api/v1',
        client: MockClient(
          (r) async => r.url.path.endsWith('/login')
              ? json({'access_token': 'token'})
              : json({'id': 'officer', 'role': 'officer'}),
        ),
      ),
    );
    addTearDown(store.dispose);
    await expectLater(
      store.login('officer@example.test', 'fictional-password'),
      throwsA(isA<ApiException>()),
    );
    expect(store.authenticated, isFalse);
    expect(store.api.token, isNull);
  });
}
