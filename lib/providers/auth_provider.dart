import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  // Access FirebaseAuth lazily so provider construction itself
  // doesn't fail if Firebase isn't ready yet.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;
  String? _lastError;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  AuthProvider() {
    // Seed with any already-signed-in Firebase user so that
    // `isAuthenticated` is accurate on app startup before the
    // authStateChanges stream emits its first value.
    _user = _auth.currentUser;

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _lastError = null;
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await AnalyticsService.logLogin(method: 'email');
      await AnalyticsService.setUserId(_auth.currentUser?.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      _lastError = _friendlyAuthError(e.code);
      return false;
    } catch (e) {
      debugPrint('Sign in error (unexpected): $e');
      // Workaround: if Firebase actually signed the user in (currentUser is set),
      // treat this as a successful sign-in despite the unexpected error.
      if (_auth.currentUser != null) {
        debugPrint('Sign in succeeded despite unexpected error (currentUser is set).');
        return true;
      }
      _lastError = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUserWithEmailAndPassword(String email, String password) async {
    _lastError = null;
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await AnalyticsService.logSignUp(method: 'email');
      await AnalyticsService.setUserId(_auth.currentUser?.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign up error: ${e.message}');
      _lastError = _friendlyAuthError(e.code);
      return false;
    } catch (e) {
      debugPrint('Sign up error (unexpected): $e');
      // Workaround: if Firebase actually created and signed in the user,
      // consider this a success so the UI can proceed.
      if (_auth.currentUser != null) {
        debugPrint('Sign up succeeded despite unexpected error (currentUser is set).');
        return true;
      }
      _lastError = 'An unexpected error occurred. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _lastError = null;
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} – ${e.message}');
      _lastError = _friendlyAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Password reset error (unexpected): $e');
      _lastError = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await AnalyticsService.setUserId(null);
    await _auth.signOut();
  }

  static String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
