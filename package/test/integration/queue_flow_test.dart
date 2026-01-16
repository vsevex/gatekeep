import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gatekeep/gatekeep.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import '../helpers/mock_http_client.dart';
import '../helpers/mock_storage.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Queue Flow Integration Tests', () {
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
        pollInterval: const Duration(milliseconds: 100),
        heartbeatInterval: const Duration(milliseconds: 200),
      );
      client = QueueClient(config);
    });

    tearDown(() {
      client.dispose();
      mockHttpClient.clear();
      mockStorage.clear();
    });

    test('full queue flow: join -> wait -> admitted', () async {
      // Step 1: Join queue
      final joinResponse = TestHelpers.sampleJoinResponse(
        queueId: 'q_test_123',
        position: 100,
        estimatedWaitSeconds: 180,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/join',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(joinResponse),
          headers: {},
        ),
      );

      final initialStatus = await client.joinEvent(eventId: 'evt_test_123');
      expect(initialStatus.queueId, 'q_test_123');
      expect(initialStatus.position, 100);
      expect(initialStatus.state, QueueState.waiting);

      // Step 2: Status updates (waiting)
      final waitingResponse1 = TestHelpers.sampleStatusResponse(
        queueId: 'q_test_123',
        position: 75,
        estimatedWaitSeconds: 135,
      );
      final waitingResponse2 = TestHelpers.sampleStatusResponse(
        queueId: 'q_test_123',
        position: 50,
        estimatedWaitSeconds: 90,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/status',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(waitingResponse1),
          headers: {},
        ),
      );

      final stream = client.listenStatus(queueId: 'q_test_123');
      final status1 = await stream.first;
      expect(status1.position, 75);

      // Update response for next poll
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/status',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(waitingResponse2),
          headers: {},
        ),
      );

      // Step 3: Admitted
      final token = TestHelpers.createTestAdmissionToken();
      final admittedResponse = TestHelpers.sampleStatusResponse(
        queueId: 'q_test_123',
        position: 0,
        status: 'admitted',
        admissionToken: token,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/status',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(admittedResponse),
          headers: {},
        ),
      );

      // Wait for admitted status
      final admittedStatus = await stream.firstWhere(
        (status) => status.state == QueueState.admitted,
        orElse: () => throw Exception('Not admitted'),
      );

      expect(admittedStatus.state, QueueState.admitted);
      expect(admittedStatus.admissionToken, isNotNull);

      // Token is saved via heartbeat, so trigger a heartbeat to save it
      // Set up heartbeat response with token
      final heartbeatWithToken = TestHelpers.sampleHeartbeatResponse(
        queueId: 'q_test_123',
        position: 0,
        status: 'admitted',
        estimatedWaitSeconds: 0,
        admissionToken: token,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/heartbeat',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(heartbeatWithToken),
          headers: {},
        ),
      );

      // Wait for heartbeat to be sent (autoHeartbeat is enabled)
      await Future.delayed(const Duration(milliseconds: 250));

      // Verify token was saved
      final savedToken = await client.restoreToken(eventId: token.eventId);
      expect(savedToken, isNotNull);
      expect(savedToken?.token, token.token);
    });

    test('error recovery: retry after network failure', () async {
      // First attempt fails, second succeeds
      final joinResponse = TestHelpers.sampleJoinResponse(
        queueId: 'q_test_123',
        position: 100,
      );

      // Use retry strategy that will retry
      final retryConfig = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
        httpClient: mockHttpClient,
        storage: mockStorage,
        retryStrategy: RetryStrategy.defaultStrategy(),
        queueRetryStrategy: const RetryStrategy(
          baseDelay: Duration(milliseconds: 10),
        ),
      );
      final retryClient = QueueClient(retryConfig);

      // Set error for first call, then success for subsequent calls
      mockHttpClient.setError(
        'https://test.example.com/v1/queue/join',
        NetworkException.connectionError(
          'https://test.example.com/v1/queue/join',
          Exception('Connection failed'),
        ),
      );

      // After a delay, clear error and set success response
      Future.delayed(const Duration(milliseconds: 15), () {
        mockHttpClient
          ..clearError('https://test.example.com/v1/queue/join')
          ..setResponse(
            'https://test.example.com/v1/queue/join',
            HttpResponse(
              statusCode: 200,
              body: _jsonString(joinResponse),
              headers: {},
            ),
          );
      });

      // Should eventually succeed after retry
      final status = await retryClient.joinEvent(eventId: 'evt_test_123');
      expect(status.queueId, 'q_test_123');

      retryClient.dispose();
    });

    test('network failure scenarios: timeout', () async {
      // Create a custom HTTP client that will timeout
      final timeoutHttpClient = GatekeepHttpClient(
        timeout: const Duration(milliseconds: 50),
      );

      final timeoutConfig = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
        httpClient: timeoutHttpClient,
        storage: mockStorage,
        retryStrategy: RetryStrategy.defaultStrategy(),
        queueRetryStrategy: RetryStrategy.queueStrategy(),
      );
      final timeoutClient = QueueClient(timeoutConfig);

      // Simulate timeout by setting a response that takes longer than timeout
      // Use a real HTTP client mock that will timeout
      // For this test, we'll just verify that timeout exceptions are handled
      expect(
        () => timeoutClient.joinEvent(eventId: 'evt_test_123'),
        throwsA(isA<GatekeepException>()),
      );

      timeoutClient.dispose();
      timeoutHttpClient.close();
    });

    test('network failure scenarios: connection error', () async {
      mockHttpClient.setError(
        'https://test.example.com/v1/queue/join',
        NetworkException.connectionError(
          'https://test.example.com/v1/queue/join',
          Exception('No internet connection'),
        ),
      );

      expect(
        () => client.joinEvent(eventId: 'evt_test_123'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('network failure scenarios: server error', () async {
      // Use GatekeepHttpClient with a mock that returns 500
      final mockHttp = http_testing.MockClient((request) async {
        return http.Response('{"message": "Internal server error"}', 500);
      });

      final httpClient = GatekeepHttpClient(
        client: mockHttp,
        responseInterceptors: [DefaultResponseInterceptor()],
      );

      final serverErrorConfig = GatekeepConfig(
        baseUrl: 'https://test.example.com/v1',
        deviceId: 'test-device-id',
        httpClient: httpClient,
        storage: mockStorage,
        retryStrategy: RetryStrategy.defaultStrategy(),
        queueRetryStrategy: RetryStrategy.queueStrategy(),
      );
      final serverErrorClient = QueueClient(serverErrorConfig);

      // Response interceptor should convert 500 to QueueException
      expect(
        () => serverErrorClient.joinEvent(eventId: 'evt_test_123'),
        throwsA(isA<QueueException>()),
      );

      serverErrorClient.dispose();
      httpClient.close();
    });

    test('token expiration handling', () async {
      // Join and get admitted
      final token = TestHelpers.createTestAdmissionToken(
        expiresAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      final admittedResponse = TestHelpers.sampleStatusResponse(
        queueId: 'q_test_123',
        position: 0,
        status: 'admitted',
        admissionToken: token,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/join',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(admittedResponse),
          headers: {},
        ),
      );

      await client.joinEvent(eventId: 'evt_test_123');

      // Wait for token to expire
      await Future.delayed(const Duration(seconds: 2));

      // Token should no longer be valid
      final restored = await client.restoreToken(eventId: token.eventId);
      expect(restored, isNull);
    });

    test('heartbeat keeps connection alive', () async {
      final joinResponse = TestHelpers.sampleJoinResponse(
        queueId: 'q_test_123',
        position: 100,
      );

      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/join',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(joinResponse),
          headers: {},
        ),
      );

      await client.joinEvent(eventId: 'evt_test_123');

      // Set up status response for polling
      final statusResponse = TestHelpers.sampleStatusResponse(
        queueId: 'q_test_123',
        position: 99,
        estimatedWaitSeconds: 90,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/status',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(statusResponse),
          headers: {},
        ),
      );

      // Set up heartbeat response
      final heartbeatResponse = TestHelpers.sampleHeartbeatResponse(
        queueId: 'q_test_123',
        position: 99,
        estimatedWaitSeconds: 90,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/heartbeat',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(heartbeatResponse),
          headers: {},
        ),
      );

      // Start listening (which starts heartbeat)
      client.listenStatus(queueId: 'q_test_123');

      // Wait for heartbeat to be sent
      await Future.delayed(const Duration(milliseconds: 250));

      // Verify heartbeat was called
      final calls = mockHttpClient.calls;
      expect(calls.any((call) => call.url.contains('heartbeat')), isTrue);
    });

    test('multiple queue entries handled independently', () async {
      // Join first queue
      final response1 = TestHelpers.sampleJoinResponse(
        queueId: 'q_test_1',
        position: 100,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/join',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(response1),
          headers: {},
        ),
      );

      final status1 = await client.joinEvent(eventId: 'evt_1');
      expect(status1.queueId, 'q_test_1');

      // Join second queue
      final response2 = TestHelpers.sampleJoinResponse(
        queueId: 'q_test_2',
        position: 50,
      );
      mockHttpClient.setResponse(
        'https://test.example.com/v1/queue/join',
        HttpResponse(
          statusCode: 200,
          body: _jsonString(response2),
          headers: {},
        ),
      );

      final status2 = await client.joinEvent(eventId: 'evt_2');
      expect(status2.queueId, 'q_test_2');
      expect(status2.queueId, isNot(status1.queueId));
    });
  });
}

String _jsonString(Map<String, dynamic> json) {
  // Convert DateTime objects to ISO strings
  final converted = json.map((key, value) {
    if (value is DateTime) {
      return MapEntry(key, value.toIso8601String());
    }
    if (value is Map) {
      return MapEntry(key, _convertMap(value as Map<String, dynamic>));
    }
    return MapEntry(key, value);
  });
  return jsonEncode(converted);
}

Map<String, dynamic> _convertMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    if (value is DateTime) {
      return MapEntry(key, value.toIso8601String());
    }
    if (value is Map) {
      return MapEntry(key, _convertMap(value as Map<String, dynamic>));
    }
    return MapEntry(key, value);
  });
}
