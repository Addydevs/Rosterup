import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ReportProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<bool> _submitReport(Map<String, dynamic> data) async {
    try {
      _isSubmitting = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('reports').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      return true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error submitting report: $e');
      }
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? additionalDetails,
  }) {
    return _submitReport({
      'type': 'user',
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'additionalDetails': additionalDetails,
    });
  }

  Future<bool> reportMessage({
    required String reporterId,
    required String reportedUserId,
    required String teamId,
    required String messageId,
    required String messageText,
    required String reason,
    String? additionalDetails,
  }) {
    return _submitReport({
      'type': 'message',
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'teamId': teamId,
      'messageId': messageId,
      'messageText': messageText,
      'reason': reason,
      'additionalDetails': additionalDetails,
    });
  }
}

