import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/hervoice_repository.dart';
import '../models/enums.dart';
import '../models/evidence_item.dart';
import '../models/incident_report.dart';

/// Loads and mutates incidents and cases, and keeps the on-device queue in view
/// so the student always knows what has actually reached the institution.
class CaseController extends ChangeNotifier {
  CaseController(this._repository);

  final HerVoiceRepository _repository;

  List<CaseSummary> _cases = <CaseSummary>[];
  IncidentReport? _selected;
  int _pendingCount = 0;
  bool _loading = false;
  bool _busy = false;
  String? _errorMessage;
  int _patternAlertNotice = 0;

  List<CaseSummary> get cases => _cases;
  IncidentReport? get selected => _selected;
  int get pendingCount => _pendingCount;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  int get patternAlertNotice => _patternAlertNotice;

  List<CaseSummary> get drafts =>
      _cases.where((CaseSummary item) => item.isDraft).toList();

  List<CaseSummary> get submitted =>
      _cases.where((CaseSummary item) => !item.isDraft).toList();

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshPendingCount() async {
    final int next = await _repository.pendingCount();
    if (next == _pendingCount) return;
    _pendingCount = next;
    notifyListeners();
  }

  Future<void> loadCases({bool showSpinner = true}) async {
    if (showSpinner) {
      _loading = true;
      notifyListeners();
    }
    try {
      _cases = await _repository.listCases();
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _loading = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  Future<void> openCase(String caseId) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selected = await _repository.getCase(caseId);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates an incident from the reporting form. The repository decides whether
  /// it travels now or waits in the local queue.
  Future<SubmitOutcome> createIncident(
    IncidentDraft draft, {
    required bool saveAsDraft,
    required bool forceOffline,
  }) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SubmitOutcome outcome = await _repository.createIncident(
        draft,
        asDraft: saveAsDraft,
        forceOffline: forceOffline,
      );
      if (outcome.patternDetected) _patternAlertNotice += 1;
      return outcome;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _busy = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  Future<EvidenceItem> attachEvidence(String reportId, EvidenceUpload upload) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final EvidenceItem item = await _repository.attachEvidence(reportId, upload);
      if (_selected != null && _selected!.id == reportId) {
        _selected = await _repository.getCase(reportId);
      }
      return item;
    } finally {
      _busy = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  Future<void> removeEvidence(String reportId, String evidenceId) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.deleteEvidence(reportId, evidenceId);
      if (_selected != null && _selected!.id == reportId) {
        _selected = await _repository.getCase(reportId);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Records a subsequent incident on the timeline (section 3.1 A, item VII).
  Future<void> addFollowUp(String caseId, {required String title, String? detail}) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.addFollowUp(caseId, title: title, detail: detail);
      _selected = await _repository.getCase(caseId);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<SubmitOutcome?> submitDraft(String caseId) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SubmitOutcome outcome = await _repository.submitDraft(caseId);
      _selected = await _repository.getCase(caseId);
      await loadCases(showSpinner: false);
      return outcome;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Flushes the offline queue and reports back what happened.
  Future<SyncOutcome> synchronise({String? caseIdForEvidence}) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final SyncOutcome outcome =
          await _repository.synchronise(caseIdForEvidence: caseIdForEvidence);
      _patternAlertNotice += outcome.patternAlerts;
      await loadCases(showSpinner: false);
      return outcome;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return const SyncOutcome(synced: 0, failed: 0);
    } finally {
      _busy = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  /// Counts how many cases the student has in a given status, used by the
  /// progress tracker on the case detail screen.
  int countByStatus(CaseStatus status) =>
      _cases.where((CaseSummary item) => item.status == status).length;
}
