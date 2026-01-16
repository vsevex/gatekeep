import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform check utilities for mobile-only package
class PlatformCheck {
  const PlatformCheck._();

  /// Check if running on iOS
  static bool get isIOS {
    if (kIsWeb) {
      return false;
    }
    return Platform.isIOS;
  }

  /// Check if running on Android
  static bool get isAndroid {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid;
  }

  /// Check if running on mobile (iOS or Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Check if running on web
  static bool get isWeb => kIsWeb;

  /// Check if running on desktop
  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// Assert that the current platform is mobile
  /// Throws [UnsupportedError] if not on mobile
  static void assertMobile() {
    if (!isMobile) {
      throw UnsupportedError(
        'Gatekeep package only supports iOS and Android platforms. '
        'Current platform: ${_getPlatformName()}',
      );
    }
  }

  /// Get platform name for error messages
  static String _getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    }
    if (Platform.isIOS) {
      return 'iOS';
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isMacOS) {
      return 'macOS';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }

  /// Get platform-specific identifier
  static String get platformName => _getPlatformName();
}
