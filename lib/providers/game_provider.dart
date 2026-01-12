import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/game.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';

class GameProvider extends ChangeNotifier {
  // Lazily access Firestore so local-only flows don't require Firebase.init.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  List<Game> _games = [];
  List<Game> _publicGames = [];
  bool _isLoading = false;
  String? _error;

  List<Game> get games => _games;
  List<Game> get publicGames => _publicGames;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<String> createGame({
    required String teamId,
    required DateTime dateTime,
    required String location,
    String? locationUrl,
    double? latitude,
    double? longitude,
    int? maxPlayersIn,
    String? notes,
    bool isRecurring = false,
    bool isPublic = true,
    String? accessCode,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      String? finalAccessCode = accessCode;
      if (!isPublic) {
        // Auto-generate an uppercase access code if one was not provided.
        if (finalAccessCode == null || finalAccessCode.trim().isEmpty) {
          finalAccessCode = await _generateUniqueAccessCode(teamId);
        } else {
          finalAccessCode = finalAccessCode.toUpperCase();
        }
      } else {
        finalAccessCode = null;
      }

      final game = Game(
        id: _uuid.v4(),
        teamId: teamId,
        dateTime: dateTime,
        location: location,
        locationUrl: locationUrl,
        latitude: latitude,
        longitude: longitude,
        maxPlayersIn: maxPlayersIn,
        isRecurring: isRecurring,
        isPublic: isPublic,
        accessCode: finalAccessCode,
        confirmations: {},
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('games').doc(game.id).set(game.toFirestore());
      
      _games.add(game);
      _games.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Analytics: game created (do not fail creation if analytics throws)
      try {
        await AnalyticsService.logCreateGame(
          gameId: game.id,
          teamId: teamId,
          isPublic: isPublic,
          isRecurring: isRecurring,
        );
      } catch (_) {
        // Ignore analytics errors so the user flow stays smooth.
      }

      // Schedule local reminders for this device: 24h and 1h before.
      try {
        final notificationService = NotificationService();
        await notificationService.initialize();

        final oneDayBefore = dateTime.subtract(const Duration(hours: 24));
        final oneHourBefore = dateTime.subtract(const Duration(hours: 1));

        await notificationService.scheduleGameReminder(
          id: game.id.hashCode,
          title: 'Game tomorrow',
          body: 'You have a game with your team in 24 hours.',
          scheduledTime: oneDayBefore,
        );

        await notificationService.scheduleGameReminder(
          id: game.id.hashCode ^ 1,
          title: 'Game soon',
          body: 'Your game starts in 1 hour.',
          scheduledTime: oneHourBefore,
        );
      } catch (_) {
        // Ignore local notification errors so game creation still succeeds.
      }
      
      return game.id;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _generateUniqueAccessCode(String teamId) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    bool exists = true;

    while (exists) {
      final buffer = StringBuffer();
      for (var i = 0; i < 6; i++) {
        final millis = DateTime.now().millisecondsSinceEpoch + i;
        buffer.write(chars[millis % chars.length]);
      }
      code = buffer.toString();

      final snapshot = await _firestore
          .collection('games')
          .where('teamId', isEqualTo: teamId)
          .where('accessCode', isEqualTo: code)
          .limit(1)
          .get();

      exists = snapshot.docs.isNotEmpty;
      if (!exists) return code;
    }

    return 'GAME$teamId'.substring(0, 6); // Fallback, very unlikely.
  }

  Future<void> confirmAttendance({
    required String gameId,
    required String userId,
    required ConfirmationStatus status,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update Firestore
      final updates = <String, Object?>{
        'confirmations.$userId': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Clear any previous decline reason when status is not declined.
      if (status != ConfirmationStatus.declined) {
        updates['declineReasons.$userId'] = FieldValue.delete();
      }

      await _firestore.collection('games').doc(gameId).update(updates);

      // Update local state
      final gameIndex = _games.indexWhere((g) => g.id == gameId);
      if (gameIndex != -1) {
        final updatedConfirmations = Map<String, ConfirmationStatus>.from(
          _games[gameIndex].confirmations,
        );
        updatedConfirmations[userId] = status;

        final updatedDeclineReasons =
            Map<String, String>.from(_games[gameIndex].declineReasons);
        if (status != ConfirmationStatus.declined) {
          updatedDeclineReasons.remove(userId);
        }

        _games[gameIndex] = _games[gameIndex].copyWith(
          confirmations: updatedConfirmations,
          declineReasons: updatedDeclineReasons,
        );
      }

      // Analytics: RSVP
      final game = getGameById(gameId);
      if (game != null) {
        await AnalyticsService.logGameRsvp(
          gameId: gameId,
          teamId: game.teamId,
          status: status.name,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setGuestCount({
    required String gameId,
    required String userId,
    required int guestCount,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updates = <String, Object?>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (guestCount <= 0) {
        updates['guestCounts.$userId'] = FieldValue.delete();
      } else {
        updates['guestCounts.$userId'] = guestCount;
      }

      await _firestore.collection('games').doc(gameId).update(updates);

      final gameIndex = _games.indexWhere((g) => g.id == gameId);
      if (gameIndex != -1) {
        final updatedGuestCounts =
            Map<String, int>.from(_games[gameIndex].guestCounts);

        if (guestCount <= 0) {
          updatedGuestCounts.remove(userId);
        } else {
          updatedGuestCounts[userId] = guestCount;
        }

        final updatedGame = _games[gameIndex].copyWith(
          guestCounts: updatedGuestCounts,
        );
        _games[gameIndex] = updatedGame;

        try {
          await AnalyticsService.logGamePlusOneToggled(
            gameId: updatedGame.id,
            teamId: updatedGame.teamId,
            hasGuest: guestCount > 0,
          );
        } catch (_) {
          // Ignore analytics failures so UX stays smooth.
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDeclineReason({
    required String gameId,
    required String userId,
    required String reasonCode,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('games').doc(gameId).update({
        'declineReasons.$userId': reasonCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final gameIndex = _games.indexWhere((g) => g.id == gameId);
      if (gameIndex != -1) {
        final updatedDeclineReasons =
            Map<String, String>.from(_games[gameIndex].declineReasons);
        updatedDeclineReasons[userId] = reasonCode;

        _games[gameIndex] = _games[gameIndex].copyWith(
          declineReasons: updatedDeclineReasons,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeamGames(String teamId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('games')
          .where('teamId', isEqualTo: teamId)
          .where('isActive', isEqualTo: true)
          .orderBy('dateTime')
          .get();

      _games = snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUpcomingGames(List<String> teamIds) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (teamIds.isEmpty) {
        _games = [];
        return;
      }

      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('games')
          .where('teamId', whereIn: teamIds)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .where('isActive', isEqualTo: true)
          .orderBy('dateTime')
          .limit(50)
          .get();

      _games = snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPublicUpcomingGames() async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('games')
          .where('isPublic', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dateTime')
          .limit(50)
          .get();

      _publicGames = snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateGameActive(String gameId, bool isActive) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final gameIndex = _games.indexWhere((g) => g.id == gameId);
      if (gameIndex != -1) {
        _games[gameIndex] = _games[gameIndex].copyWith(isActive: isActive);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Game> getActiveGames() {
    return _games.where((game) => game.isActive).toList();
  }

  List<Game> getUpcomingGames() {
    final now = DateTime.now();
    return _games.where((game) => 
        game.isActive && 
        game.dateTime.isAfter(now)
    ).toList();
  }

  List<Game> getGamesForTeam(String teamId) {
    return _games
        .where((game) => game.teamId == teamId && game.isActive)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Game? getNextUpcomingGameForTeam(String teamId) {
    final now = DateTime.now();
    final upcoming = _games
        .where(
          (g) =>
              g.teamId == teamId &&
              g.isActive &&
              g.dateTime.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Future<Game?> findFirstGameByAccessCode({
    required String teamId,
    required String accessCode,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('games')
          .where('teamId', isEqualTo: teamId)
          .where('accessCode', isEqualTo: accessCode.toUpperCase())
          .where('isActive', isEqualTo: true)
          .orderBy('dateTime')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Game.fromFirestore(snapshot.docs.first);
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  Game? getGameById(String gameId) {
    try {
      return _games.firstWhere((game) => game.id == gameId);
    } catch (e) {
      return null;
    }
  }

  int getConfirmedCount(String gameId, ConfirmationStatus status) {
    final game = getGameById(gameId);
    if (game == null) return 0;
    
    return game.confirmations.values
        .where((s) => s == status)
        .length;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<List<Game>> fetchPastGames(List<String> teamIds) async {
    if (teamIds.isEmpty) return [];

    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('games')
          .where('teamId', whereIn: teamIds)
          .where('dateTime', isLessThan: Timestamp.fromDate(now))
          .where('isActive', isEqualTo: true)
          .orderBy('dateTime', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<bool> deleteGame(String gameId) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final index = _games.indexWhere((g) => g.id == gameId);
      if (index != -1) {
        _games[index] = _games[index].copyWith(isActive: false);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGameDetails({
    required String gameId,
    DateTime? dateTime,
    String? location,
    int? maxPlayersIn,
  }) async {
    try {
      final updates = <String, Object?>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (dateTime != null) {
        updates['dateTime'] = Timestamp.fromDate(dateTime);
      }
      if (location != null) {
        updates['location'] = location;
      }
      if (maxPlayersIn != null) {
        updates['maxPlayersIn'] = maxPlayersIn;
      }

      await _firestore.collection('games').doc(gameId).update(updates);

      final index = _games.indexWhere((g) => g.id == gameId);
      if (index != -1) {
        _games[index] = _games[index].copyWith(
          dateTime: dateTime,
          location: location,
          maxPlayersIn: maxPlayersIn,
        );
        _games.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
