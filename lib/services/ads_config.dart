import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Gates ad serving behind the `ads_enabled` Remote Config flag.
///
/// Ads default to OFF (both here and in the Remote Config template) so they
/// can be turned on later from the Firebase console — no app release needed.
class AdsConfig {
  AdsConfig._();

  static const _adsEnabledKey = 'ads_enabled';

  static bool _fetched = false;
  static bool _enabled = false;

  /// Last known value; false until [load] has completed successfully.
  static bool get enabled => _enabled;

  /// Fetches the flag once per app session (12h server-side cache).
  static Future<bool> load() async {
    if (_fetched) return _enabled;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 12),
        ),
      );
      await remoteConfig.setDefaults(const {_adsEnabledKey: false});
      await remoteConfig.fetchAndActivate();
      _enabled = remoteConfig.getBool(_adsEnabledKey);
      _fetched = true;
    } catch (_) {
      // Network/config issues: keep ads off rather than risk a bad experience.
      _enabled = false;
    }
    return _enabled;
  }
}
