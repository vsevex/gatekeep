/// Represents an admission token for accessing protected resources
class AdmissionToken {
  const AdmissionToken({
    required this.token,
    required this.eventId,
    required this.deviceId,
    required this.issuedAt,
    required this.expiresAt,
    this.userId,
    this.queueId,
  });

  /// Create AdmissionToken from JSON
  factory AdmissionToken.fromJson(Map<String, dynamic> json) => AdmissionToken(
    token: json['token'] as String,
    eventId: json['event_id'] as String,
    deviceId: json['device_id'] as String,
    userId: json['user_id'] as String?,
    issuedAt: DateTime.parse(json['issued_at'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
    queueId: json['queue_id'] as String?,
  );

  /// The token string
  final String token;

  /// Event ID this token is for
  final String eventId;

  /// Device ID this token is bound to
  final String deviceId;

  /// User ID (optional)
  final String? userId;

  /// When the token was issued
  final DateTime issuedAt;

  /// When the token expires
  final DateTime expiresAt;

  /// Queue ID this token was issued for
  final String? queueId;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'token': token,
    'event_id': eventId,
    'device_id': deviceId,
    if (userId != null) 'user_id': userId,
    'issued_at': issuedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    if (queueId != null) 'queue_id': queueId,
  };

  /// Check if token is still valid
  bool isValid({DateTime? now}) {
    final checkTime = now ?? DateTime.now();
    return checkTime.isBefore(expiresAt);
  }

  /// Get remaining validity duration
  Duration remainingValidity({DateTime? now}) {
    final checkTime = now ?? DateTime.now();
    if (!isValid(now: checkTime)) {
      return Duration.zero;
    }
    return expiresAt.difference(checkTime);
  }

  /// Check if token is expiring soon (within threshold)
  bool isExpiringSoon({Duration threshold = const Duration(minutes: 1)}) {
    return remainingValidity() <= threshold;
  }

  /// Get time until expiry as a human-readable string
  String getTimeUntilExpiry({DateTime? now}) {
    final remaining = remainingValidity(now: now);
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return 'Expired';
    }

    if (remaining.inDays > 0) {
      return '${remaining.inDays} day${remaining.inDays > 1 ? 's' : ''}';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours} hour${remaining.inHours > 1 ? 's' : ''}';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes} minute${remaining.inMinutes > 1 ? 's' : ''}';
    } else {
      return '${remaining.inSeconds} second${remaining.inSeconds > 1 ? 's' : ''}';
    }
  }

  /// Create a copy with updated fields
  AdmissionToken copyWith({
    String? token,
    String? eventId,
    String? deviceId,
    String? userId,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? queueId,
  }) => AdmissionToken(
    token: token ?? this.token,
    eventId: eventId ?? this.eventId,
    deviceId: deviceId ?? this.deviceId,
    userId: userId ?? this.userId,
    issuedAt: issuedAt ?? this.issuedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    queueId: queueId ?? this.queueId,
  );

  @override
  String toString() =>
      'AdmissionToken(eventId: $eventId, expiresAt: $expiresAt, '
      'valid: ${isValid()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AdmissionToken &&
        other.token == token &&
        other.eventId == eventId &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => token.hashCode ^ eventId.hashCode ^ deviceId.hashCode;
}
