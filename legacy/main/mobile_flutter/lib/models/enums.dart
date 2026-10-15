/// Domain vocabulary shared with the backend (`backend/src/domain.js`).
///
/// Keep these wire values in step with the server: they are the contract that
/// makes the offline queue replayable and the pattern detector meaningful.
library;

/// The three reporting pathways of section 3.4.
enum ReportingType {
  identified('IDENTIFIED', 'Identified report'),
  confidential('CONFIDENTIAL', 'Confidential report'),
  anonymous('ANONYMOUS', 'Anonymous report');

  const ReportingType(this.wire, this.label);

  final String wire;
  final String label;

  static ReportingType fromWire(Object? value) {
    return ReportingType.values.firstWhere(
      (ReportingType type) => type.wire == value,
      orElse: () => ReportingType.confidential,
    );
  }

  /// Shown to the student before she commits to a pathway.
  String get explanation {
    switch (this) {
      case ReportingType.identified:
        return 'Your identity is provided to the authorised personnel handling the complaint.';
      case ReportingType.confidential:
        return 'Your identity is protected from unnecessary disclosure and accessible only to '
            'authorised personnel according to defined access controls.';
      case ReportingType.anonymous:
        return 'No identity is attached to the report. It can still contribute to pattern '
            'detection, but anonymity may limit the institution\'s ability to investigate '
            'an individual case.';
    }
  }
}

/// Case lifecycle shown by the case-status tracker (section 3.1 C).
enum CaseStatus {
  draft('DRAFT', 'Draft'),
  submitted('SUBMITTED', 'Received'),
  underReview('UNDER_REVIEW', 'Under review'),
  investigating('INVESTIGATING', 'Investigating'),
  actionTaken('ACTION_TAKEN', 'Action taken'),
  referred('REFERRED', 'Referred'),
  closed('CLOSED', 'Closed');

  const CaseStatus(this.wire, this.label);

  final String wire;
  final String label;

  static CaseStatus fromWire(Object? value) {
    return CaseStatus.values.firstWhere(
      (CaseStatus status) => status.wire == value,
      orElse: () => CaseStatus.submitted,
    );
  }

  /// Ordering used to render progress indicators.
  static const List<CaseStatus> flow = <CaseStatus>[
    CaseStatus.draft,
    CaseStatus.submitted,
    CaseStatus.underReview,
    CaseStatus.investigating,
    CaseStatus.actionTaken,
    CaseStatus.referred,
    CaseStatus.closed,
  ];

  int get stepIndex => flow.indexOf(this);
}

/// Evidence categories listed in section 3.2.
enum EvidenceKind {
  screenshot('SCREENSHOT', 'Screenshot'),
  photograph('PHOTOGRAPH', 'Photograph'),
  email('EMAIL', 'Email'),
  document('DOCUMENT', 'Document'),
  audio('AUDIO', 'Permitted recording'),
  other('OTHER', 'Other record');

  const EvidenceKind(this.wire, this.label);

  final String wire;
  final String label;

  static EvidenceKind fromWire(Object? value) {
    return EvidenceKind.values.firstWhere(
      (EvidenceKind kind) => kind.wire == value,
      orElse: () => EvidenceKind.other,
    );
  }

  /// Audio needs the lawful-collection declaration from the risk table.
  bool get requiresLawfulDeclaration => this == EvidenceKind.audio;
}

/// Timeline entry types drawn on the incident timeline.
enum TimelineEventKind {
  incidentRecorded('INCIDENT_RECORDED', 'Incident'),
  evidenceAdded('EVIDENCE_ADDED', 'Evidence'),
  followUp('FOLLOW_UP', 'Follow-up'),
  reportSubmitted('REPORT_SUBMITTED', 'Submitted'),
  statusChanged('STATUS_CHANGED', 'Status'),
  officerMessage('OFFICER_MESSAGE', 'Message');

  const TimelineEventKind(this.wire, this.label);

  final String wire;
  final String label;

  static TimelineEventKind fromWire(Object? value) {
    return TimelineEventKind.values.firstWhere(
      (TimelineEventKind kind) => kind.wire == value,
      orElse: () => TimelineEventKind.incidentRecorded,
    );
  }
}

/// Account roles recognised by the backend (`backend/src/security.js`).
enum UserRole {
  student('STUDENT'),
  officer('OFFICER'),
  admin('ADMIN');

  const UserRole(this.wire);

  final String wire;

  static UserRole fromWire(Object? value) {
    return UserRole.values.firstWhere(
      (UserRole role) => role.wire == value,
      orElse: () => UserRole.student,
    );
  }

  bool get isStaff => this != UserRole.student;
}
