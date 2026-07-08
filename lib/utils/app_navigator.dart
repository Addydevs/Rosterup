import 'package:flutter/material.dart';

/// Global keys so services (e.g. push notifications, deep links) can navigate
/// and show messages without a [BuildContext].
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
}
