import 'dart:async';

// Import for jsonDecode
import 'dart:convert';

/// Interface for HTTP client implementations
/// Allows for easy swapping of HTTP clients (http, dio, etc.)
abstract class HttpClientInterface {
  /// Send a GET request
  Future<HttpResponse> get(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Send a POST request
  Future<HttpResponse> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  });

  /// Send a PUT request
  Future<HttpResponse> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  });

  /// Send a DELETE request
  Future<HttpResponse> delete(String url, {Map<String, String>? headers});

  /// Close the client and release resources
  void close();
}

/// HTTP response wrapper
class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  /// Response status code
  final int statusCode;

  /// Response body as string
  final String body;

  /// Response headers
  final Map<String, String> headers;

  /// Whether the request was successful (2xx status codes)
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Parse body as JSON
  Map<String, dynamic> get json {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JSON: $e', body);
    }
  }

  /// Parse body as JSON list
  List<dynamic> get jsonList {
    try {
      return jsonDecode(body) as List<dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JSON list: $e', body);
    }
  }
}
