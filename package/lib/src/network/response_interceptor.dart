import 'dart:async';
import 'dart:convert';

import '../errors/gatekeep_exception.dart';
import '../errors/queue_exception.dart';
import '../errors/network_exception.dart';
import 'http_client_interface.dart';

/// Interface for intercepting and modifying responses
abstract class ResponseInterceptor {
  /// Intercept and modify a response
  /// Can throw exceptions to trigger retry logic
  Future<HttpResponse> intercept(HttpResponse response);

  /// Handle errors
  Future<GatekeepException> onError(Object error, StackTrace stackTrace);

  /// Priority of this interceptor (lower = higher priority)
  int get priority => 0;
}

/// Default response interceptor that handles common error cases
class DefaultResponseInterceptor implements ResponseInterceptor {
  @override
  Future<HttpResponse> intercept(HttpResponse response) async {
    // Check for error status codes
    if (!response.isSuccess) {
      final errorBody = _tryParseErrorBody(response.body);
      throw QueueException.fromStatusCode(
        response.statusCode,
        errorBody['message'] as String?,
        errorBody,
      );
    }

    return response;
  }

  @override
  Future<GatekeepException> onError(Object error, StackTrace stackTrace) async {
    if (error is GatekeepException) {
      return error;
    }

    // Try to extract URL from error message
    String? extractUrl(Object error) {
      final errorStr = error.toString();
      // Try to find URL patterns in error messages
      final uriMatch = RegExp(r'https?://[^\s]+').firstMatch(errorStr);
      if (uriMatch != null) {
        return uriMatch.group(0);
      }
      // Check if it's a SocketException with host info
      final hostMatch = RegExp(r'host[:\s]+([^\s,)]+)').firstMatch(errorStr);
      if (hostMatch != null) {
        return hostMatch.group(1);
      }
      return null;
    }

    // Handle network errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Network is unreachable')) {
      final url = extractUrl(error) ?? 'unknown';
      return NetworkException.connectionError(url, error);
    }

    if (error.toString().contains('TimeoutException')) {
      final url = extractUrl(error) ?? 'unknown';
      return NetworkException.timeout(url, const Duration(seconds: 30));
    }

    // Generic error - create a concrete exception
    return _GenericException(
      error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  Map<String, dynamic> _tryParseErrorBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'message': body};
    }
  }

  @override
  int get priority => 100;
}

/// Generic exception implementation
class _GenericException extends GatekeepException {
  const _GenericException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}
