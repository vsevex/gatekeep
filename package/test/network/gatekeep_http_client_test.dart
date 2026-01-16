import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

void main() {
  group('GatekeepHttpClient', () {
    late GatekeepHttpClient client;

    tearDown(() => client.close());

    test('GET request works correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://example.com/test?key=value');
        return http.Response('{"result": "success"}', 200);
      });

      client = GatekeepHttpClient(client: mockClient);

      final response = await client.get(
        'https://example.com/test',
        queryParameters: {'key': 'value'},
      );

      expect(response.statusCode, 200);
      expect(response.json, {'result': 'success'});
    });

    test('POST request works correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://example.com/test');
        expect(request.body, '{"key":"value"}');
        return http.Response('{"result": "created"}', 201);
      });

      client = GatekeepHttpClient(client: mockClient);

      final response = await client.post(
        'https://example.com/test',
        body: {'key': 'value'},
      );

      expect(response.statusCode, 201);
      expect(response.json, {'result': 'created'});
    });

    test('PUT request works correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'PUT');
        return http.Response('{"result": "updated"}', 200);
      });

      client = GatekeepHttpClient(client: mockClient);

      final response = await client.put(
        'https://example.com/test',
        body: {'key': 'value'},
      );

      expect(response.statusCode, 200);
      expect(response.json, {'result': 'updated'});
    });

    test('DELETE request works correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'DELETE');
        return http.Response('', 204);
      });

      client = GatekeepHttpClient(client: mockClient);

      final response = await client.delete('https://example.com/test');

      expect(response.statusCode, 204);
    });

    test('applies request interceptors', () async {
      var interceptorCalled = false;
      final interceptor = _TestRequestInterceptor(
        onIntercept: (request) async {
          interceptorCalled = true;
          return request.copyWith(
            headers: {...request.headers, 'X-Custom': 'value'},
          );
        },
      );

      final mockClient = http_testing.MockClient((request) async {
        expect(request.headers['X-Custom'], 'value');
        return http.Response('{}', 200);
      });

      client = GatekeepHttpClient(
        client: mockClient,
        requestInterceptors: [interceptor],
      );

      await client.get('https://example.com/test');

      expect(interceptorCalled, isTrue);
    });

    test('applies response interceptors', () async {
      var interceptorCalled = false;
      final interceptor = _TestResponseInterceptor(
        onIntercept: (response) async {
          interceptorCalled = true;
          return response;
        },
      );

      final mockClient = http_testing.MockClient((request) async {
        return http.Response('{}', 200);
      });

      client = GatekeepHttpClient(
        client: mockClient,
        responseInterceptors: [interceptor],
      );

      await client.get('https://example.com/test');

      expect(interceptorCalled, isTrue);
    });

    test('sorts interceptors by priority', () async {
      final callOrder = <int>[];
      final interceptor1 = _TestRequestInterceptor(
        priority: 10,
        onIntercept: (request) async {
          callOrder.add(1);
          return request;
        },
      );
      final interceptor2 = _TestRequestInterceptor(
        priority: 5,
        onIntercept: (request) async {
          callOrder.add(2);
          return request;
        },
      );

      final mockClient = http_testing.MockClient((request) async {
        return http.Response('{}', 200);
      });

      client = GatekeepHttpClient(
        client: mockClient,
        requestInterceptors: [interceptor1, interceptor2],
      );

      await client.get('https://example.com/test');

      expect(callOrder, [2, 1]); // Lower priority runs first
    });

    test('handles timeout correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        await Future.delayed(const Duration(seconds: 2));
        return http.Response('{}', 200);
      });

      client = GatekeepHttpClient(
        client: mockClient,
        timeout: const Duration(milliseconds: 100),
      );

      expect(
        () => client.get('https://example.com/test'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('handles network errors through response interceptors', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Network error');
      });

      final interceptor = _TestResponseInterceptor(
        onIntercept: (response) async => response,
        onErrorHandler: (error, stackTrace) async {
          return NetworkException.connectionError('https://example.com', error);
        },
      );

      client = GatekeepHttpClient(
        client: mockClient,
        responseInterceptors: [interceptor],
      );

      expect(
        () => client.get('https://example.com/test'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('builds URI with query parameters correctly', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.queryParameters['key1'], 'value1');
        expect(request.url.queryParameters['key2'], 'value2');
        return http.Response('{}', 200);
      });

      client = GatekeepHttpClient(client: mockClient);

      await client.get(
        'https://example.com/test',
        queryParameters: {'key1': 'value1', 'key2': 'value2'},
      );
    });
  });
}

class _TestRequestInterceptor implements RequestInterceptor {
  _TestRequestInterceptor({required this.onIntercept, this.priority = 0});

  final Future<InterceptedRequest> Function(InterceptedRequest) onIntercept;
  @override
  final int priority;

  @override
  Future<InterceptedRequest> intercept(InterceptedRequest request) =>
      onIntercept(request);
}

class _TestResponseInterceptor implements ResponseInterceptor {
  _TestResponseInterceptor({required this.onIntercept, this.onErrorHandler});

  final Future<HttpResponse> Function(HttpResponse) onIntercept;
  final Future<GatekeepException> Function(Object, StackTrace)? onErrorHandler;
  @override
  int get priority => 0;

  @override
  Future<HttpResponse> intercept(HttpResponse response) =>
      onIntercept(response);

  @override
  Future<GatekeepException> onError(Object error, StackTrace stackTrace) {
    if (onErrorHandler != null) {
      return onErrorHandler!(error, stackTrace);
    }

    return Future.value(
      QueueException.fromStatusCode(500, error.toString(), null),
    );
  }
}
