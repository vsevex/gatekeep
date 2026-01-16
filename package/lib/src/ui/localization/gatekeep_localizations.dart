import 'package:flutter/material.dart';

/// Localization helper for Gatekeep UI
class GatekeepLocalizations {
  const GatekeepLocalizations(this.locale);

  final Locale locale;

  /// Get localization from context
  static GatekeepLocalizations? of(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return GatekeepLocalizations(locale);
  }

  /// Format duration as human-readable string
  String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format estimated wait time
  String formatEstimatedWait(Duration duration) {
    final formatted = formatDuration(duration);
    return 'Estimated wait: $formatted';
  }

  /// Get position in queue message
  String positionInQueue(int position) => 'You are #$position in line';

  /// Get queue title
  String get queueTitle => 'Waiting Room';

  /// Get joining queue message
  String get joiningQueue => 'Joining queue...';

  /// Get admitted message
  String get admitted => "You're in!";

  /// Get token expired message
  String get tokenExpired => 'Your admission token has expired';

  /// Get error occurred message
  String get errorOccurred => 'An error occurred';

  /// Get retry button text
  String get retry => 'Retry';

  /// Get cancel button text
  String get cancel => 'Cancel';

  /// Get heartbeat status message
  String get heartbeatStatus => 'Connection active';

  /// Get heartbeat failed message
  String get heartbeatFailed => 'Connection lost';

  /// Format minutes with pluralization
  String minutes(int count) {
    if (count == 0) {
      return '0 minutes';
    }
    if (count == 1) {
      return '1 minute';
    }
    return '$count minutes';
  }

  /// Format seconds with pluralization
  String seconds(int count) {
    if (count == 0) {
      return '0 seconds';
    }
    if (count == 1) {
      return '1 second';
    }
    return '$count seconds';
  }
}

/// RTL helper utilities
class RTLHelper {
  const RTLHelper._();

  static bool isRTL(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  static TextDirection textDirection(BuildContext context) {
    final direction = Directionality.of(context);
    return direction == TextDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static AlignmentGeometry alignment(
    BuildContext context,
    AlignmentGeometry ltr,
    AlignmentGeometry rtl,
  ) => isRTL(context) ? rtl : ltr;

  static EdgeInsetsDirectional padding(
    BuildContext context,
    EdgeInsetsDirectional ltr,
    EdgeInsetsDirectional rtl,
  ) => isRTL(context) ? rtl : ltr;
}
