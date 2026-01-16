/// Request model for joining a queue
class JoinRequest {
  const JoinRequest({
    required this.eventId,
    required this.deviceId,
    this.userId,
    this.priorityBucket,
    this.metadata,
  });

  /// Create from JSON
  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      eventId: json['event_id'] as String,
      deviceId: json['device_id'] as String,
      userId: json['user_id'] as String?,
      priorityBucket: json['priority_bucket'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Event ID to join
  final String eventId;

  /// Device ID
  final String deviceId;

  /// User ID (optional)
  final String? userId;

  /// Priority bucket (optional)
  final String? priorityBucket;

  /// Custom metadata (optional)
  final Map<String, dynamic>? metadata;

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (priorityBucket != null) 'priority_bucket': priorityBucket,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'JoinRequest(eventId: $eventId, deviceId: $deviceId, '
      'priorityBucket: $priorityBucket)';
}
