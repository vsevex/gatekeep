import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('AdmissionToken', () {
    test('creates token from JSON correctly', () {
      final json = {
        'token': 'test_token_123',
        'event_id': 'evt_test_123',
        'device_id': 'test-device-id',
        'user_id': 'test-user-id',
        'issued_at': '2024-01-15T10:30:00Z',
        'expires_at': '2024-01-15T10:35:00Z',
        'queue_id': 'q_test_123',
      };

      final token = AdmissionToken.fromJson(json);

      expect(token.token, 'test_token_123');
      expect(token.eventId, 'evt_test_123');
      expect(token.deviceId, 'test-device-id');
      expect(token.userId, 'test-user-id');
      expect(token.queueId, 'q_test_123');
    });

    test('converts to JSON correctly', () {
      final token = TestHelpers.createTestAdmissionToken();
      final json = token.toJson();

      expect(json['token'], token.token);
      expect(json['event_id'], token.eventId);
      expect(json['device_id'], token.deviceId);
      expect(json['issued_at'], isNotNull);
      expect(json['expires_at'], isNotNull);
    });

    test('isValid returns true for valid token', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(token.isValid(), isTrue);
    });

    test('isValid returns false for expired token', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(token.isValid(), isFalse);
    });

    test('remainingValidity returns correct duration', () {
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      final token = TestHelpers.createTestAdmissionToken(expiresAt: expiresAt);

      final remaining = token.remainingValidity();
      expect(remaining.inMinutes, greaterThanOrEqualTo(4));
      expect(remaining.inMinutes, lessThanOrEqualTo(6));
    });

    test('remainingValidity returns zero for expired token', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(token.remainingValidity().inSeconds, 0);
    });

    test('isExpiringSoon returns true when expiring soon', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );

      expect(token.isExpiringSoon(), isTrue);
    });

    test('isExpiringSoon returns false when not expiring soon', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      expect(token.isExpiringSoon(), isFalse);
    });

    test('getTimeUntilExpiry returns correct format', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      final timeStr = token.getTimeUntilExpiry();
      expect(timeStr, contains('minute'));
    });

    test('getTimeUntilExpiry returns "Expired" for expired token', () {
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(token.getTimeUntilExpiry(), 'Expired');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = TestHelpers.createTestAdmissionToken();
      final updated = original.copyWith(userId: 'new-user-id');

      expect(updated.userId, 'new-user-id');
      expect(updated.token, original.token);
      expect(updated.eventId, original.eventId);
    });

    test('equality works correctly', () {
      final token1 = TestHelpers.createTestAdmissionToken(
        token: 'same_token',
        eventId: 'same_event',
        deviceId: 'same_device',
      );
      final token2 = TestHelpers.createTestAdmissionToken(
        token: 'same_token',
        eventId: 'same_event',
        deviceId: 'same_device',
      );

      expect(token1 == token2, isTrue);
      expect(token1.hashCode, token2.hashCode);
    });

    test('toString returns meaningful string', () {
      final token = TestHelpers.createTestAdmissionToken();
      final str = token.toString();

      expect(str, contains(token.eventId));
      expect(str, contains('valid'));
    });
  });
}
