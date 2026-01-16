import 'gatekeep_exception.dart';

/// Exception thrown when network operations fail
class NetworkException extends GatekeepException {
  const NetworkException(
    super.message, {
    this.isTimeout = false,
    this.isConnectionError = false,
    this.url,
    super.errorCode,
    super.details,
    super.originalError,
    super.stackTrace,
  });

  /// Create a NetworkException from a socket error
  factory NetworkException.socketError(String message, Object? originalError) =>
      NetworkException(
        message,
        isConnectionError: true,
        errorCode: 'SOCKET_ERROR',
        originalError: originalError,
      );

  /// Create a NetworkException from a connection error
  factory NetworkException.connectionError(String url, Object? originalError) =>
      NetworkException(
        'Failed to connect to $url',
        isConnectionError: true,
        url: url,
        errorCode: 'CONNECTION_ERROR',
        originalError: originalError,
      );

  /// Create a NetworkException from a timeout
  factory NetworkException.timeout(String url, Duration timeout) =>
      NetworkException(
        'Request to $url timed out after ${timeout.inSeconds} seconds',
        isTimeout: true,
        url: url,
        errorCode: 'TIMEOUT',
        details: {'timeout': timeout.inSeconds, 'url': url},
      );

  /// Whether this is a timeout error
  final bool isTimeout;

  /// Whether this is a connection error
  final bool isConnectionError;

  /// URL that failed
  final String? url;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'isTimeout': isTimeout,
    'isConnectionError': isConnectionError,
    'url': url,
  };
}
