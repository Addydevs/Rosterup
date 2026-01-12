import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  // Access FirebaseAuth lazily so provider construction itself
  // doesn't fail if Firebase isn't ready yet.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

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
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await AnalyticsService.logLogin(method: 'email');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Sign in error (unexpected): $e');
      // Workaround: if Firebase actually signed the user in (currentUser is set),
      // treat this as a successful sign-in despite the unexpected error.
      if (_auth.currentUser != null) {
        debugPrint('Sign in succeeded despite unexpected error (currentUser is set).');
        return true;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await AnalyticsService.logSignUp(method: 'email');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign up error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Sign up error (unexpected): $e');
      // Workaround: if Firebase actually created and signed in the user,
      // consider this a success so the UI can proceed.
      if (_auth.currentUser != null) {
        debugPrint('Sign up succeeded despite unexpected error (currentUser is set).');
        return true;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Password reset error (unexpected): $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // mockSignIn kept previously for local-only flows has been removed in favor
  // of real Firebase Authentication.
}
