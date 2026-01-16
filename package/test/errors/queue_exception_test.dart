import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('QueueException', () {
    test('creates exception from status code', () {
      final exception = QueueException.fromStatusCode(
        404,
        'Queue not found',
        null,
      );

      expect(exception.statusCode, 404);
      expect(exception.message, 'Queue not found');
      expect(exception.errorCode, 'QUEUE_NOT_FOUND');
      expect(exception.retryable, isFalse);
    });

    test('marks retryable errors correctly', () {
      final retryable = QueueException.fromStatusCode(429, null, null);
      final nonRetryable = QueueException.fromStatusCode(400, null, null);

      expect(retryable.retryable, isTrue);
      expect(nonRetryable.retryable, isFalse);
    });

    test('includes retryAfter from details', () {
      final exception = QueueException.fromStatusCode(429, null, {
        'retry_after': 60,
      });

      expect(exception.retryAfter, 60);
    });

    test('provides default messages for status codes', () {
      final exception400 = QueueException.fromStatusCode(400, null, null);
      final exception404 = QueueException.fromStatusCode(404, null, null);
      final exception409 = QueueException.fromStatusCode(409, null, null);
      final exception429 = QueueException.fromStatusCode(429, null, null);
      final exception503 = QueueException.fromStatusCode(503, null, null);

      expect(exception400.message, isNotEmpty);
      expect(exception404.message, isNotEmpty);
      expect(exception409.message, isNotEmpty);
      expect(exception429.message, isNotEmpty);
      expect(exception503.message, isNotEmpty);
    });

    test('toJson includes status code and retry info', () {
      final exception = QueueException.fromStatusCode(429, 'Rate limited', {
        'retry_after': 60,
      });

      final json = exception.toJson();
      expect(json['statusCode'], 429);
      expect(json['retryAfter'], 60);
      expect(json['retryable'], isTrue);
    });
  });
}
