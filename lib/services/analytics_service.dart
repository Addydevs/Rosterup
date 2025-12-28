import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logLogin({String method = 'email'}) {
    return _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp({String method = 'email'}) {
    return _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> logCreateTeam({
    required String teamId,
    required String sport,
    bool hasCustomSport = false,
  }) {
    return _analytics.logEvent(
      name: 'create_team',
      parameters: {
        'team_id': teamId,
        'sport': sport,
        'has_custom_sport': hasCustomSport,
      },
    );
  }

  static Future<void> logCreateGame({
    required String gameId,
    required String teamId,
    required bool isPublic,
    required bool isRecurring,
  }) {
    return _analytics.logEvent(
      name: 'create_game',
      parameters: {
        'game_id': gameId,
        'team_id': teamId,
        'is_public': isPublic,
        'is_recurring': isRecurring,
      },
    );
  }

  static Future<void> logGameRsvp({
    required String gameId,
    required String teamId,
    required String status,
  }) {
    return _analytics.logEvent(
      name: 'game_rsvp',
      parameters: {
        'game_id': gameId,
        'team_id': teamId,
        'status': status,
      },
    );
  }

  static Future<void> logChatMessage({
    required String teamId,
  }) {
    return _analytics.logEvent(
      name: 'chat_message_sent',
      parameters: {
        'team_id': teamId,
      },
    );
  }
}

