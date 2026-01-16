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

    // Handle network errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return NetworkException.connectionError('', error);
    }

    if (error.toString().contains('TimeoutException')) {
      return NetworkException.timeout('', const Duration(seconds: 30));
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
