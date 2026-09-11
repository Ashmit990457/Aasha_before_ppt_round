import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/app_user.dart';
import '../data/models/auth_status.dart';
import '../features/auth/data/auth_service.dart';
import '../data/repositories/user_repository.dart';
import '../data/sync/sync_service.dart';

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  final SyncService syncService = SyncService.instance;

  User? _firebaseUser;
  AppUser? _userProfile;
  AuthStatus _status = AuthStatus.loading;
  bool _isAwaitingVerification = false;
  Timer? _verificationTimer;

  AppState() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
    syncService.addListener(_onSyncChanged);
  }

  void _onSyncChanged() => notifyListeners();

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  AppUser? get userProfile => _userProfile;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;
  bool get isAwaitingVerification => _isAwaitingVerification;

  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user == null) {
      _userProfile = null;
      _isAwaitingVerification = false;
      _status = AuthStatus.unauthenticated;
      _stopVerificationTimer();
    } else {
      if (user.emailVerified) {
        _isAwaitingVerification = false;
        _stopVerificationTimer();
        await _loadUserProfile(user.uid);
        if (_userProfile?.role == UserRole.official &&
            _userProfile?.approved == true) {
          unawaited(syncService.startSession(user.uid));
        }
      } else {
        // Firebase restores the session across app restarts. Keep an
        // unverified session alive and show the verification screen instead
        // of forcing the user to log in again.
        _status = AuthStatus.authenticatedUnverified;
        _startVerificationTimer();
      }
    }
    _updateStatus();
    notifyListeners();
  }

  void _startVerificationTimer() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await refreshEmailVerification();
    });
  }

  void _stopVerificationTimer() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
  }

  @override
  void dispose() {
    _stopVerificationTimer();
    unawaited(syncService.stopSession());
    syncService.removeListener(_onSyncChanged);
    syncService.dispose();
    super.dispose();
  }

  void _updateStatus() {
    if (_firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      return;
    }

    if (!_firebaseUser!.emailVerified) {
      _status = AuthStatus.authenticatedUnverified;
      return;
    }

    if (_userProfile == null) {
      // If we are authenticated and verified but have no profile doc, it's an error
      _status = AuthStatus.profileError;
      return;
    }

    if (_userProfile!.role == UserRole.official) {
      _status = _userProfile!.approved
          ? AuthStatus.authenticatedOfficial
          : AuthStatus.authenticatedOfficialPending;
    } else {
      _status = AuthStatus.authenticatedVerified;
    }
  }

  Future<void> _loadUserProfile(String uid) async {
    _userProfile = await _userRepository.getUserProfile(uid);
  }

  Future<void> refreshEmailVerification() async {
    if (_firebaseUser != null) {
      bool verified = await _authService.checkEmailVerified();
      if (verified) {
        _isAwaitingVerification = false;
        await _loadUserProfile(_firebaseUser!.uid);
      }
      _updateStatus();
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _status = AuthStatus.loading;
    _isAwaitingVerification = true;
    notifyListeners();

    try {
      final error = await _authService.signIn(email: email, password: password);

      if (error == null) {
        final user = _authService.currentUser;
        if (user != null && user.emailVerified) {
          _isAwaitingVerification = false;
          await _loadUserProfile(user.uid);
          if (_userProfile?.role == UserRole.official &&
              _userProfile?.approved == true) {
            unawaited(syncService.startSession(user.uid));
          }
        }
      } else {
        _isAwaitingVerification = false;
      }
      _updateStatus();
      notifyListeners();
      return error;
    } catch (e) {
      _isAwaitingVerification = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return 'Unable to complete login. Please check your connection and try again.';
    }
  }

  Future<String?> register(String email, String password, String name) async {
    _status = AuthStatus.loading;
    _isAwaitingVerification = true;
    notifyListeners();

    final error = await _authService.signUp(
      email: email,
      password: password,
      name: name,
    );

    if (error == null) {
      User? user = _authService.currentUser;
      if (user != null) {
        final newUser = AppUser(
          id: user.uid,
          name: name,
          email: email,
          role: UserRole.user,
          approved: true,
        );
        await _userRepository.createUserProfile(newUser);
        _userProfile = newUser;
      }
    } else {
      _isAwaitingVerification = false;
    }

    _updateStatus();
    notifyListeners();
    return error;
  }

  Future<void> logout() async {
    await syncService.stopSession();
    await _authService.signOut();
    _isAwaitingVerification = false;
    _firebaseUser = null;
    _userProfile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    return await _authService.sendPasswordResetEmail(email);
  }

  Future<String?> resendVerificationEmail() async {
    return await _authService.sendEmailVerification();
  }
}
