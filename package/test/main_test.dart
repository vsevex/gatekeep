import 'package:flutter_test/flutter_test.dart';
import 'package:gatekeep/gatekeep.dart';

void main() {
  group('Gatekeep SDK', () {
    test('can create QueueClient with factory', () {
      final client = QueueClientFactory.create(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(client, isNotNull);
      expect(client, isA<QueueClientInterface>());
    });

    test('GatekeepConfig validates correctly', () {
      const config = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
      );

      expect(() => config.validate(), returnsNormally);
    });

    test('GatekeepConfig throws on invalid baseUrl', () {
      const config = GatekeepConfig(baseUrl: '', deviceId: 'test-device-id');

      expect(() => config.validate(), throwsArgumentError);
    });
  });
}
