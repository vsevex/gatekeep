/// Request model for sending a heartbeat
class HeartbeatRequest {
  const HeartbeatRequest({required this.queueId});

  /// Create from JSON
  factory HeartbeatRequest.fromJson(Map<String, dynamic> json) {
    return HeartbeatRequest(queueId: json['queue_id'] as String);
  }

  /// Queue ID to send heartbeat for
  final String queueId;

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => {'queue_id': queueId};

  @override
  String toString() => 'HeartbeatRequest(queueId: $queueId)';
}
