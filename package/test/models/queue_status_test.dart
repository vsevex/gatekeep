import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('QueueStatus', () {
    test('creates status from JSON correctly', () {
      final json = {
        'queue_id': 'q_test_123',
        'position': 100,
        'estimated_wait_seconds': 180,
        'status': 'waiting',
        'enqueued_at': '2024-01-15T10:23:45Z',
        'last_heartbeat': '2024-01-15T10:28:12Z',
      };

      final status = QueueStatus.fromJson(json);

      expect(status.queueId, 'q_test_123');
      expect(status.position, 100);
      expect(status.estimatedWaitSeconds, 180);
      expect(status.state, QueueState.waiting);
      expect(status.enqueuedAt, isNotNull);
      expect(status.lastHeartbeat, isNotNull);
    });

    test('creates status with admission token', () {
      final token = TestHelpers.createTestAdmissionToken();
      final json = TestHelpers.sampleStatusResponse(
        admissionToken: token,
        status: 'admitted',
      );

      final status = QueueStatus.fromJson(json);

      expect(status.state, QueueState.admitted);
      expect(status.admissionToken, isNotNull);
      expect(status.admissionToken!.token, token.token);
    });

    test('converts to JSON correctly', () {
      final status = TestHelpers.createTestQueueStatus();
      final json = status.toJson();

      expect(json['queue_id'], status.queueId);
      expect(json['position'], status.position);
      expect(json['estimated_wait_seconds'], status.estimatedWaitSeconds);
      expect(json['status'], status.state.toApiString());
    });

    test('calculates progress correctly', () {
      const status = QueueStatus(
        queueId: 'q_test',
        position: 50,
        estimatedWaitSeconds: 100,
        state: QueueState.waiting,
        totalInQueue: 100,
      );

      expect(status.progress, 0.5);
    });

    test('progress returns null when totalInQueue is null', () {
      final status = TestHelpers.createTestQueueStatus();
      expect(status.progress, isNull);
    });

    test('progress returns 1.0 when position is 0', () {
      const status = QueueStatus(
        queueId: 'q_test',
        position: 0,
        estimatedWaitSeconds: 0,
        state: QueueState.admitted,
        totalInQueue: 100,
      );

      expect(status.progress, 1.0);
    });

    test('estimatedWait returns correct Duration', () {
      final status = TestHelpers.createTestQueueStatus(
        estimatedWaitSeconds: 180,
      );

      expect(status.estimatedWait.inSeconds, 180);
    });

    test('isAdmitted returns true when admitted with token', () {
      final token = TestHelpers.createTestAdmissionToken();
      final status = TestHelpers.createTestQueueStatus(
        state: QueueState.admitted,
        admissionToken: token,
      );

      expect(status.isAdmitted, isTrue);
    });

    test('isAdmitted returns false when not admitted', () {
      final status = TestHelpers.createTestQueueStatus(
        state: QueueState.waiting,
      );

      expect(status.isAdmitted, isFalse);
    });

    test('hasError returns true for error state', () {
      final status = TestHelpers.createTestQueueStatus(
        state: QueueState.error,
        error: 'Test error',
      );

      expect(status.hasError, isTrue);
    });

    test('isExpired returns true for expired state', () {
      final status = TestHelpers.createTestQueueStatus(
        state: QueueState.expired,
      );

      expect(status.isExpired, isTrue);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = TestHelpers.createTestQueueStatus();
      final updated = original.copyWith(position: 50);

      expect(updated.position, 50);
      expect(updated.queueId, original.queueId);
      expect(updated.state, original.state);
    });

    test('equality works correctly', () {
      final status1 = TestHelpers.createTestQueueStatus(
        queueId: 'q_test',
        position: 100,
      );
      final status2 = TestHelpers.createTestQueueStatus(
        queueId: 'q_test',
        position: 100,
      );

      expect(status1 == status2, isTrue);
      expect(status1.hashCode, status2.hashCode);
    });

    test('toString returns meaningful string', () {
      final status = TestHelpers.createTestQueueStatus();
      final str = status.toString();

      expect(str, contains(status.queueId));
      expect(str, contains(status.position.toString()));
      expect(str, contains(status.state.toString()));
    });
  });
}
