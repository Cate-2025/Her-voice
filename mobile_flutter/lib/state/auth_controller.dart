import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/hervoice_repository.dart';
import '../data/secure_store.dart';
import '../models/auth_user.dart';

enum AuthStatus { checking, signedOut, signedIn }

/// Owns the session: it restores the encrypted token at start-up (section 3.12,
/// items I and IV) and exposes the signed-in account to the widget tree.
class AuthController extends ChangeNotifier {
  AuthController({required HerVoiceRepository repository, required SecureSessionStore secureStore})
      : _repository = repository,
        _secureStore = secureStore;

  final HerVoiceRepository _repository;
  final SecureSessionStore _secureStore;

  AuthStatus _status = AuthStatus.checking;
  AuthUser? _user;
  String? _errorMessage;
  bool _busy = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  bool get isStaff => _user?.isStaff ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Restores a previous session without forcing the student to sign in again.
  Future<void> bootstrap() async {
    final String? token = await _secureStore.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _repository.api.setToken(token);
    try {
      _user = await _repository.currentUser();
      _status = AuthStatus.signedIn;
    } on ApiException {
      // The token expired or was revoked; clear it rather than looping on a
      // broken session.
      await _secureStore.clear();
      _repository.api.setToken(null);
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ({String token, AuthUser user}) session =
          await _repository.login(email: email, password: password);
      await _secureStore.writeToken(session.token);
      _user = session.user;
      _status = AuthStatus.signedIn;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (error) {
      _errorMessage = 'Could not sign in: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final AuthUser account = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      // Registration signs the student straight in, so the token is persisted
      // the same way a normal login would persist it.
      final String? token = _repository.api.token;
      if (token != null) await _secureStore.writeToken(token);
      _user = account;
      _status = AuthStatus.signedIn;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (error) {
      _errorMessage = 'Could not create the account: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool clearPendingQueue = false}) async {
    if (clearPendingQueue) await _repository.queue.clearAll();
    await _secureStore.clear();
    _repository.api.setToken(null);
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
