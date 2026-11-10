import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';

void main() {
  test(
    'an older server repeating a full page fails instead of looping',
    () async {
      var requests = 0;
      final api = ApiClient(
        'https://test',
        client: MockClient((r) async {
          requests++;
          return http.Response(
            jsonEncode(List.generate(100, (i) => {'id': '$i'})),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await expectLater(api.listPages('/cases'), throwsA(isA<ApiException>()));
      expect(requests, 2);
    },
  );

  test('paged lists preserve filters and request the remaining rows', () async {
    final offsets = <int>[];
    final api = ApiClient(
      'https://test/api/v1',
      client: MockClient((r) async {
        expect(r.url.queryParameters['status_filter'], 'submitted');
        final offset = int.parse(r.url.queryParameters['offset']!);
        offsets.add(offset);
        return http.Response(
          jsonEncode(List.generate(offset == 0 ? 100 : 5, (i) => i + offset)),
          200,
        );
      }),
    );
    addTearDown(api.close);
    expect((await api.listPages('/cases?status_filter=submitted')).length, 105);
    expect(offsets, [0, 100]);
  });

  test(
    'record refresh overlaps requests but never exceeds four details',
    () async {
      var active = 0, peak = 0;
      final store = ConnectedStore(
        ApiClient(
          'https://test/api/v1',
          client: MockClient((r) async {
            Object result = [];
            if (r.url.path.endsWith('/login')) {
              result = {'access_token': 'fixture'};
            }
            if (r.url.path.endsWith('/me')) {
              result = {'id': 'one', 'role': 'student'};
            }
            if (r.url.path.endsWith('/mine')) {
              result = List.generate(9, (i) => {'id': '$i'});
            }
            if (r.url.path.contains('/reports/')) {
              active++;
              if (active > peak) peak = active;
              await Future<void>.delayed(const Duration(milliseconds: 5));
              active--;
              result = {
                'id': r.url.pathSegments.last,
                'status': 'submitted',
                'subject_staff_ref': 'Fictional',
                'created_at': '2026-10-30T10:00:00Z',
                'timeline': [],
                'evidence': [],
              };
            }
            return http.Response(jsonEncode(result), 200);
          }),
        ),
      );
      addTearDown(store.dispose);
      await store.login('fixture', 'fixture');
      expect(peak, 4);
      expect(store.cases.map((c) => c.id), List.generate(9, (i) => '$i'));
    },
  );
}
