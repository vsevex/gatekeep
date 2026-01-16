import '../network/http_client_interface.dart';
import '../network/request_interceptor.dart';
import '../network/response_interceptor.dart';
import '../storage/storage_interface.dart';
import '../utils/retry_strategy.dart';
import '../plugins/plugin_registry.dart';

/// Configuration for Gatekeep SDK
/// Allows full customization of all components
class GatekeepConfig {
  const GatekeepConfig({
    required this.baseUrl,
    required this.deviceId,
    this.userId,
    this.httpClient,
    this.storage,
    this.requestInterceptors = const [],
    this.responseInterceptors = const [],
    this.retryStrategy,
    this.queueRetryStrategy,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 5),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.autoHeartbeat = true,
    this.pluginRegistry,
    this.debug = false,
  });

  /// Base URL of the Gatekeep API
  final String baseUrl;

  /// Device ID (required)
  final String deviceId;

  /// User ID (optional)
  final String? userId;

  /// Custom HTTP client (optional, uses default if not provided)
  final HttpClientInterface? httpClient;

  /// Custom storage implementation (optional, uses secure storage if not provided)
  final StorageInterface? storage;

  /// Request interceptors
  final List<RequestInterceptor> requestInterceptors;

  /// Response interceptors
  final List<ResponseInterceptor> responseInterceptors;

  /// Retry strategy for network operations
  final RetryStrategy? retryStrategy;

  /// Retry strategy for queue operations
  final RetryStrategy? queueRetryStrategy;

  /// Custom headers to include in all requests
  final Map<String, String> headers;

  /// Request timeout
  final Duration timeout;

  /// Polling interval for queue status
  final Duration pollInterval;

  /// Heartbeat interval
  final Duration heartbeatInterval;

  /// Whether to automatically send heartbeats
  final bool autoHeartbeat;

  /// Plugin registry for extensions
  final PluginRegistry? pluginRegistry;

  /// Enable debug logging
  final bool debug;

  /// Create a copy with updated fields
  GatekeepConfig copyWith({
    String? baseUrl,
    String? deviceId,
    String? userId,
    HttpClientInterface? httpClient,
    StorageInterface? storage,
    List<RequestInterceptor>? requestInterceptors,
    List<ResponseInterceptor>? responseInterceptors,
    RetryStrategy? retryStrategy,
    RetryStrategy? queueRetryStrategy,
    Map<String, String>? headers,
    Duration? timeout,
    Duration? pollInterval,
    Duration? heartbeatInterval,
    bool? autoHeartbeat,
    PluginRegistry? pluginRegistry,
    bool? debug,
  }) => GatekeepConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    deviceId: deviceId ?? this.deviceId,
    userId: userId ?? this.userId,
    httpClient: httpClient ?? this.httpClient,
    storage: storage ?? this.storage,
    requestInterceptors: requestInterceptors ?? this.requestInterceptors,
    responseInterceptors: responseInterceptors ?? this.responseInterceptors,
    retryStrategy: retryStrategy ?? this.retryStrategy,
    queueRetryStrategy: queueRetryStrategy ?? this.queueRetryStrategy,
    headers: headers ?? this.headers,
    timeout: timeout ?? this.timeout,
    pollInterval: pollInterval ?? this.pollInterval,
    heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
    autoHeartbeat: autoHeartbeat ?? this.autoHeartbeat,
    pluginRegistry: pluginRegistry ?? this.pluginRegistry,
    debug: debug ?? this.debug,
  );

  /// Validate configuration
  void validate() {
    if (baseUrl.isEmpty) {
      throw ArgumentError('baseUrl cannot be empty');
    }
    if (deviceId.isEmpty) {
      throw ArgumentError('deviceId cannot be empty');
    }
    if (!Uri.parse(baseUrl).isAbsolute) {
      throw ArgumentError('baseUrl must be a valid absolute URL');
    }
  }
}
