import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'http_client_interface.dart';
import 'request_interceptor.dart';
import 'response_interceptor.dart';
import '../errors/network_exception.dart';

/// HTTP client implementation using the `http` package
/// Supports interceptors for request/response modification
class GatekeepHttpClient implements HttpClientInterface {
  GatekeepHttpClient({
    http.Client? client,
    List<RequestInterceptor>? requestInterceptors,
    List<ResponseInterceptor>? responseInterceptors,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _requestInterceptors = requestInterceptors ?? [],
       _responseInterceptors = responseInterceptors ?? [] {
    // Sort interceptors by priority
    _requestInterceptors.sort((a, b) => a.priority.compareTo(b.priority));
    _responseInterceptors.sort((a, b) => a.priority.compareTo(b.priority));
  }

  final http.Client _client;
  final List<RequestInterceptor> _requestInterceptors;
  final List<ResponseInterceptor> _responseInterceptors;
  final Duration timeout;

  @override
  Future<HttpResponse> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) => _executeRequest(
    url: url,
    method: 'GET',
    headers: headers,
    queryParameters: queryParameters,
  );

  @override
  Future<HttpResponse> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) => _executeRequest(url: url, method: 'POST', headers: headers, body: body);

  @override
  Future<HttpResponse> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) => _executeRequest(url: url, method: 'PUT', headers: headers, body: body);

  @override
  Future<HttpResponse> delete(String url, {Map<String, String>? headers}) =>
      _executeRequest(url: url, method: 'DELETE', headers: headers);

  Future<HttpResponse> _executeRequest({
    required String url,
    required String method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(url, queryParameters);

      // Create initial request
      var request = InterceptedRequest(
        url: uri.toString(),
        method: method,
        headers: headers ?? {},
        body: body,
        queryParameters: queryParameters,
      );

      // Apply request interceptors
      for (final interceptor in _requestInterceptors) {
        request = await interceptor.intercept(request);
      }

      // Prepare HTTP request
      http.Request httpRequest;
      if (method == 'GET') {
        httpRequest = http.Request(method, uri);
      } else {
        httpRequest = http.Request(method, uri);
        if (body != null) {
          httpRequest.body = jsonEncode(body);
        }
      }

      // Add headers
      httpRequest.headers.addAll(request.headers);

      // Send request
      final streamedResponse = await _client
          .send(httpRequest)
          .timeout(
            timeout,
            onTimeout: () {
              throw NetworkException.timeout(url, timeout);
            },
          );

      // Read response
      final responseBody = await streamedResponse.stream.bytesToString();

      // Create response
      var response = HttpResponse(
        statusCode: streamedResponse.statusCode,
        body: responseBody,
        headers: streamedResponse.headers,
      );

      // Apply response interceptors
      for (final interceptor in _responseInterceptors) {
        response = await interceptor.intercept(response);
      }

      return response;
    } catch (e, stackTrace) {
      // Handle errors through response interceptors
      for (final interceptor in _responseInterceptors) {
        final exception = await interceptor.onError(e, stackTrace);
        throw exception;
      }
      rethrow;
    }
  }

  Uri _buildUri(String url, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse(url);

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final queryMap = <String, String>{};
    queryParameters.forEach((key, value) {
      queryMap[key] = value.toString();
    });

    return uri.replace(queryParameters: queryMap);
  }

  @override
  void close() => _client.close();
}
