import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('BackoffCalculator', () {
    const baseDelay = Duration(seconds: 1);
    const maxDelay = Duration(seconds: 30);

    test('exponential calculates correct delays', () {
      final delay1 = BackoffCalculator.exponential(1, baseDelay, maxDelay);
      final delay2 = BackoffCalculator.exponential(2, baseDelay, maxDelay);
      final delay3 = BackoffCalculator.exponential(3, baseDelay, maxDelay);

      expect(delay1.inSeconds, 1); // 1 * 2^0
      expect(delay2.inSeconds, 2); // 1 * 2^1
      expect(delay3.inSeconds, 4); // 1 * 2^2
    });

    test('exponential caps at maxDelay', () {
      final delay = BackoffCalculator.exponential(10, baseDelay, maxDelay);

      expect(delay, lessThanOrEqualTo(maxDelay));
    });

    test('linear calculates correct delays', () {
      final delay1 = BackoffCalculator.linear(1, baseDelay, maxDelay);
      final delay2 = BackoffCalculator.linear(2, baseDelay, maxDelay);
      final delay3 = BackoffCalculator.linear(3, baseDelay, maxDelay);

      expect(delay1.inSeconds, 1);
      expect(delay2.inSeconds, 2);
      expect(delay3.inSeconds, 3);
    });

    test('linear caps at maxDelay', () {
      final delay = BackoffCalculator.linear(100, baseDelay, maxDelay);

      expect(delay, lessThanOrEqualTo(maxDelay));
    });

    test('fixed returns base delay', () {
      final delay1 = BackoffCalculator.fixed(1, baseDelay, maxDelay);
      final delay2 = BackoffCalculator.fixed(5, baseDelay, maxDelay);

      expect(delay1, baseDelay);
      expect(delay2, baseDelay);
    });

    test('exponentialWithJitter adds jitter', () {
      final delay = BackoffCalculator.exponentialWithJitter(
        2,
        baseDelay,
        maxDelay,
      );

      // Should be between base exponential and base exponential + 25%
      final baseExpDelay = BackoffCalculator.exponential(
        2,
        baseDelay,
        maxDelay,
      );
      expect(delay, greaterThanOrEqualTo(baseExpDelay));
      expect(
        delay,
        lessThanOrEqualTo(
          baseExpDelay +
              Duration(
                milliseconds: (baseExpDelay.inMilliseconds * 0.25).round(),
              ),
        ),
      );
    });
  });
}
