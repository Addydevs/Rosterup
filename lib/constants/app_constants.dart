/// Central place for app-wide constants such as store URLs and support info.
class AppConstants {
  AppConstants._();

  /// App Store (iOS) download link.
  static const String appStoreUrl =
      'https://apps.apple.com/app/rosterup/id6745498149';

  /// Play Store (Android) download link.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.rosterup.app';

  /// Generic download link shown in share messages.
  /// Points to a landing page / smart link that redirects per platform.
  static const String downloadUrl = 'https://rosterup.app/download';

  /// Support email address.
  static const String supportEmail = 'rosterupapp@gmail.com';
}
