import 'package:flutter_test/flutter_test.dart';
import 'package:gatekeep/gatekeep.dart';

void main() {
  group('PluginRegistry', () {
    late PluginRegistry registry;

    setUp(() {
      registry = PluginRegistry();
    });

    tearDown(() async {
      await registry.clear();
    });

    group('register', () {
      test('registers enabled plugin', () async {
        final plugin = _TestPlugin(id: 'test_plugin');

        await registry.register(plugin);

        expect(registry.isRegistered('test_plugin'), isTrue);
        expect(plugin.initialized, isTrue);
      });

      test('does not register disabled plugin', () async {
        final plugin = _TestPlugin(id: 'test_plugin', enabled: false);

        await registry.register(plugin);

        expect(registry.isRegistered('test_plugin'), isFalse);
        expect(plugin.initialized, isFalse);
      });

      test('throws error when registering duplicate plugin', () async {
        final plugin1 = _TestPlugin(id: 'test_plugin');
        final plugin2 = _TestPlugin(id: 'test_plugin');

        await registry.register(plugin1);

        expect(() => registry.register(plugin2), throwsA(isA<ArgumentError>()));
      });
    });

    group('unregister', () {
      test('unregisters plugin and disposes it', () async {
        final plugin = _TestPlugin(id: 'test_plugin');
        await registry.register(plugin);

        await registry.unregister('test_plugin');

        expect(registry.isRegistered('test_plugin'), isFalse);
        expect(plugin.disposed, isTrue);
      });

      test('does nothing for non-existent plugin', () async {
        await registry.unregister('non_existent');

        expect(registry.isRegistered('non_existent'), isFalse);
      });
    });

    group('getPlugin', () {
      test('returns plugin by ID and type', () async {
        final plugin = _TestAnalyticsPlugin(id: 'analytics_1');
        await registry.register(plugin);

        final retrieved = registry.getPlugin<AnalyticsPlugin>('analytics_1');

        expect(retrieved, isNotNull);
        expect(retrieved, plugin);
      });

      test('returns null for non-existent plugin', () {
        final retrieved = registry.getPlugin<Plugin>('non_existent');

        expect(retrieved, isNull);
      });

      test('returns null for wrong type', () async {
        final plugin = _TestAnalyticsPlugin(id: 'analytics_1');
        await registry.register(plugin);

        final retrieved = registry.getPlugin<LoggingPlugin>('analytics_1');

        expect(retrieved, isNull);
      });
    });

    group('getPlugins', () {
      test('returns all plugins of specific type', () async {
        final analytics1 = _TestAnalyticsPlugin(id: 'analytics_1');
        final analytics2 = _TestAnalyticsPlugin(id: 'analytics_2');
        final logging = _TestLoggingPlugin(id: 'logging_1');

        await registry.register(analytics1);
        await registry.register(analytics2);
        await registry.register(logging);

        final analyticsPlugins = registry.getPlugins<AnalyticsPlugin>();

        expect(analyticsPlugins.length, 2);
        expect(analyticsPlugins, contains(analytics1));
        expect(analyticsPlugins, contains(analytics2));
      });

      test('returns empty list when no plugins of type', () {
        final plugins = registry.getPlugins<AnalyticsPlugin>();

        expect(plugins, isEmpty);
      });
    });

    group('getAllPlugins', () {
      test('returns all registered plugins', () async {
        final plugin1 = _TestPlugin(id: 'plugin_1');
        final plugin2 = _TestPlugin(id: 'plugin_2');

        await registry.register(plugin1);
        await registry.register(plugin2);

        final all = registry.getAllPlugins();

        expect(all.length, 2);
        expect(all, contains(plugin1));
        expect(all, contains(plugin2));
      });
    });

    group('isRegistered', () {
      test('returns true for registered plugin', () async {
        final plugin = _TestPlugin(id: 'test_plugin');
        await registry.register(plugin);

        expect(registry.isRegistered('test_plugin'), isTrue);
      });

      test('returns false for non-registered plugin', () {
        expect(registry.isRegistered('non_existent'), isFalse);
      });
    });

    group('clear', () {
      test('disposes all plugins and clears registry', () async {
        final plugin1 = _TestPlugin(id: 'plugin_1');
        final plugin2 = _TestPlugin(id: 'plugin_2');

        await registry.register(plugin1);
        await registry.register(plugin2);

        await registry.clear();

        expect(registry.getAllPlugins(), isEmpty);
        expect(plugin1.disposed, isTrue);
        expect(plugin2.disposed, isTrue);
      });
    });

    group('notifyInitialized', () {
      test('notifies lifecycle plugins', () async {
        final lifecyclePlugin = _TestLifecyclePlugin(id: 'lifecycle_1');
        await registry.register(lifecyclePlugin);

        registry.notifyInitialized();

        expect(lifecyclePlugin.initializedCalled, isTrue);
      });

      test('does not notify non-lifecycle plugins', () async {
        final plugin = _TestPlugin(id: 'plugin_1');
        await registry.register(plugin);

        expect(() => registry.notifyInitialized(), returnsNormally);
      });
    });

    group('notifyDisposed', () {
      test('notifies lifecycle plugins', () async {
        final lifecyclePlugin = _TestLifecyclePlugin(id: 'lifecycle_1');
        await registry.register(lifecyclePlugin);

        registry.notifyDisposed();

        expect(lifecyclePlugin.disposedCalled, isTrue);
      });
    });
  });
}

// Test plugin implementations
class _TestPlugin extends Plugin {
  _TestPlugin({required this.id, this.enabled = true});

  @override
  final String id;

  @override
  final bool enabled;

  @override
  String get name => 'Test Plugin';

  @override
  String get version => '1.0.0';

  bool initialized = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _TestAnalyticsPlugin extends AnalyticsPlugin {
  _TestAnalyticsPlugin({required this.id});

  @override
  final String id;

  @override
  String get name => 'Test Analytics';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  void trackQueueJoin(String eventId, {Map<String, dynamic>? properties}) {}

  @override
  void trackQueuePosition(
    String queueId,
    int position, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackAdmission(
    String queueId,
    String eventId, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackError(
    String errorType,
    String errorMessage, {
    Map<String, dynamic>? properties,
  }) {}

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? properties}) {}
}

class _TestLoggingPlugin extends LoggingPlugin {
  _TestLoggingPlugin({required this.id});

  @override
  final String id;

  @override
  String get name => 'Test Logging';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

class _TestLifecyclePlugin extends LifecyclePlugin {
  _TestLifecyclePlugin({required this.id});

  @override
  final String id;

  @override
  String get name => 'Test Lifecycle';

  @override
  String get version => '1.0.0';

  bool initializedCalled = false;
  bool disposedCalled = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  void onInitialized() {
    initializedCalled = true;
  }

  @override
  void onDisposed() {
    disposedCalled = true;
  }
}
