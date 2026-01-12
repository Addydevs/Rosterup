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

  static Future<void> logHomeTabViewed({required String tab}) {
    return _analytics.logEvent(
      name: 'home_tab_viewed',
      parameters: {
        'tab': tab,
      },
    );
  }

  static Future<void> logTeamShare({
    required String teamId,
  }) {
    return _analytics.logEvent(
      name: 'team_share_clicked',
      parameters: {
        'team_id': teamId,
      },
    );
  }

  static Future<void> logGameShare({
    required String gameId,
    required String teamId,
    required bool isPublic,
    required bool hasAccessCode,
  }) {
    return _analytics.logEvent(
      name: 'game_share_clicked',
      parameters: {
        'game_id': gameId,
        'team_id': teamId,
        'is_public': isPublic,
        'has_access_code': hasAccessCode,
      },
    );
  }

  static Future<void> logGamePlusOneToggled({
    required String gameId,
    required String teamId,
    required bool hasGuest,
  }) {
    return _analytics.logEvent(
      name: 'game_plus_one_toggled',
      parameters: {
        'game_id': gameId,
        'team_id': teamId,
        'has_guest': hasGuest,
      },
    );
  }
}
