import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('GatekeepConfig', () {
    test('creates config with required fields', () {
      const config = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(config.baseUrl, 'https://test.example.com/v1');
      expect(config.deviceId, 'test-device-id');
    });

    test('validates successfully with valid config', () {
      const config = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(() => config.validate(), returnsNormally);
    });

    test('validate throws on empty baseUrl', () {
      const config = GatekeepConfig(baseUrl: '', deviceId: 'test-device-id');

      expect(() => config.validate(), throwsArgumentError);
    });

    test('validate throws on empty deviceId', () {
      const config = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: '',
      );

      expect(() => config.validate(), throwsArgumentError);
    });

    test('validate throws on invalid URL', () {
      const config = GatekeepConfig(
        baseUrl: 'not-a-url',
        deviceId: 'test-device-id',
      );

      expect(() => config.validate(), throwsArgumentError);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      final updated = original.copyWith(debug: true);

      expect(updated.debug, isTrue);
      expect(updated.baseUrl, original.baseUrl);
      expect(updated.deviceId, original.deviceId);
    });
  });

  group('GatekeepInitializer', () {
    test('initialize creates config with defaults', () {
      final config = GatekeepInitializer.initialize(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(config.baseUrl, 'https://test.example.com/v1');
      expect(config.deviceId, 'test-device-id');
      expect(config.httpClient, isNotNull);
      expect(config.storage, isNotNull);
      expect(config.retryStrategy, isNotNull);
      expect(config.queueRetryStrategy, isNotNull);
    });

    test('initializeWith allows full customization', () {
      final config = GatekeepInitializer.initializeWith(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
        timeout: const Duration(seconds: 60),
        pollInterval: const Duration(seconds: 10),
      );

      expect(config.timeout, const Duration(seconds: 60));
      expect(config.pollInterval, const Duration(seconds: 10));
    });
  });
}
