import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/api_client.dart';
import 'package:hervoice/core/connected_store.dart';

void main() {
  const base = String.fromEnvironment('HERVOICE_TEST_API');
  const password = String.fromEnvironment('HERVOICE_TEST_PASSWORD');
  test(
    'real PostgreSQL API: student report, officer status, notification, relogin',
    () async {
      final store = ConnectedStore(ApiClient(base));
      final officer = ApiClient(base);
      addTearDown(store.dispose);
      addTearDown(officer.close);
      await store.login('student@example.test', password);
      expect(store.authenticated, isTrue);
      store.startDraft()
        ..subject = 'FICTIONAL-INTEGRATION-TEST'
        ..narrative = 'Fictional connected prototype acceptance test.'
        ..occurredAt = DateTime.now().subtract(const Duration(days: 1));
      final report = await store.submit();
      expect(report.status, 'Submitted');
      final token = await officer.request('POST', '/auth/login', {
        'email': 'officer@example.test',
        'password': password,
      });
      officer.token = token['access_token'] as String;
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
      store.signOut();
      expect(store.cases, isEmpty);
      await store.login('student@example.test', password);
      expect(store.caseById(report.id)!.status, 'Received');
    },
    skip: base.isEmpty
        ? 'Set HERVOICE_TEST_API and HERVOICE_TEST_PASSWORD for a local fictional-data server.'
        : false,
  );
}
