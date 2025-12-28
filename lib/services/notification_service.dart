import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Remote (FCM) permissions
    await _messaging.requestPermission();
    // Local scheduled notifications are disabled due to a plugin
    // compile error outside this app.
  }

  Future<String?> getFcmToken() async {
    return _messaging.getToken();
  }

  Stream<String> get tokenStream {
    return _messaging.onTokenRefresh;
  }

  Future<void> scheduleGameReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // No-op: local scheduling is turned off until the
    // flutter_local_notifications plugin is updated/fixed.
    return;
  }
}
