import 'queue_state.dart'
    show QueueState, QueueStateExtension, queueStateFromString;
import 'admission_token.dart';

/// Represents the current status of a queue entry
class QueueStatus {
  const QueueStatus({
    required this.queueId,
    required this.position,
    required this.estimatedWaitSeconds,
    required this.state,
    this.enqueuedAt,
    this.lastHeartbeat,
    this.admissionToken,
    this.error,
    this.totalInQueue,
    this.nextHeartbeatSeconds,
  });

  /// Create QueueStatus from JSON
  factory QueueStatus.fromJson(Map<String, dynamic> json) {
    return QueueStatus(
      queueId: json['queue_id'] as String,
      position: json['position'] as int,
      estimatedWaitSeconds: json['estimated_wait_seconds'] as int,
      state: queueStateFromString(json['status'] as String? ?? 'error'),
      enqueuedAt: json['enqueued_at'] != null
          ? DateTime.parse(json['enqueued_at'] as String)
          : null,
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.parse(json['last_heartbeat'] as String)
          : null,
      admissionToken: json['admission_token'] != null
          ? AdmissionToken.fromJson(
              json['admission_token'] as Map<String, dynamic>,
            )
          : null,
      error: json['error'] as String?,
      totalInQueue: json['total_in_queue'] as int?,
      nextHeartbeatSeconds: json['next_heartbeat_seconds'] as int?,
    );
  }

  /// Unique identifier for this queue entry
  final String queueId;

  /// Current position in queue (0 = front of queue)
  final int position;

  /// Estimated wait time in seconds
  final int estimatedWaitSeconds;

  /// Current state of the queue entry
  final QueueState state;

  /// When the user joined the queue
  final DateTime? enqueuedAt;

  /// Last successful heartbeat timestamp
  final DateTime? lastHeartbeat;

  /// Admission token (null until admitted)
  final AdmissionToken? admissionToken;

  /// Error message (if state is error)
  final String? error;

  /// Total number of users in queue (if available)
  final int? totalInQueue;

  /// Next heartbeat interval in seconds (if available)
  final int? nextHeartbeatSeconds;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'queue_id': queueId,
    'position': position,
    'estimated_wait_seconds': estimatedWaitSeconds,
    'status': state.toApiString(),
    if (enqueuedAt != null) 'enqueued_at': enqueuedAt!.toIso8601String(),
    if (lastHeartbeat != null)
      'last_heartbeat': lastHeartbeat!.toIso8601String(),
    if (admissionToken != null) 'admission_token': admissionToken!.toJson(),
    if (error != null) 'error': error,
    if (totalInQueue != null) 'total_in_queue': totalInQueue,
    if (nextHeartbeatSeconds != null)
      'next_heartbeat_seconds': nextHeartbeatSeconds,
  };

  /// Calculate progress (0.0 to 1.0) based on position
  /// Requires totalInQueue to be set
  double? get progress {
    if (totalInQueue == null || totalInQueue == 0) {
      return null;
    }
    if (position == 0) {
      return 1.0;
    }
    return 1.0 - (position / totalInQueue!);
  }

  /// Get estimated wait time as Duration
  Duration get estimatedWait => Duration(seconds: estimatedWaitSeconds);

  /// Check if status indicates admission
  bool get isAdmitted => state == QueueState.admitted && admissionToken != null;

  /// Check if status indicates error
  bool get hasError => state == QueueState.error;

  /// Check if status indicates expired
  bool get isExpired => state == QueueState.expired;

  /// Create a copy with updated fields
  QueueStatus copyWith({
    String? queueId,
    int? position,
    int? estimatedWaitSeconds,
    QueueState? state,
    DateTime? enqueuedAt,
    DateTime? lastHeartbeat,
    AdmissionToken? admissionToken,
    String? error,
    int? totalInQueue,
    int? nextHeartbeatSeconds,
  }) => QueueStatus(
    queueId: queueId ?? this.queueId,
    position: position ?? this.position,
    estimatedWaitSeconds: estimatedWaitSeconds ?? this.estimatedWaitSeconds,
    state: state ?? this.state,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    admissionToken: admissionToken ?? this.admissionToken,
    error: error ?? this.error,
    totalInQueue: totalInQueue ?? this.totalInQueue,
    nextHeartbeatSeconds: nextHeartbeatSeconds ?? this.nextHeartbeatSeconds,
  );

  @override
  String toString() =>
      'QueueStatus(queueId: $queueId, position: $position, '
      'state: $state, estimatedWait: ${estimatedWaitSeconds}s)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is QueueStatus &&
        other.queueId == queueId &&
        other.position == position &&
        other.state == state;
  }

  @override
  int get hashCode => queueId.hashCode ^ position.hashCode ^ state.hashCode;
}
