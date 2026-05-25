import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/analytics_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<ChatMessage>> _messagesByTeam = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _subscriptions = {};

  /// Timestamp of the last message the user has "seen" per team.
  final Map<String, DateTime> _lastReadTimestamps = {};

  ChatProvider() {
    _loadPersistedTimestamps();
  }

  Future<void> _loadPersistedTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('chat_last_read_'));
      for (final key in keys) {
        final teamId = key.replaceFirst('chat_last_read_', '');
        final tsStr = prefs.getString(key);
        if (tsStr != null) {
          _lastReadTimestamps[teamId] = DateTime.parse(tsStr);
        }
      }
      notifyListeners();
    } catch (_) {
      // Ignore; unread counts will reset on cold start if prefs are unavailable.
    }
  }

  Future<void> _persistTimestamp(String teamId, DateTime ts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'chat_last_read_$teamId',
        ts.toIso8601String(),
      );
    } catch (_) {
      // Best-effort; badge count may reset on next cold start.
    }
  }

  List<ChatMessage> messagesForTeam(String teamId) {
    final list = _messagesByTeam[teamId] ?? const [];
    final sorted = [...list]
      ..sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );
    return sorted;
  }

  /// Returns the total number of unread messages across all teams.
  int get totalUnreadCount {
    int count = 0;
    for (final entry in _messagesByTeam.entries) {
      final teamId = entry.key;
      final lastRead = _lastReadTimestamps[teamId];
      if (lastRead == null) {
        count += entry.value.length;
      } else {
        count += entry.value
            .where((m) => m.createdAt.isAfter(lastRead))
            .length;
      }
    }
    return count;
  }

  /// Returns unread count for a single team.
  int unreadCountForTeam(String teamId) {
    final messages = _messagesByTeam[teamId] ?? [];
    final lastRead = _lastReadTimestamps[teamId];
    if (lastRead == null) return messages.length;
    return messages.where((m) => m.createdAt.isAfter(lastRead)).length;
  }

  /// Mark all messages in a team as read.
  void markTeamAsRead(String teamId) {
    final messages = _messagesByTeam[teamId];
    if (messages != null && messages.isNotEmpty) {
      final latest = messages
          .map((m) => m.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      _lastReadTimestamps[teamId] = latest;
      notifyListeners();
      _persistTimestamp(teamId, latest);
    }
  }

  void subscribeToTeam(String teamId) {
    if (_subscriptions.containsKey(teamId)) return;

    final sub = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        _messagesByTeam[teamId] =
            snapshot.docs.map(ChatMessage.fromFirestore).toList();
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) {
          print('Chat subscription error for team $teamId: $e');
        }
      },
    );

    _subscriptions[teamId] = sub;
  }

  Future<void> sendMessage({
    required String teamId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('messages')
        .add({
      'teamId': teamId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Analytics: chat message sent
    await AnalyticsService.logChatMessage(teamId: teamId);
  }

  Future<bool> deleteMessage({
    required String teamId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('teams')
          .doc(teamId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting message $messageId for team $teamId: $e');
      }
      return false;
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
