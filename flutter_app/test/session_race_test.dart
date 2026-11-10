import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';

http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
Object detail() => {
  'id': 'old-report',
  'status': 'submitted',
  'subject_staff_ref': 'Fictional',
  'created_at': '2026-11-01T10:00:00Z',
  'timeline': [],
  'evidence': [],
};

void main() {
  test('late failed login cannot clear a newer account token', () async {
    final started = Completer<void>(), oldMe = Completer<http.Response>();
    final api = ApiClient(
      'https://test',
      client: MockClient((r) async {
        if (r.url.path == '/auth/login') {
          return json({'access_token': jsonDecode(r.body)['email']});
        }
        if (r.url.path == '/auth/me') {
          if (r.headers['Authorization'] == 'Bearer one') {
            started.complete();
            return oldMe.future;
          }
          return json({'id': 'two', 'role': 'student'});
        }
        return json([]);
      }),
    );
    final store = ConnectedStore(api);
    addTearDown(store.dispose);
    final oldLogin = store.login('one', 'fixture');
    await started.future;
    final failed = expectLater(oldLogin, throwsA(isA<ApiException>()));
    await store.login('two', 'fixture');
    oldMe.complete(json({}, 401));
    await failed;
    expect(api.token, 'two');
    expect(store.authenticated, true);
  });

  test(
    'old detail refresh stops before fetching updates with a new account',
    () async {
      final started = Completer<void>(), oldDetail = Completer<http.Response>();
      var newUpdates = 0;
      final store = ConnectedStore(
        ApiClient(
          'https://test',
          client: MockClient((r) async {
            final account = r.headers['Authorization']?.split(' ').last;
            if (r.url.path == '/auth/login') {
              return json({'access_token': jsonDecode(r.body)['email']});
            }
            if (r.url.path == '/auth/me') {
              return json({'id': account, 'role': 'student'});
            }
            if (r.url.path == '/cases/mine') {
              return json(
                account == 'one'
                    ? [
                        {'id': 'old-report'},
                      ]
                    : [],
              );
            }
            if (r.url.path == '/reports/old-report') {
              started.complete();
              return oldDetail.future;
            }
            if (r.url.path == '/notifications' && account == 'two') {
              newUpdates++;
            }
            return json([]);
          }),
        ),
      );
      addTearDown(store.dispose);
      final first = store.login('one', 'fixture');
      await started.future;
      await store.login('two', 'fixture');
      oldDetail.complete(json(detail()));
      await first;
      expect(newUpdates, 1);
      expect(store.cases, isEmpty);
    },
  );

  test(
    'late submission response cannot fetch another accounts case details',
    () async {
      final started = Completer<void>(), submitted = Completer<http.Response>();
      var newDetailReads = 0;
      final store = ConnectedStore(
        ApiClient(
          'https://test',
          client: MockClient((r) async {
            final account = r.headers['Authorization']?.split(' ').last;
            if (r.url.path == '/auth/login') {
              return json({'access_token': jsonDecode(r.body)['email']});
            }
            if (r.url.path == '/auth/me') {
              return json({'id': account, 'role': 'student'});
            }
            if (r.url.path == '/reports/drafts') {
              return json({'id': 'old-report'});
            }
            if (r.url.path.endsWith('/submit')) {
              started.complete();
              return submitted.future;
            }
            if (r.url.path == '/reports/old-report' && account == 'two') {
              newDetailReads++;
            }
            return json([]);
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.login('one', 'fixture');
      store.startDraft()
        ..subject = 'Fictional'
        ..narrative = 'Fictional only'
        ..occurredAt = DateTime(2026, 11, 1);
      final operation = store.submit();
      final failed = expectLater(operation, throwsA(isA<ApiException>()));
      await started.future;
      store.signOut();
      await store.login('two', 'fixture');
      submitted.complete(json({}));
      await failed;
      expect(newDetailReads, 0);
      expect(store.cases, isEmpty);
    },
  );
}
