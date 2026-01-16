import 'gatekeep_config.dart';
import '../network/gatekeep_http_client.dart';
import '../network/http_client_interface.dart';
import '../network/request_interceptor.dart';
import '../network/response_interceptor.dart';
import '../storage/secure_storage.dart';
import '../storage/storage_interface.dart';
import '../utils/retry_strategy.dart';
import '../plugins/plugin_registry.dart';

/// Helper class for initializing Gatekeep with sensible defaults
class GatekeepInitializer {
  GatekeepInitializer._();

  /// Initialize with minimal configuration
  /// Uses defaults for all optional components
  static GatekeepConfig initialize({
    required String baseUrl,
    required String deviceId,
    String? userId,
    Map<String, String>? headers,
    bool debug = false,
  }) {
    // Create default request interceptor
    final requestInterceptor = DefaultRequestInterceptor(
      deviceId: deviceId,
      userId: userId,
      defaultHeaders: headers ?? {},
    );

    // Create default response interceptor
    final responseInterceptor = DefaultResponseInterceptor();

    // Create HTTP client with interceptors
    final httpClient = GatekeepHttpClient(
      requestInterceptors: [requestInterceptor],
      responseInterceptors: [responseInterceptor],
    );

    // Create storage
    final storage = SecureStorage();

    // Create plugin registry
    final pluginRegistry = PluginRegistry();

    return GatekeepConfig(
      baseUrl: baseUrl,
      deviceId: deviceId,
      userId: userId,
      httpClient: httpClient,
      storage: storage,
      requestInterceptors: [requestInterceptor],
      responseInterceptors: [responseInterceptor],
      retryStrategy: RetryStrategy.networkStrategy(),
      queueRetryStrategy: RetryStrategy.queueStrategy(),
      headers: headers ?? {},
      debug: debug,
      pluginRegistry: pluginRegistry,
    );
  }

  /// Initialize with full customization
  static GatekeepConfig initializeWith({
    required String baseUrl,
    required String deviceId,
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
    bool debug = false,
  }) {
    // Build request interceptors list
    final requestInterceptorsList = <RequestInterceptor>[];
    if (requestInterceptors != null) {
      requestInterceptorsList.addAll(requestInterceptors);
    }

    // Add default if not already present
    final hasDefaultRequest = requestInterceptorsList.any(
      (i) => i is DefaultRequestInterceptor,
    );
    if (!hasDefaultRequest) {
      requestInterceptorsList.add(
        DefaultRequestInterceptor(
          deviceId: deviceId,
          userId: userId,
          defaultHeaders: headers ?? {},
        ),
      );
    }

    // Build response interceptors list
    final responseInterceptorsList = <ResponseInterceptor>[];
    if (responseInterceptors != null) {
      responseInterceptorsList.addAll(responseInterceptors);
    }

    // Add default if not already present
    final hasDefaultResponse = responseInterceptorsList.any(
      (i) => i is DefaultResponseInterceptor,
    );
    if (!hasDefaultResponse) {
      responseInterceptorsList.add(DefaultResponseInterceptor());
    }

    // Create HTTP client if not provided
    final httpClientInstance =
        httpClient ??
        GatekeepHttpClient(
          requestInterceptors: requestInterceptorsList,
          responseInterceptors: responseInterceptorsList,
        );

    // Create storage if not provided
    final storageInstance = storage ?? SecureStorage();

    // Create plugin registry if not provided
    final pluginRegistryInstance = pluginRegistry ?? PluginRegistry();

    return GatekeepConfig(
      baseUrl: baseUrl,
      deviceId: deviceId,
      userId: userId,
      httpClient: httpClientInstance,
      storage: storageInstance,
      requestInterceptors: requestInterceptorsList,
      responseInterceptors: responseInterceptorsList,
      retryStrategy: retryStrategy ?? RetryStrategy.networkStrategy(),
      queueRetryStrategy: queueRetryStrategy ?? RetryStrategy.queueStrategy(),
      headers: headers ?? {},
      timeout: timeout ?? const Duration(seconds: 30),
      pollInterval: pollInterval ?? const Duration(seconds: 5),
      heartbeatInterval: heartbeatInterval ?? const Duration(seconds: 30),
      autoHeartbeat: autoHeartbeat ?? true,
      pluginRegistry: pluginRegistryInstance,
      debug: debug,
    );
  }
}
