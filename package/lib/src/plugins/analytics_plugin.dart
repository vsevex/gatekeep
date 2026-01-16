import 'plugin_interface.dart';

/// Plugin for analytics tracking
abstract class AnalyticsPlugin extends Plugin {
  /// Track queue join event
  void trackQueueJoin(String eventId, {Map<String, dynamic>? properties});

  /// Track queue position update
  void trackQueuePosition(
    String queueId,
    int position, {
    Map<String, dynamic>? properties,
  });

  /// Track admission
  void trackAdmission(
    String queueId,
    String eventId, {
    Map<String, dynamic>? properties,
  });

  /// Track error
  void trackError(
    String errorType,
    String errorMessage, {
    Map<String, dynamic>? properties,
  });

  /// Track custom event
  void trackEvent(String eventName, {Map<String, dynamic>? properties});
}

/// Default no-op analytics plugin
class DefaultAnalyticsPlugin extends AnalyticsPlugin {
  @override
  String get id => 'default_analytics';

  @override
  String get name => 'Default Analytics';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {
    // No-op
  }

  @override
  Future<void> dispose() async {
    // No-op
  }

  @override
  void trackQueueJoin(String eventId, {Map<String, dynamic>? properties}) {
    // No-op
  }

  @override
  void trackQueuePosition(
    String queueId,
    int position, {
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void trackAdmission(
    String queueId,
    String eventId, {
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void trackError(
    String errorType,
    String errorMessage, {
    Map<String, dynamic>? properties,
  }) {
    // No-op
  }

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {
    // No-op
  }
}
