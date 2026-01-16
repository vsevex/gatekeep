import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('TokenException', () {
    test('creates expired token exception', () {
      final exception = TokenException.expired('token_123');

      expect(exception.isExpired, isTrue);
      expect(exception.isInvalid, isFalse);
      expect(exception.token, 'token_123');
      expect(exception.errorCode, 'TOKEN_EXPIRED');
    });

    test('creates invalid token exception', () {
      final exception = TokenException.invalid(
        'token_123',
        'Invalid signature',
      );

      expect(exception.isInvalid, isTrue);
      expect(exception.isExpired, isFalse);
      expect(exception.token, 'token_123');
      expect(exception.errorCode, 'TOKEN_INVALID');
      expect(exception.details?['reason'], 'Invalid signature');
    });

    test('creates missing token exception', () {
      final exception = TokenException.missing();

      expect(exception.isInvalid, isTrue);
      expect(exception.isExpired, isFalse);
      expect(exception.token, isNull);
      expect(exception.errorCode, 'TOKEN_MISSING');
    });

    test('toJson does not include token for security', () {
      final exception = TokenException.expired('token_123');
      final json = exception.toJson();

      expect(json['isExpired'], isTrue);
      expect(json.containsKey('token'), isFalse);
    });
  });
}
