import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Auth state and anonymous sign-in.
class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _currentUser = _firebaseAuth.currentUser;
    _authSubscription = _firebaseAuth.authStateChanges().listen(
          _handleAuthStateChanged,
          onError: _handleAuthError,
        );
  }

  final FirebaseAuth _firebaseAuth;
  late final StreamSubscription<User?> _authSubscription;

  User? _currentUser;
  bool _isReady = false;
  Object? _lastError;

  User? get currentUser => _currentUser;
  String? get uid => _currentUser?.uid;
  bool get isReady => _isReady;
  Object? get lastError => _lastError;
  bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  String get displayName {
    final name = _currentUser?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Citizen Scientist';
  }

  /// Ensures the app has a Firebase user, creating an anonymous user if needed.
  Future<void> ensureSignedIn() async {
    try {
      _lastError = null;

      final existingUser = _firebaseAuth.currentUser;
      if (existingUser != null) {
        _currentUser = existingUser;
        _isReady = true;
        notifyListeners();
        return;
      }

      final credential = await _firebaseAuth.signInAnonymously();
      _currentUser = credential.user;
      _isReady = true;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      _isReady = true;
      notifyListeners();
      rethrow;
    }
  }

  void _handleAuthStateChanged(User? user) {
    _currentUser = user;
    _isReady = true;
    notifyListeners();
  }

  void _handleAuthError(Object error) {
    _lastError = error;
    _isReady = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
