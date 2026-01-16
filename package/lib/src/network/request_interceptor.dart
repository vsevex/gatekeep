import 'dart:async';

/// Interface for intercepting and modifying requests before they are sent
abstract class RequestInterceptor {
  /// Intercept and modify a request
  /// Return the modified request or the original if no changes needed
  Future<InterceptedRequest> intercept(InterceptedRequest request);

  /// Priority of this interceptor (lower = higher priority)
  int get priority => 0;
}

/// Request data that can be intercepted
class InterceptedRequest {
  const InterceptedRequest({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    this.queryParameters,
  });

  /// Request URL
  final String url;

  /// Request method (GET, POST, etc.)
  final String method;

  /// Request headers
  final Map<String, String> headers;

  /// Request body (for POST/PUT)
  final Map<String, dynamic>? body;

  /// Query parameters (for GET)
  final Map<String, dynamic>? queryParameters;

  /// Create a copy with updated fields
  InterceptedRequest copyWith({
    String? url,
    String? method,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
  }) => InterceptedRequest(
    url: url ?? this.url,
    method: method ?? this.method,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    queryParameters: queryParameters ?? this.queryParameters,
  );
}

/// Default request interceptor that adds common headers
class DefaultRequestInterceptor implements RequestInterceptor {
  const DefaultRequestInterceptor({
    this.defaultHeaders = const {},
    this.deviceId,
    this.userId,
  });

  final Map<String, String> defaultHeaders;
  final String? deviceId;
  final String? userId;

  @override
  Future<InterceptedRequest> intercept(InterceptedRequest request) async {
    final headers = Map<String, String>.from(request.headers)
      // Add default headers
      ..addAll(defaultHeaders);

    // Add device/user identification
    if (deviceId != null) {
      headers['X-Device-ID'] = deviceId!;
    }
    if (userId != null) {
      headers['X-User-ID'] = userId!;
    }

    // Add content type for POST/PUT
    if (request.method == 'POST' || request.method == 'PUT') {
      headers['Content-Type'] = 'application/json';
    }

    return request.copyWith(headers: headers);
  }

  @override
  int get priority => 100; // Lower priority (runs later)
}
