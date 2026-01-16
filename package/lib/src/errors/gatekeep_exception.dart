/// Base exception class for all Gatekeep-related errors
abstract class GatekeepException implements Exception {
  const GatekeepException(
    this.message, {
    this.errorCode,
    this.details,
    this.originalError,
    this.stackTrace,
  });

  /// Human-readable error message
  final String message;

  /// Machine-readable error code
  final String? errorCode;

  /// Additional error details
  final Map<String, dynamic>? details;

  /// Original exception that caused this error (if any)
  final Object? originalError;

  /// Stack trace of the original error
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('GatekeepException: $message');
    if (errorCode != null) {
      buffer.write(' (code: $errorCode)');
    }
    if (details != null && details!.isNotEmpty) {
      buffer.write(' (details: $details)');
    }

    return buffer.toString();
  }

  /// Convert exception to JSON for logging/analytics
  Map<String, dynamic> toJson() => {
    'message': message,
    'errorCode': errorCode,
    'details': details,
    'type': runtimeType.toString(),
  };
}
