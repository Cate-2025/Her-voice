import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hervoice/core/encrypted_draft_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';

void main() {
  const base = String.fromEnvironment('HERVOICE_TEST_API');
  const password = String.fromEnvironment('HERVOICE_TEST_PASSWORD');
  test(
    'real PostgreSQL API: student report, officer status, notification, relogin',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hervoice-live-vault-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final keys = <String, String>{};
      final store = ConnectedStore(
        ApiClient(base),
        vault: EncryptedDraftVault(
          directory: directory,
          readKey: (key) async => keys[key],
          writeKey: (key, value) async {
            keys[key] = value;
          },
        ),
      );
      final officer = ApiClient(base);
      addTearDown(store.dispose);
      addTearDown(officer.close);
      await store.login('student@example.test', password);
      expect(store.authenticated, isTrue);
      store.startDraft()
        ..subject = 'FICTIONAL-INTEGRATION-TEST'
        ..narrative = 'Fictional connected prototype acceptance test.'
        ..occurredAt = DateTime.now().subtract(const Duration(days: 1));
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6MtIAAAAASUVORK5CYII=',
      );
      await store.addAttachment(store.active!, 'fictional.png', image);
      final report = await store.submit();
      expect(report.attachments.single.name, 'fictional.png');
      expect(report.status, 'Submitted');
      final token = await officer.request('POST', '/auth/login', {
        'email': 'officer@example.test',
        'password': password,
      });
      officer.token = token['access_token'] as String;
      final evidence =
          (await officer.request(
                'GET',
                '/officer/cases/${report.id}',
              ))['evidence']
              as List;
      final download = await http.get(
        Uri.parse('$base/evidence/${evidence.single['id']}/file'),
        headers: {'Authorization': 'Bearer ${officer.token}'},
      );
      expect(download.statusCode, 200);
      expect(download.bodyBytes, image);
      final queue = await officer.request('GET', '/officer/cases') as List;
      expect(queue.any((c) => c['id'] == report.id), isTrue);
      await officer.request('PATCH', '/officer/cases/${report.id}/status', {
        'status': 'received',
      });
      await store.refresh();
      expect(store.caseById(report.id)!.status, 'Received');
      expect(store.updates, isNotEmpty);
      final notice = store.updates.firstWhere((n) => !n.read);
      await store.readUpdate(notice.id);
      expect(store.updates.firstWhere((n) => n.id == notice.id).read, isTrue);
      await officer.request('PATCH', '/officer/cases/${report.id}/status', {
        'status': 'under_review',
        'expected_status': 'received',
      });
      await store.refresh();
      await store.readAllUpdates();
      expect(store.updates.every((item) => item.read), isTrue);
      store.signOut();
      expect(store.cases, isEmpty);
      await store.login('student@example.test', password);
      expect(store.caseById(report.id)!.status, 'Under review');
      expect(store.caseById(report.id)!.events.map((e) => e.$1), [
        'Submitted',
        'Received',
        'Under review',
      ]);
    },
    skip: base.isEmpty
        ? 'Set HERVOICE_TEST_API and HERVOICE_TEST_PASSWORD for a local fictional-data server.'
        : false,
  );
}
