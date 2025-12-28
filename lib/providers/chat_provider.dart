import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/analytics_service.dart';

class ChatMessage {
  final String id;
  final String teamId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<ChatMessage>> _messagesByTeam = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _subscriptions = {};

  List<ChatMessage> messagesForTeam(String teamId) {
    final list = _messagesByTeam[teamId] ?? const [];
    final sorted = [...list]
      ..sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );
    return sorted;
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
