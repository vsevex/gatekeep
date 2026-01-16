import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('QueueState', () {
    test('has correct enum values', () {
      expect(QueueState.joining, isNotNull);
      expect(QueueState.waiting, isNotNull);
      expect(QueueState.admitted, isNotNull);
      expect(QueueState.expired, isNotNull);
      expect(QueueState.error, isNotNull);
    });

    group('QueueStateExtension', () {
      test('isTerminal returns true for terminal states', () {
        expect(QueueState.admitted.isTerminal, isTrue);
        expect(QueueState.expired.isTerminal, isTrue);
        expect(QueueState.error.isTerminal, isTrue);
      });

      test('isTerminal returns false for non-terminal states', () {
        expect(QueueState.joining.isTerminal, isFalse);
        expect(QueueState.waiting.isTerminal, isFalse);
      });

      test('isRetryable returns true for retryable states', () {
        expect(QueueState.error.isRetryable, isTrue);
        expect(QueueState.expired.isRetryable, isTrue);
      });

      test('isRetryable returns false for non-retryable states', () {
        expect(QueueState.joining.isRetryable, isFalse);
        expect(QueueState.waiting.isRetryable, isFalse);
        expect(QueueState.admitted.isRetryable, isFalse);
      });

      test('displayName returns correct names', () {
        expect(QueueState.joining.displayName, 'Joining');
        expect(QueueState.waiting.displayName, 'Waiting');
        expect(QueueState.admitted.displayName, 'Admitted');
        expect(QueueState.expired.displayName, 'Expired');
        expect(QueueState.error.displayName, 'Error');
      });

      test('toApiString returns lowercase display name', () {
        expect(QueueState.waiting.toApiString(), 'waiting');
        expect(QueueState.admitted.toApiString(), 'admitted');
      });
    });

    group('queueStateFromString', () {
      test('parses valid state strings correctly', () {
        expect(queueStateFromString('joining'), QueueState.joining);
        expect(queueStateFromString('waiting'), QueueState.waiting);
        expect(queueStateFromString('admitted'), QueueState.admitted);
        expect(queueStateFromString('expired'), QueueState.expired);
        expect(queueStateFromString('error'), QueueState.error);
      });

      test('handles uppercase strings', () {
        expect(queueStateFromString('JOINING'), QueueState.joining);
        expect(queueStateFromString('WAITING'), QueueState.waiting);
      });

      test('returns error for invalid strings', () {
        expect(queueStateFromString('invalid'), QueueState.error);
        expect(queueStateFromString(''), QueueState.error);
      });
    });
  });
}
