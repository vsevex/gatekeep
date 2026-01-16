import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('RetryStrategy', () {
    test('defaultStrategy creates strategy with defaults', () {
      final strategy = RetryStrategy.defaultStrategy();

      expect(strategy.maxAttempts, 3);
      expect(strategy.baseDelay, const Duration(seconds: 1));
      expect(strategy.useExponentialBackoff, isTrue);
    });

    test('networkStrategy creates strategy for network operations', () {
      final strategy = RetryStrategy.networkStrategy();

      expect(strategy.maxAttempts, 5);
      expect(strategy.maxDelay, const Duration(seconds: 60));
      expect(strategy.isRetryable, isNotNull);
    });

    test('queueStrategy creates strategy for queue operations', () {
      final strategy = RetryStrategy.queueStrategy();

      expect(strategy.maxAttempts, 3);
      expect(strategy.baseDelay, const Duration(seconds: 2));
      expect(strategy.isRetryable, isNotNull);
    });

    test('execute succeeds on first attempt', () async {
      final strategy = RetryStrategy.defaultStrategy();
      var callCount = 0;

      final result = await strategy.execute(() async {
        callCount++;
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 1);
    });

    test('execute retries on retryable errors', () async {
      final strategy = RetryStrategy(
        baseDelay: const Duration(milliseconds: 10),
        isRetryable: (error) => error is NetworkException,
      );

      var callCount = 0;

      final result = await strategy.execute(() async {
        callCount++;
        if (callCount < 2) {
          throw NetworkException.timeout('test', const Duration(seconds: 1));
        }
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 2);
    });

    test('execute throws after max attempts', () async {
      final strategy = RetryStrategy(
        maxAttempts: 2,
        baseDelay: const Duration(milliseconds: 10),
        isRetryable: (error) => true,
      );

      await expectLater(
        strategy.execute(() async {
          throw NetworkException.timeout('test', const Duration(seconds: 1));
        }),
        throwsA(isA<NetworkException>()),
      );
    });

    test('execute does not retry non-retryable errors', () async {
      final strategy = RetryStrategy(isRetryable: (error) => false);

      await expectLater(
        strategy.execute(() async {
          throw const QueueException('Test error', statusCode: 400);
        }),
        throwsA(isA<QueueException>()),
      );
    });
  });
}
