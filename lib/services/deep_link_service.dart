import 'dart:async';

import 'package:app_links/app_links.dart';

/// Handles incoming deep links of the form:
///   rosterup://join-team?code=WMH8KQ
///
/// Call [init] once from the app's root widget and pass a [navigatorKey]
/// so the service can push routes when a link arrives.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _sub;

  /// The team code extracted from the initial deep link that launched the app
  /// (cold start). Null if the app was opened normally.
  String? initialTeamCode;

  /// Callback that the root widget sets so this service can navigate when a
  /// deep link arrives while the app is already running (warm start).
  void Function(String teamCode)? onTeamCodeReceived;

  /// Call once at startup. Returns the team code from the initial (cold-start)
  /// link, if any.
  Future<String?> init() async {
    // --- Cold start ---
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        initialTeamCode = _extractTeamCode(initialUri);
      }
    } catch (_) {
      // No initial link – app opened normally.
    }

    // --- Warm start / foreground link ---
    _sub = _appLinks.uriLinkStream.listen((uri) {
      final code = _extractTeamCode(uri);
      if (code != null && onTeamCodeReceived != null) {
        onTeamCodeReceived!(code);
      }
    });

    return initialTeamCode;
  }

  /// Extracts the `code` query parameter from a URI like
  /// `rosterup://join-team?code=WMH8KQ`.
  String? _extractTeamCode(Uri uri) {
    if (uri.host == 'join-team' || uri.path.contains('join-team')) {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        return code.toUpperCase();
      }
    }
    return null;
  }

  void dispose() {
    _sub?.cancel();
  }
}
