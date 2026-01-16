import 'dart:math';

/// Calculates backoff delays for retry strategies
abstract class BackoffCalculator {
  /// Calculate delay for a given attempt number
  Duration calculate(int attempt, Duration baseDelay, Duration maxDelay);

  /// Exponential backoff calculator
  static Duration exponential(
    int attempt,
    Duration baseDelay,
    Duration maxDelay,
  ) {
    // Calculate: baseDelay * 2^(attempt - 1)
    final delayMs = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final delay = Duration(milliseconds: delayMs);

    // Cap at maxDelay
    if (delay > maxDelay) {
      return maxDelay;
    }

    return delay;
  }

  /// Linear backoff calculator
  static Duration linear(int attempt, Duration baseDelay, Duration maxDelay) {
    final delay = baseDelay * attempt;

    if (delay > maxDelay) {
      return maxDelay;
    }

    return delay;
  }

  /// Fixed backoff calculator (no increase)
  static Duration fixed(int attempt, Duration baseDelay, Duration maxDelay) =>
      baseDelay;

  /// Exponential backoff with jitter
  static Duration exponentialWithJitter(
    int attempt,
    Duration baseDelay,
    Duration maxDelay,
  ) {
    final base = exponential(attempt, baseDelay, maxDelay);

    // Add random jitter (0-25% of delay)
    final jitterMs = (base.inMilliseconds * 0.25 * (Random().nextDouble()));
    final jitter = Duration(milliseconds: jitterMs.toInt());

    return base + jitter;
  }
}
