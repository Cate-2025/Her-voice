import 'package:flutter/foundation.dart';

import '../data/admin_repository.dart';
import '../data/api_client.dart';
import '../models/app_notification.dart';
import '../models/audit_entry.dart';
import '../models/enums.dart';
import '../models/incident_report.dart';

/// Backs the institutional dashboard (section 7.2).
class AdminController extends ChangeNotifier {
  AdminController(this._repository);

  final AdminRepository _repository;

  AdminDashboard? _dashboard;
  List<CaseSummary> _cases = <CaseSummary>[];
  IncidentReport? _selected;
  List<PatternAlert> _alerts = <PatternAlert>[];
  String _alertNotice = '';
  int _alertThreshold = 3;
  List<AuditEntry> _audit = <AuditEntry>[];
  bool _loading = false;
  bool _busy = false;
  String? _errorMessage;

  AdminDashboard? get dashboard => _dashboard;
  List<CaseSummary> get cases => _cases;
  IncidentReport? get selected => _selected;
  List<PatternAlert> get alerts => _alerts;
  String get alertNotice => _alertNotice;
  int get alertThreshold => _alertThreshold;
  List<AuditEntry> get audit => _audit;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();
    try {
      _dashboard = await _repository.dashboard();
      _cases = _dashboard!.cases;
      _alerts = _dashboard!.alerts;
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAlerts() async {
    try {
      final ({int threshold, String notice, List<PatternAlert> alerts}) result =
          await _repository.patternAlerts();
      _alerts = result.alerts;
      _alertNotice = result.notice;
      _alertThreshold = result.threshold;
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadAuditLog() async {
    try {
      _audit = await _repository.auditLog();
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      notifyListeners();
    }
  }

  Future<void> openCase(String caseId) async {
    _busy = true;
    notifyListeners();
    try {
      _selected = await _repository.caseDetail(caseId);
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(String caseId, CaseStatus status, {String? note}) async {
    _busy = true;
    notifyListeners();
    try {
      _selected = await _repository.updateStatus(caseId, status, note: note);
      await loadDashboard();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> sendSecureMessage(String caseId, String message) async {
    _busy = true;
    notifyListeners();
    try {
      _selected = await _repository.sendSecureMessage(caseId, message);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> assignToMe(String caseId) async {
    _busy = true;
    notifyListeners();
    try {
      _selected = await _repository.assignCase(caseId);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
