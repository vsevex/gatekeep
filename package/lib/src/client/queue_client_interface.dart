import 'dart:async';

import '../models/queue_status.dart';
import '../models/admission_token.dart';

/// Interface for queue client implementations
/// Allows for easy mocking and testing
abstract class QueueClientInterface {
  /// Join a queue for an event
  Future<QueueStatus> joinEvent({
    required String eventId,
    String? priorityBucket,
    Map<String, dynamic>? metadata,
  });

  /// Get current queue status
  Future<QueueStatus> getStatus({required String queueId});

  /// Send a heartbeat to keep queue position alive
  Future<QueueStatus> sendHeartbeat({required String queueId});

  /// Listen to queue status updates
  Stream<QueueStatus> listenStatus({
    required String queueId,
    Duration? pollInterval,
  });

  /// Restore a previously saved admission token
  Future<AdmissionToken?> restoreToken({required String eventId});

  /// Save an admission token
  Future<void> saveToken({
    required String eventId,
    required AdmissionToken token,
  });

  /// Dispose and cleanup resources
  void dispose();
}
