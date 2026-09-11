import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user?.updateDisplayName(name);
      await result.user?.sendEmailVerification();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapExceptionToMessage(e);
    } catch (e) {
      // Handle PlatformException or other errors that might contain pigeon strings
      if (e.toString().contains('pigeon')) {
        return 'Connection error. Please stop the app and run it again (full restart).';
      }
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw FirebaseAuthException(
              code: 'network-request-failed',
              message: 'The login request timed out.',
            ),
          );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapExceptionToMessage(e);
    } catch (e) {
      // Handle PlatformException or other errors that might contain pigeon strings
      if (e.toString().contains('pigeon')) {
        return 'Connection error. Please stop the app and run it again (full restart).';
      }
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapExceptionToMessage(e);
    } catch (e) {
      if (e.toString().contains('pigeon')) {
        return 'Connection error. Please stop the app and run it again (full restart).';
      }
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException [${e.code}]: ${e.message}');
      return _mapExceptionToMessage(e);
    } catch (e) {
      debugPrint('Unexpected error during email verification: $e');
      return 'An unexpected error occurred.';
    }
  }

  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  String _mapExceptionToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'requires-recent-login':
        return 'Please login again to perform this sensitive action.';
      case 'operation-not-allowed':
        return 'This operation is not currently enabled.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}
