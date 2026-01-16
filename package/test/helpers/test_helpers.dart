import 'package:gatekeep/gatekeep.dart';

/// Test helpers and utilities
class TestHelpers {
  TestHelpers._();

  /// Create a test configuration
  static GatekeepConfig createTestConfig({
    String baseUrl = 'https://test.example.com/v1',
    String deviceId = 'test-device-id',
    String? userId,
    bool debug = false,
  }) => GatekeepInitializer.initialize(
    baseUrl: baseUrl,
    deviceId: deviceId,
    userId: userId,
    debug: debug,
  );

  /// Create a test queue status
  static QueueStatus createTestQueueStatus({
    String? queueId,
    int? position,
    int? estimatedWaitSeconds,
    QueueState? state,
    AdmissionToken? admissionToken,
    String? error,
  }) => QueueStatus(
    queueId: queueId ?? 'q_test_123',
    position: position ?? 100,
    estimatedWaitSeconds: estimatedWaitSeconds ?? 180,
    state: state ?? QueueState.waiting,
    admissionToken: admissionToken,
    error: error,
    enqueuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    lastHeartbeat: DateTime.now(),
  );

  /// Create a test admission token
  static AdmissionToken createTestAdmissionToken({
    String? token,
    String? eventId,
    String? deviceId,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    return AdmissionToken(
      token: token ?? 'test_token_123',
      eventId: eventId ?? 'evt_test_123',
      deviceId: deviceId ?? 'test-device-id',
      issuedAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
    );
  }

  /// Create a test join request
  static JoinRequest createTestJoinRequest({
    String? eventId,
    String? deviceId,
    String? userId,
    String? priorityBucket,
  }) => JoinRequest(
    eventId: eventId ?? 'evt_test_123',
    deviceId: deviceId ?? 'test-device-id',
    userId: userId,
    priorityBucket: priorityBucket,
  );

  /// Create a test heartbeat request
  static HeartbeatRequest createTestHeartbeatRequest({String? queueId}) =>
      HeartbeatRequest(queueId: queueId ?? 'q_test_123');

  /// Sample JSON response for queue join
  static Map<String, dynamic> sampleJoinResponse({
    String? queueId,
    int? position,
    int? estimatedWaitSeconds,
  }) {
    return {
      'queue_id': queueId ?? 'q_test_123',
      'position': position ?? 100,
      'estimated_wait_seconds': estimatedWaitSeconds ?? 180,
      'status': 'waiting',
      'enqueued_at': DateTime.now().toIso8601String(),
      'last_heartbeat': DateTime.now().toIso8601String(),
    };
  }

  /// Sample JSON response for queue status
  static Map<String, dynamic> sampleStatusResponse({
    String? queueId,
    int? position,
    int? estimatedWaitSeconds,
    String? status,
    AdmissionToken? admissionToken,
  }) => {
    'queue_id': queueId ?? 'q_test_123',
    'position': position ?? 50,
    'estimated_wait_seconds': estimatedWaitSeconds ?? 90,
    'status': status ?? 'waiting',
    'enqueued_at': DateTime.now().toIso8601String(),
    'last_heartbeat': DateTime.now().toIso8601String(),
    if (admissionToken != null) 'admission_token': admissionToken.toJson(),
  };

  /// Sample JSON response for heartbeat
  static Map<String, dynamic> sampleHeartbeatResponse({
    String? queueId,
    int? position,
    int? estimatedWaitSeconds,
    String? status,
    AdmissionToken? admissionToken,
  }) => {
    'queue_id': queueId ?? 'q_test_123',
    'position': position ?? 50,
    'estimated_wait_seconds': estimatedWaitSeconds ?? 90,
    'status': status ?? 'waiting',
    'next_heartbeat_seconds': 30,
    if (admissionToken != null) 'admission_token': admissionToken.toJson(),
  };
}
