/// Base interface for all Gatekeep plugins
/// Plugins allow extending functionality without modifying core code
abstract class Plugin {
  /// Unique identifier for this plugin
  String get id;

  /// Plugin name
  String get name;

  /// Plugin version
  String get version;

  /// Initialize the plugin
  /// Called when plugin is registered
  Future<void> initialize();

  /// Cleanup the plugin
  /// Called when plugin is unregistered
  Future<void> dispose();

  /// Check if plugin is enabled
  bool get enabled => true;
}

/// Plugin that can handle lifecycle events
abstract class LifecyclePlugin extends Plugin {
  /// Called when queue client is initialized
  void onInitialized();

  /// Called when queue client is disposed
  void onDisposed();
}

/// Plugin that can intercept requests
abstract class RequestPlugin extends Plugin {
  /// Intercept and modify request data
  /// Return modified data or original if no changes
  Future<Map<String, dynamic>?> interceptRequest(
    String endpoint,
    Map<String, dynamic>? data,
  );
}

/// Plugin that can intercept responses
abstract class ResponsePlugin extends Plugin {
  /// Intercept and modify response data
  /// Return modified data or original if no changes
  Future<Map<String, dynamic>?> interceptResponse(
    String endpoint,
    Map<String, dynamic>? data,
  );
}

/// Plugin that can handle errors
abstract class ErrorPlugin extends Plugin {
  /// Handle an error
  void onError(Object error, StackTrace? stackTrace);
}
