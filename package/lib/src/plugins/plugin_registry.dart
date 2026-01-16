import 'plugin_interface.dart';

/// Registry for managing plugins
class PluginRegistry {
  final Map<String, Plugin> _plugins = {};

  /// Register a plugin
  Future<void> register(Plugin plugin) async {
    if (_plugins.containsKey(plugin.id)) {
      throw ArgumentError('Plugin with id ${plugin.id} is already registered');
    }

    if (plugin.enabled) {
      await plugin.initialize();
      _plugins[plugin.id] = plugin;
    }
  }

  /// Unregister a plugin
  Future<void> unregister(String pluginId) async {
    final plugin = _plugins.remove(pluginId);
    if (plugin != null) {
      await plugin.dispose();
    }
  }

  /// Get a plugin by ID
  T? getPlugin<T extends Plugin>(String pluginId) {
    final plugin = _plugins[pluginId];
    return plugin is T ? plugin : null;
  }

  /// Get all plugins of a specific type
  List<T> getPlugins<T extends Plugin>() {
    return _plugins.values.whereType<T>().toList();
  }

  /// Get all registered plugins
  List<Plugin> getAllPlugins() {
    return _plugins.values.toList();
  }

  /// Check if a plugin is registered
  bool isRegistered(String pluginId) {
    return _plugins.containsKey(pluginId);
  }

  /// Clear all plugins
  Future<void> clear() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();
  }

  /// Notify lifecycle plugins of initialization
  void notifyInitialized() {
    for (final plugin in getPlugins<LifecyclePlugin>()) {
      plugin.onInitialized();
    }
  }

  /// Notify lifecycle plugins of disposal
  void notifyDisposed() {
    for (final plugin in getPlugins<LifecyclePlugin>()) {
      plugin.onDisposed();
    }
  }
}
