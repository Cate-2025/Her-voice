import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hervoice/core/date_format.dart';
import 'package:hervoice/models/enums.dart';
import 'package:hervoice/models/incident_report.dart';
import 'package:hervoice/models/timeline_event.dart';
import 'package:hervoice/widgets/privacy_notice.dart';
import 'package:hervoice/widgets/section_card.dart';

void main() {
  group('ReportingType', () {
    test('round-trips through the wire values used by the backend', () {
      for (final ReportingType type in ReportingType.values) {
        expect(ReportingType.fromWire(type.wire), type);
      }
    });

    test('falls back to a confidential report for an unknown value', () {
      expect(ReportingType.fromWire('SOMETHING_ELSE'), ReportingType.confidential);
    });

    test('every pathway explains its privacy consequence', () {
      for (final ReportingType type in ReportingType.values) {
        expect(type.explanation, isNotEmpty);
      }
    });
  });

  group('CaseStatus', () {
    test('orders the lifecycle from draft to closed', () {
      expect(CaseStatus.draft.stepIndex, 0);
      expect(CaseStatus.closed.stepIndex, greaterThan(CaseStatus.underReview.stepIndex));
    });

    test('an unknown status does not crash the tracker', () {
      expect(CaseStatus.fromWire('WHATEVER'), CaseStatus.submitted);
    });
  });

  group('IncidentReport', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 'rpt_1',
      'reference': 'HV-2026-0001',
      'person': 'Dr A. Lecturer',
      'course': 'BSE 3106',
      'location': 'Block C, Room 12',
      'description': 'Inappropriate messages after class.',
      'reportingType': 'CONFIDENTIAL',
      'status': 'SUBMITTED',
      'incidentOccurredAt': '2026-09-12T14:30:00.000Z',
      'evidence': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'evd_1',
          'kind': 'SCREENSHOT',
          'originalName': 'screenshot.png',
          'sizeBytes': 2048,
          'sha256': 'a' * 64,
        },
      ],
      'timeline': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'tl_1',
          'kind': 'INCIDENT_RECORDED',
          'title': 'Incident recorded',
          'at': '2026-09-12T14:30:00.000Z',
          'actorRole': 'STUDENT',
        },
      ],
    };

    test('parses the server payload including evidence and timeline', () {
      final IncidentReport report = IncidentReport.fromJson(payload);
      expect(report.reference, 'HV-2026-0001');
      expect(report.reportingType, ReportingType.confidential);
      expect(report.status, CaseStatus.submitted);
      expect(report.evidence, hasLength(1));
      expect(report.timeline, hasLength(1));
      expect(report.evidence.first.fingerprint, isNot(contains('...')));
    });

    test('survives a payload with missing optional fields', () {
      final IncidentReport report = IncidentReport.fromJson(<String, dynamic>{
        'id': 'rpt_2',
        'reference': 'HV-2026-0002',
        'person': '',
        'course': '',
        'location': '',
        'description': '',
      });
      expect(report.reportingType, ReportingType.confidential);
      expect(report.evidence, isEmpty);
      expect(report.coordinateLabel, isNull);
    });

    test('an anonymous incident carries no coordinates unless consent was given', () {
      final IncidentDraft draft = IncidentDraft(
        person: 'Dr A. Lecturer',
        course: 'BSE 3106',
        location: 'Block C',
        description: 'Inappropriate messages.',
        reportingType: ReportingType.anonymous,
        incidentOccurredAt: DateTime.utc(2026, 9, 12, 14, 30),
      );
      final Map<String, dynamic> json = draft.toJson();
      expect(json['reportingType'], 'ANONYMOUS');
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
    });
  });

  group('TimelineEvent', () {
    test('flags entries written by institutional personnel', () {
      final TimelineEvent fromStudent = TimelineEvent(
        id: 'tl_1',
        kind: TimelineEventKind.incidentRecorded,
        title: 'Incident recorded',
        at: DateTime.utc(2026, 9, 12, 14, 30),
        actorRole: 'STUDENT',
      );
      final TimelineEvent fromOfficer = TimelineEvent(
        id: 'tl_2',
        kind: TimelineEventKind.officerMessage,
        title: 'Message from authorised personnel',
        at: DateTime.utc(2026, 9, 12, 15),
        actorRole: 'ADMIN',
      );
      expect(fromStudent.fromInstitution, isFalse);
      expect(fromOfficer.fromInstitution, isTrue);
    });

    test('formats the time in the style used by the concept paper', () {
      final TimelineEvent event = TimelineEvent(
        id: 'tl_1',
        kind: TimelineEventKind.incidentRecorded,
        title: 'Incident recorded',
        at: DateTime(2026, 9, 12, 16, 30),
      );
      expect(event.whenLabel, '12 September, 4:30 PM');
    });
  });

  group('formatBytes', () {
    test('scales the unit', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('PrivacyNotice', () {
    testWidgets('always states that a report is not a finding', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AllegationNotice()),
      ));
      expect(find.textContaining('not a finding of guilt'), findsOneWidget);
    });
  });

  group('CaseStatusChip', () {
    testWidgets('renders the human label rather than the wire value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SectionCard(
            title: 'Case status',
            child: CaseStatusChip(status: CaseStatus.underReview),
          ),
        ),
      ));
      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('UNDER_REVIEW'), findsNothing);
    });
  });
}
