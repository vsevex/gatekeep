import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('InterceptedRequest', () {
    test('copyWith creates new instance with updated fields', () {
      const original = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {'header1': 'value1'},
      );

      final updated = original.copyWith(
        url: 'https://new.com',
        headers: {'header2': 'value2'},
      );

      expect(updated.url, 'https://new.com');
      expect(updated.method, 'GET');
      expect(updated.headers, {'header2': 'value2'});
      expect(original.url, 'https://example.com'); // Original unchanged
    });
  });

  group('DefaultRequestInterceptor', () {
    test('adds default headers', () async {
      const interceptor = DefaultRequestInterceptor(
        defaultHeaders: {'X-Custom': 'value'},
      );

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['X-Custom'], 'value');
    });

    test('adds device ID header when provided', () async {
      const interceptor = DefaultRequestInterceptor(deviceId: 'device-123');

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['X-Device-ID'], 'device-123');
    });

    test('adds user ID header when provided', () async {
      const interceptor = DefaultRequestInterceptor(userId: 'user-456');

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['X-User-ID'], 'user-456');
    });

    test('adds Content-Type for POST requests', () async {
      const interceptor = DefaultRequestInterceptor();

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'POST',
        headers: {},
        body: {'key': 'value'},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['Content-Type'], 'application/json');
    });

    test('adds Content-Type for PUT requests', () async {
      const interceptor = DefaultRequestInterceptor();

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'PUT',
        headers: {},
        body: {'key': 'value'},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['Content-Type'], 'application/json');
    });

    test('does not add Content-Type for GET requests', () async {
      const interceptor = DefaultRequestInterceptor();

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers.containsKey('Content-Type'), isFalse);
    });

    test('preserves existing headers', () async {
      const interceptor = DefaultRequestInterceptor(
        defaultHeaders: {'X-Custom': 'value'},
      );

      const request = InterceptedRequest(
        url: 'https://example.com',
        method: 'GET',
        headers: {'Existing': 'header'},
      );

      final intercepted = await interceptor.intercept(request);

      expect(intercepted.headers['Existing'], 'header');
      expect(intercepted.headers['X-Custom'], 'value');
    });

    test('has correct priority', () {
      const interceptor = DefaultRequestInterceptor();
      expect(interceptor.priority, 100);
    });
  });
}
