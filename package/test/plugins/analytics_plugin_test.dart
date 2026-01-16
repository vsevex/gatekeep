import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('DefaultAnalyticsPlugin', () {
    late DefaultAnalyticsPlugin plugin;

    setUp(() {
      plugin = DefaultAnalyticsPlugin();
    });

    test('has correct properties', () {
      expect(plugin.id, 'default_analytics');
      expect(plugin.name, 'Default Analytics');
      expect(plugin.version, '1.0.0');
    });

    test(
      'initialize does nothing',
      () => expect(() => plugin.initialize(), returnsNormally),
    );

    test(
      'dispose does nothing',
      () => expect(() => plugin.dispose(), returnsNormally),
    );

    test('trackQueueJoin does nothing', () {
      expect(() => plugin.trackQueueJoin('evt_123'), returnsNormally);
      expect(
        () => plugin.trackQueueJoin('evt_123', properties: {'key': 'value'}),
        returnsNormally,
      );
    });

    test('trackQueuePosition does nothing', () {
      expect(() => plugin.trackQueuePosition('q_123', 50), returnsNormally);
      expect(
        () => plugin.trackQueuePosition(
          'q_123',
          50,
          properties: {'key': 'value'},
        ),
        returnsNormally,
      );
    });

    test('trackAdmission does nothing', () {
      expect(() => plugin.trackAdmission('q_123', 'evt_123'), returnsNormally);
      expect(
        () => plugin.trackAdmission(
          'q_123',
          'evt_123',
          properties: {'key': 'value'},
        ),
        returnsNormally,
      );
    });

    test('trackError does nothing', () {
      expect(
        () => plugin.trackError('error_type', 'error message'),
        returnsNormally,
      );
      expect(
        () => plugin.trackError(
          'error_type',
          'error message',
          properties: {'key': 'value'},
        ),
        returnsNormally,
      );
    });

    test('trackEvent does nothing', () {
      expect(() => plugin.trackEvent('custom_event'), returnsNormally);
      expect(
        () => plugin.trackEvent('custom_event', properties: {'key': 'value'}),
        returnsNormally,
      );
    });
  });

  group('AnalyticsPlugin interface', () {
    test('can be implemented', () {
      final plugin = _TestAnalyticsPlugin();

      expect(plugin, isA<AnalyticsPlugin>());
      expect(plugin, isA<Plugin>());
    });
  });
}

class _TestAnalyticsPlugin extends AnalyticsPlugin {
  @override
  String get id => 'test_analytics';

  @override
  String get name => 'Test Analytics';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  void trackQueueJoin(String eventId, {Map<String, dynamic>? properties}) {}

  @override
  void trackQueuePosition(
    String queueId,
    int position, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackAdmission(
    String queueId,
    String eventId, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackError(
    String errorType,
    String errorMessage, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {}
}
