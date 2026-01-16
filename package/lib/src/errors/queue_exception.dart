import 'gatekeep_exception.dart';

/// Exception thrown when queue operations fail
class QueueException extends GatekeepException {
  const QueueException(
    super.message, {
    this.statusCode,
    this.retryAfter,
    this.retryable = false,
    super.errorCode,
    super.details,
    super.originalError,
    super.stackTrace,
  });

  /// Create a QueueException from HTTP status code
  factory QueueException.fromStatusCode(
    int statusCode,
    String? message,
    Map<String, dynamic>? details,
  ) {
    final errorCode = _getErrorCode(statusCode);
    final retryable = _isRetryable(statusCode);
    final retryAfter = details?['retry_after'] as int?;

    return QueueException(
      message ?? _getDefaultMessage(statusCode),
      statusCode: statusCode,
      retryAfter: retryAfter,
      retryable: retryable,
      errorCode: errorCode,
      details: details,
    );
  }

  /// HTTP status code (if applicable)
  final int? statusCode;

  /// Retry-After header value in seconds (if rate limited)
  final int? retryAfter;

  /// Whether this error is retryable
  final bool retryable;

  static String _getErrorCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'INVALID_REQUEST';
      case 404:
        return 'QUEUE_NOT_FOUND';
      case 409:
        return 'ALREADY_IN_QUEUE';
      case 410:
        return 'TOKEN_EXPIRED';
      case 429:
        return 'RATE_LIMITED';
      case 503:
        return 'SERVICE_UNAVAILABLE';
      default:
        return 'UNKNOWN_ERROR';
    }
  }

  static bool _isRetryable(int statusCode) {
    return statusCode == 429 || statusCode == 503 || statusCode >= 500;
  }

  static String _getDefaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your parameters.';
      case 404:
        return 'Queue not found. It may have expired.';
      case 409:
        return 'Already in queue.';
      case 410:
        return 'Admission token has expired.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 503:
        return 'Service temporarily unavailable.';
      default:
        return 'An error occurred while processing your request.';
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'statusCode': statusCode,
    'retryAfter': retryAfter,
    'retryable': retryable,
  };
}
