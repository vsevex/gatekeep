import 'dart:async';

import '../errors/gatekeep_exception.dart';
import '../errors/queue_exception.dart';
import '../errors/network_exception.dart';
import 'backoff_calculator.dart';

/// Generic exception for retry strategy
class _GenericException extends GatekeepException {
  const _GenericException(super.message, {super.originalError});
}

/// Strategy for retrying failed operations
class RetryStrategy {
  const RetryStrategy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.useExponentialBackoff = true,
    this.backoffCalculator,
    this.isRetryable,
  });

  /// Retry strategy for queue operations
  factory RetryStrategy.queueStrategy() => RetryStrategy(
    baseDelay: const Duration(seconds: 2),
    isRetryable: (error) {
      if (error is QueueException) {
        // Don't retry 4xx errors except 429
        if (error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500 &&
            error.statusCode != 429) {
          return false;
        }
        return error.retryable;
      }
      if (error is NetworkException) {
        return true;
      }
      return false;
    },
  );

  /// Retry strategy for network operations
  factory RetryStrategy.networkStrategy() => RetryStrategy(
    maxAttempts: 5,
    maxDelay: const Duration(seconds: 60),
    isRetryable: (error) {
      if (error is NetworkException) {
        return error.isTimeout || error.isConnectionError;
      }
      if (error is QueueException) {
        return error.retryable;
      }
      return false;
    },
  );

  /// Default retry strategy
  factory RetryStrategy.defaultStrategy() => const RetryStrategy();

  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Base delay before first retry
  final Duration baseDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Whether to use exponential backoff
  final bool useExponentialBackoff;

  /// Custom backoff calculator
  final BackoffCalculator? backoffCalculator;

  /// Function to determine if an error is retryable
  final bool Function(GatekeepException)? isRetryable;

  /// Execute a function with retry logic
  Future<T> execute<T>(Future<T> Function() operation) async {
    int attempt = 0;
    GatekeepException? lastError;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        lastError = e is GatekeepException
            ? e
            : _GenericException(e.toString(), originalError: e);

        // Check if error is retryable
        if (!_shouldRetry(lastError, attempt)) {
          throw lastError;
        }

        attempt++;

        // Don't wait after last attempt
        if (attempt >= maxAttempts) {
          break;
        }

        // Calculate delay
        final delay = _calculateDelay(attempt);

        // Wait before retry
        await Future.delayed(delay);
      }
    }

    // All retries exhausted
    throw lastError ??
        _GenericException('Operation failed after $maxAttempts attempts');
  }

  bool _shouldRetry(GatekeepException error, int attempt) {
    if (attempt >= maxAttempts) {
      return false;
    }

    // Use custom retryable function if provided
    if (isRetryable != null) {
      return isRetryable!(error);
    }

    // Default: retry network errors and retryable queue errors
    if (error is NetworkException) {
      return true;
    }

    if (error is QueueException) {
      return error.retryable;
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    if (backoffCalculator != null) {
      return backoffCalculator!.calculate(attempt, baseDelay, maxDelay);
    }

    if (useExponentialBackoff) {
      return BackoffCalculator.exponential(attempt, baseDelay, maxDelay);
    }

    return baseDelay;
  }
}
