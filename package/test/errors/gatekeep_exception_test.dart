import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('GatekeepException', () {
    test('creates exception with message', () {
      const exception = _TestException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.errorCode, isNull);
      expect(exception.details, isNull);
    });

    test('creates exception with all fields', () {
      final exception = _TestException(
        'Test error',
        errorCode: 'TEST_ERROR',
        details: {'key': 'value'},
        originalError: Exception('Original'),
      );

      expect(exception.message, 'Test error');
      expect(exception.errorCode, 'TEST_ERROR');
      expect(exception.details, {'key': 'value'});
      expect(exception.originalError, isNotNull);
    });

    test('toString includes message and error code', () {
      const exception = _TestException('Test error', errorCode: 'TEST_ERROR');

      final str = exception.toString();
      expect(str, contains('Test error'));
      expect(str, contains('TEST_ERROR'));
    });

    test('toJson returns correct structure', () {
      const exception = _TestException(
        'Test error',
        errorCode: 'TEST_ERROR',
        details: {'key': 'value'},
      );

      final json = exception.toJson();
      expect(json['message'], 'Test error');
      expect(json['errorCode'], 'TEST_ERROR');
      expect(json['details'], {'key': 'value'});
      expect(json['type'], contains('_TestException'));
    });
  });
}

// Test implementation of GatekeepException
class _TestException extends GatekeepException {
  const _TestException(
    super.message, {
    super.errorCode,
    super.details,
    super.originalError,
  });
}
