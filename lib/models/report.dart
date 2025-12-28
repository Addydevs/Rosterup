import 'package:cloud_firestore/cloud_firestore.dart';

class ContentReport {
  final String id;
  final String reporterId;
  final String? reportedUserId;
  final String? messageId;
  final String? teamId;
  final String? messageText;
  final String type; // e.g. user, message
  final String reason;
  final String? additionalDetails;
  final DateTime createdAt;
  final String status; // e.g. open, reviewed, dismissed

  ContentReport({
    required this.id,
    required this.reporterId,
    this.reportedUserId,
    this.messageId,
    this.teamId,
    this.messageText,
    required this.type,
    required this.reason,
    this.additionalDetails,
    required this.createdAt,
    this.status = 'open',
  });

  factory ContentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentReport(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'],
      messageId: data['messageId'],
      teamId: data['teamId'],
      messageText: data['messageText'],
      type: data['type'] ?? '',
      reason: data['reason'] ?? '',
      additionalDetails: data['additionalDetails'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'open',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'messageId': messageId,
      'teamId': teamId,
      'messageText': messageText,
      'type': type,
      'reason': reason,
      'additionalDetails': additionalDetails,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}

