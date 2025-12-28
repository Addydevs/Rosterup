import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart';

class UserProvider extends ChangeNotifier {
  // Access Firestore lazily so this provider can be constructed
  // even in environments where Firebase isn't initialized yet.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  AppUser? _currentUser;
  final Map<String, AppUser> _usersById = {};
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  AppUser? getUserById(String id) => _usersById[id];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCurrentUser(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final user = AppUser.fromFirestore(doc);
        _currentUser = user;
        _usersById[user.id] = user;
      } else {
        _currentUser = null;
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading user: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createOrUpdateUser(AppUser user) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(user.id).set(
            user.toFirestore(),
            SetOptions(merge: true),
          );
      _currentUser = user;
      _usersById[user.id] = user;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error saving user: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUsersByIds(List<String> ids) async {
    final toFetch =
        ids.where((id) => id.isNotEmpty && !_usersById.containsKey(id)).toList();
    if (toFetch.isEmpty) return;

    try {
      for (final id in toFetch) {
        final doc = await _firestore.collection('users').doc(id).get();
        if (doc.exists) {
          final user = AppUser.fromFirestore(doc);
          _usersById[user.id] = user;
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading users: $e');
      }
      notifyListeners();
    }
  }

  Future<void> addFcmToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error adding FCM token: $e');
      }
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    final current = _currentUser;
    if (current == null) return;

    final updated = current.copyWith(preferences: preferences);
    await createOrUpdateUser(updated);
  }

  Future<bool> deleteAccountData(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('users').doc(uid).delete();

      if (_currentUser?.id == uid) {
        _currentUser = null;
      }
      _usersById.remove(uid);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error deleting user data: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentUser = null;
    _usersById.clear();
    _error = null;
    notifyListeners();
  }
}
