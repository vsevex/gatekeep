/// Represents the current state of a queue entry
enum QueueState {
  /// Initial join request in progress
  joining,

  /// In queue, waiting for admission
  waiting,

  /// Admitted, token available
  admitted,

  /// Token expired or queue entry expired
  expired,

  /// Error occurred
  error,
}

/// Extension methods for QueueState
extension QueueStateExtension on QueueState {
  /// Check if state is a terminal state (no further transitions)
  bool get isTerminal =>
      this == QueueState.admitted ||
      this == QueueState.expired ||
      this == QueueState.error;

  /// Check if state allows retry
  bool get isRetryable =>
      this == QueueState.error || this == QueueState.expired;

  /// Get display name for the state
  String get displayName {
    switch (this) {
      case QueueState.joining:
        return 'Joining';
      case QueueState.waiting:
        return 'Waiting';
      case QueueState.admitted:
        return 'Admitted';
      case QueueState.expired:
        return 'Expired';
      case QueueState.error:
        return 'Error';
    }
  }

  /// Convert to API request string
  String toApiString() => displayName.toLowerCase();
}

/// Convert from API response string
QueueState queueStateFromString(String status) {
  switch (status.toLowerCase()) {
    case 'joining':
      return QueueState.joining;
    case 'waiting':
      return QueueState.waiting;
    case 'admitted':
      return QueueState.admitted;
    case 'expired':
      return QueueState.expired;
    case 'error':
      return QueueState.error;
    default:
      return QueueState.error;
  }
}
