import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String teamId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isBroadcast;

  ChatMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.isBroadcast = false,
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
      isBroadcast: (data['isBroadcast'] as bool?) ?? false,
    );
  }
}
