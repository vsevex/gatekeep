import 'package:gatekeep/gatekeep.dart';

/// Mock HTTP client for testing
class MockHttpClient implements HttpClientInterface {
  MockHttpClient();

  final List<_RequestCall> _calls = [];
  final Map<String, HttpResponse> _responses = {};
  final Map<String, Exception> _errors = {};

  /// Record a call
  void _recordCall(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) {
    _calls.add(
      _RequestCall(
        method: method,
        url: url,
        body: body,
        queryParameters: queryParameters,
      ),
    );
  }

  /// Set response for a URL pattern
  void setResponse(String urlPattern, HttpResponse response) {
    _responses[urlPattern] = response;
  }

  /// Set error for a URL pattern
  void setError(String urlPattern, Exception error) {
    _errors[urlPattern] = error;
  }

  /// Get all calls
  List get calls => List<_RequestCall>.unmodifiable(_calls);

  /// Clear all calls and responses
  void clear() {
    _calls.clear();
    _responses.clear();
    _errors.clear();
  }

  /// Clear error for a specific URL
  void clearError(String url) {
    _errors.remove(url);
  }

  @override
  Future<HttpResponse> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    _recordCall('GET', url, queryParameters: queryParameters);
    await Future.delayed(const Duration(milliseconds: 10));

    if (_errors.containsKey(url)) {
      throw _errors[url]!;
    }

    return _responses[url] ??
        const HttpResponse(statusCode: 200, body: '{}', headers: {});
  }

  @override
  Future<HttpResponse> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    _recordCall('POST', url, body: body);
    await Future.delayed(const Duration(milliseconds: 10));

    if (_errors.containsKey(url)) {
      throw _errors[url]!;
    }

    return _responses[url] ??
        const HttpResponse(statusCode: 200, body: '{}', headers: {});
  }

  @override
  Future<HttpResponse> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    _recordCall('PUT', url, body: body);
    await Future.delayed(const Duration(milliseconds: 10));

    if (_errors.containsKey(url)) {
      throw _errors[url]!;
    }

    return _responses[url] ??
        const HttpResponse(statusCode: 200, body: '{}', headers: {});
  }

  @override
  Future<HttpResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    _recordCall('DELETE', url);
    await Future.delayed(const Duration(milliseconds: 10));

    if (_errors.containsKey(url)) {
      throw _errors[url]!;
    }

    return _responses[url] ??
        const HttpResponse(statusCode: 200, body: '{}', headers: {});
  }

  @override
  void close() {
    // No-op for mock
  }
}

class _RequestCall {
  const _RequestCall({
    required this.method,
    required this.url,
    this.body,
    this.queryParameters,
  });

  final String method;
  final String url;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? queryParameters;
}
