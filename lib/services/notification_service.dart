import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/game_detail_screen.dart';
import '../screens/home_screen.dart';
import '../utils/app_navigator.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _handlersRegistered = false;

  Future<void> initialize() async {
    // Remote (FCM) permissions
    await _messaging.requestPermission();

    // Register foreground/tap handlers exactly once for the app's lifetime.
    if (!_handlersRegistered) {
      _handlersRegistered = true;

      // App was launched from a terminated state by tapping a notification.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        // Defer so the first frame (HomeScreen) is mounted before we push.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // Notification tapped while the app was in the background.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data);
      });

      // Message received while the app is in the foreground. iOS/Android won't
      // show a system banner in this case, so surface it in-app with a CTA.
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    }
  }

  Future<String?> getFcmToken() {
    return _messaging.getToken();
  }

  Stream<String> get tokenStream => _messaging.onTokenRefresh;

  /// Routes a tapped notification to the most relevant screen based on the
  /// `data` payload sent by the Cloud Functions layer.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final navigator = AppNavigator.navigatorKey.currentState;
    if (navigator == null) return;

    final type = data['type'] as String?;
    final gameId = data['gameId'] as String?;

    switch (type) {
      case 'game_created':
      case 'game_reminder_24h':
      case 'game_reminder_2h':
      case 'game_reminder_1h':
      case 'confirmation_changed':
        if (gameId != null && gameId.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(gameId: gameId),
            ),
          );
        }
        break;
      case 'chat_message':
      case 'broadcast_message':
        // Open the Chat tab so the user can jump into the conversation.
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(initialTabIndex: 2),
          ),
          (route) => route.isFirst,
        );
        break;
      default:
        break;
    }
  }

  /// Shows an in-app banner for messages that arrive while the app is open.
  void _showForegroundMessage(RemoteMessage message) {
    final messenger = AppNavigator.messengerKey.currentState;
    final notification = message.notification;
    if (messenger == null || notification == null) return;

    final title = notification.title ?? 'RosterUp';
    final body = notification.body ?? '';

    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _handleNotificationTap(message.data),
        ),
      ),
    );
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
