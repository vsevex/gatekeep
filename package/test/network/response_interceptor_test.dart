import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('DefaultResponseInterceptor', () {
    late DefaultResponseInterceptor interceptor;

    setUp(() => interceptor = DefaultResponseInterceptor());

    test('passes through successful responses', () async {
      const response = HttpResponse(
        statusCode: 200,
        body: '{"key": "value"}',
        headers: {},
      );

      final result = await interceptor.intercept(response);

      expect(result, response);
    });

    test('throws QueueException for 4xx status codes', () async {
      const response = HttpResponse(
        statusCode: 404,
        body: '{"message": "Not found"}',
        headers: {},
      );

      expect(
        () => interceptor.intercept(response),
        throwsA(isA<QueueException>()),
      );
    });

    test('throws QueueException for 5xx status codes', () async {
      const response = HttpResponse(
        statusCode: 500,
        body: '{"message": "Internal server error"}',
        headers: {},
      );

      expect(
        () => interceptor.intercept(response),
        throwsA(isA<QueueException>()),
      );
    });

    test('handles error body without JSON', () async {
      const response = HttpResponse(
        statusCode: 400,
        body: 'Plain text error',
        headers: {},
      );

      expect(
        () => interceptor.intercept(response),
        throwsA(isA<QueueException>()),
      );
    });

    test('onError returns GatekeepException as-is', () async {
      final exception = QueueException.fromStatusCode(
        404,
        'Queue not found',
        null,
      );

      final result = await interceptor.onError(exception, StackTrace.current);

      expect(result, exception);
    });

    test('onError converts SocketException to NetworkException', () async {
      final error = Exception('SocketException: Failed host lookup');

      final result = await interceptor.onError(error, StackTrace.current);

      expect(result, isA<NetworkException>());
    });

    test('onError converts TimeoutException to NetworkException', () async {
      final error = Exception('TimeoutException: Request timed out');

      final result = await interceptor.onError(error, StackTrace.current);

      expect(result, isA<NetworkException>());
    });

    test('onError creates generic exception for unknown errors', () async {
      final error = Exception('Unknown error');

      final result = await interceptor.onError(error, StackTrace.current);

      expect(result, isA<GatekeepException>());
    });

    test('has correct priority', () => expect(interceptor.priority, 100));
  });
}
