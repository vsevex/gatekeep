import 'gatekeep_exception.dart';

/// Exception thrown when token operations fail
class TokenException extends GatekeepException {
  const TokenException(
    super.message, {
    this.isExpired = false,
    this.isInvalid = false,
    this.token,
    super.errorCode,
    super.details,
    super.originalError,
    super.stackTrace,
  });

  /// Create a TokenException for a missing token
  factory TokenException.missing() => const TokenException(
    'Admission token is missing',
    isInvalid: true,
    errorCode: 'TOKEN_MISSING',
  );

  /// Create a TokenException for an invalid token
  factory TokenException.invalid(String? token, String reason) =>
      TokenException(
        'Invalid admission token: $reason',
        isInvalid: true,
        token: token,
        errorCode: 'TOKEN_INVALID',
        details: {'reason': reason},
      );

  /// Create a TokenException for an expired token
  factory TokenException.expired(String? token) => TokenException(
    'Admission token has expired',
    isExpired: true,
    token: token,
    errorCode: 'TOKEN_EXPIRED',
  );

  /// Whether the token is expired
  final bool isExpired;

  /// Whether the token is invalid
  final bool isInvalid;

  /// Token that caused the error (may be null for security)
  final String? token;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'isExpired': isExpired,
    'isInvalid': isInvalid,
  };
}
