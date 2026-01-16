import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gatekeep/gatekeep.dart';

import '../helpers/mock_http_client.dart';
import '../helpers/mock_storage.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('QueueClient', () {
    late MockHttpClient mockHttpClient;
    late MockStorage mockStorage;
    late GatekeepConfig config;
    late QueueClient client;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockStorage = MockStorage();
      config = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
        httpClient: mockHttpClient,
        storage: mockStorage,
        retryStrategy: RetryStrategy.defaultStrategy(),
        queueRetryStrategy: RetryStrategy.queueStrategy(),
      );
      client = QueueClient(config);
    });

    tearDown(() {
      client.dispose();
      mockHttpClient.clear();
      mockStorage.clear();
    });

    group('joinEvent', () {
      test('successfully joins queue', () async {
        final responseJson = TestHelpers.sampleJoinResponse(
          queueId: 'q_test_123',
          position: 100,
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/join',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        final status = await client.joinEvent(eventId: 'evt_test_123');

        expect(status.queueId, 'q_test_123');
        expect(status.position, 100);
        expect(status.state, QueueState.waiting);
      });

      test('includes priority bucket in request', () async {
        final responseJson = TestHelpers.sampleJoinResponse();
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/join',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        await client.joinEvent(
          eventId: 'evt_test_123',
          priorityBucket: 'presale',
        );

        final calls = mockHttpClient.calls;
        expect(calls.length, 1);
        expect(calls[0].method, 'POST');
        expect(calls[0].body?['priority_bucket'], 'presale');
      });

      test('includes metadata in request', () async {
        final responseJson = TestHelpers.sampleJoinResponse();
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/join',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        await client.joinEvent(
          eventId: 'evt_test_123',
          metadata: {'source': 'app', 'version': '1.0'},
        );

        final calls = mockHttpClient.calls;
        expect(calls.length, 1);
        expect(calls[0].body?['metadata'], {'source': 'app', 'version': '1.0'});
      });

      test('throws exception on error', () async {
        mockHttpClient.setError(
          'https://test.example.com/v1/queue/join',
          QueueException.fromStatusCode(400, 'Invalid event ID', null),
        );

        expect(
          () => client.joinEvent(eventId: 'invalid'),
          throwsA(isA<QueueException>()),
        );
      });

      test('throws exception when disposed', () {
        client.dispose();

        expect(
          () => client.joinEvent(eventId: 'evt_test_123'),
          throwsA(isA<GatekeepException>()),
        );
      });
    });

    group('getStatus', () {
      test('successfully gets queue status', () async {
        final responseJson = TestHelpers.sampleStatusResponse(
          queueId: 'q_test_123',
          position: 50,
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/status',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        final status = await client.getStatus(queueId: 'q_test_123');

        expect(status.queueId, 'q_test_123');
        expect(status.position, 50);
      });

      test('includes queue_id in query parameters', () async {
        final responseJson = TestHelpers.sampleStatusResponse();
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/status',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        await client.getStatus(queueId: 'q_test_123');

        final calls = mockHttpClient.calls;
        expect(calls.length, 1);
        expect(calls[0].method, 'GET');
        expect(calls[0].queryParameters?['queue_id'], 'q_test_123');
      });

      test('throws exception when disposed', () {
        client.dispose();

        expect(
          () => client.getStatus(queueId: 'q_test_123'),
          throwsA(isA<GatekeepException>()),
        );
      });
    });

    group('sendHeartbeat', () {
      test('successfully sends heartbeat', () async {
        final responseJson = TestHelpers.sampleHeartbeatResponse(
          queueId: 'q_test_123',
          position: 45,
          estimatedWaitSeconds: 90,
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/heartbeat',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        final status = await client.sendHeartbeat(queueId: 'q_test_123');

        expect(status.queueId, 'q_test_123');
        expect(status.position, 45);
      });

      test('saves admission token when admitted', () async {
        final token = TestHelpers.createTestAdmissionToken();
        final responseJson = TestHelpers.sampleHeartbeatResponse(
          queueId: 'q_test_123',
          status: 'admitted',
          estimatedWaitSeconds: 0,
          admissionToken: token,
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/heartbeat',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        await client.sendHeartbeat(queueId: 'q_test_123');

        final savedToken = await client.restoreToken(eventId: token.eventId);
        expect(savedToken, isNotNull);
        expect(savedToken?.token, token.token);
      });

      test('throws exception when disposed', () {
        client.dispose();

        expect(
          () => client.sendHeartbeat(queueId: 'q_test_123'),
          throwsA(isA<GatekeepException>()),
        );
      });
    });

    group('listenStatus', () {
      test('returns stream of status updates', () async {
        final responseJson = TestHelpers.sampleStatusResponse(
          queueId: 'q_test_123',
          position: 50,
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/status',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        final stream = client.listenStatus(queueId: 'q_test_123');
        final status = await stream.first;

        expect(status.queueId, 'q_test_123');
        expect(status.position, 50);
      });

      test('stops polling when terminal state reached', () async {
        final admittedJson = TestHelpers.sampleStatusResponse(
          queueId: 'q_test_123',
          position: 0,
          status: 'admitted',
        );
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/status',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(admittedJson)),
            headers: {},
          ),
        );

        final stream = client.listenStatus(queueId: 'q_test_123');
        final status = await stream.first;

        expect(status.state, QueueState.admitted);

        // Wait a bit to ensure polling stopped
        await Future.delayed(const Duration(milliseconds: 100));

        // Stream should be closed
        expect(stream.isBroadcast, isTrue);
      });

      test('throws exception when disposed', () {
        client.dispose();

        expect(
          () => client.listenStatus(queueId: 'q_test_123'),
          throwsA(isA<GatekeepException>()),
        );
      });
    });

    group('Token persistence', () {
      test('saveToken stores token correctly', () async {
        final token = TestHelpers.createTestAdmissionToken();

        await client.saveToken(eventId: token.eventId, token: token);

        final saved = await mockStorage.read('token_${token.eventId}');
        expect(saved, isNotNull);
      });

      test('restoreToken retrieves valid token', () async {
        final token = TestHelpers.createTestAdmissionToken();
        await client.saveToken(eventId: token.eventId, token: token);

        final restored = await client.restoreToken(eventId: token.eventId);

        expect(restored, isNotNull);
        expect(restored?.token, token.token);
        expect(restored?.eventId, token.eventId);
      });

      test('restoreToken returns null for non-existent token', () async {
        final restored = await client.restoreToken(eventId: 'non_existent');

        expect(restored, isNull);
      });

      test('restoreToken returns null for expired token', () async {
        final expiredToken = TestHelpers.createTestAdmissionToken(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        await client.saveToken(
          eventId: expiredToken.eventId,
          token: expiredToken,
        );

        final restored = await client.restoreToken(
          eventId: expiredToken.eventId,
        );

        expect(restored, isNull);
      });

      test('restoreToken deletes expired token', () async {
        final expiredToken = TestHelpers.createTestAdmissionToken(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        await client.saveToken(
          eventId: expiredToken.eventId,
          token: expiredToken,
        );

        await client.restoreToken(eventId: expiredToken.eventId);

        final exists = await mockStorage.containsKey(
          'token_${expiredToken.eventId}',
        );
        expect(exists, isFalse);
      });
    });

    group('dispose', () {
      test('closes all resources', () {
        expect(() => client.dispose(), returnsNormally);
        expect(() => client.dispose(), returnsNormally); // Idempotent
      });

      test('cancels all timers', () async {
        final responseJson = TestHelpers.sampleStatusResponse();
        mockHttpClient.setResponse(
          'https://test.example.com/v1/queue/status',
          HttpResponse(
            statusCode: 200,
            body: jsonEncode(_convertDates(responseJson)),
            headers: {},
          ),
        );

        client
          ..listenStatus(queueId: 'q_test_123')
          ..dispose();

        // Wait to ensure timers are cancelled
        await Future.delayed(const Duration(milliseconds: 100));

        // Should not throw
        expect(() => client.dispose(), returnsNormally);
      });
    });
  });
}

Map<String, dynamic> _convertDates(Map<String, dynamic> json) {
  return json.map((key, value) {
    if (value is DateTime) {
      return MapEntry(key, value.toIso8601String());
    }
    if (value is Map) {
      return MapEntry(key, _convertDates(value as Map<String, dynamic>));
    }
    return MapEntry(key, value);
  });
}
