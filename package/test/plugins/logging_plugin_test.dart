import 'package:flutter_test/flutter_test.dart';

import 'package:gatekeep/gatekeep.dart';

void main() {
  group('ConsoleLoggingPlugin', () {
    late ConsoleLoggingPlugin plugin;

    setUp(() => plugin = ConsoleLoggingPlugin());

    test('has correct properties', () {
      expect(plugin.id, 'console_logging');
      expect(plugin.name, 'Console Logging');
      expect(plugin.version, '1.0.0');
    });

    test('has default minLevel of info', () {
      final defaultPlugin = ConsoleLoggingPlugin();
      expect(defaultPlugin.minLevel, LogLevel.info);
    });

    test('can set custom minLevel', () {
      final debugPlugin = ConsoleLoggingPlugin(minLevel: LogLevel.debug);
      expect(debugPlugin.minLevel, LogLevel.debug);
    });

    test(
      'initialize does nothing',
      () => expect(() => plugin.initialize(), returnsNormally),
    );

    test(
      'dispose does nothing',
      () => expect(() => plugin.dispose(), returnsNormally),
    );

    test('log respects minLevel', () {
      final warningPlugin = ConsoleLoggingPlugin(minLevel: LogLevel.warning);

      // Should not log debug/info
      expect(() => warningPlugin.log(LogLevel.debug, 'debug'), returnsNormally);
      expect(() => warningPlugin.log(LogLevel.info, 'info'), returnsNormally);

      // Should log warning/error
      expect(
        () => warningPlugin.log(LogLevel.warning, 'warning'),
        returnsNormally,
      );
      expect(() => warningPlugin.log(LogLevel.error, 'error'), returnsNormally);
    });

    test(
      'debug calls log with debug level',
      () => expect(() => plugin.debug('debug message'), returnsNormally),
    );

    test(
      'info calls log with info level',
      () => expect(() => plugin.info('info message'), returnsNormally),
    );

    test(
      'warning calls log with warning level',
      () => expect(() => plugin.warning('warning message'), returnsNormally),
    );

    test(
      'error calls log with error level',
      () => expect(() => plugin.error('error message'), returnsNormally),
    );

    test('log accepts error and stackTrace', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      expect(
        () => plugin.log(LogLevel.error, 'message', error: error),
        returnsNormally,
      );
      expect(
        () => plugin.log(
          LogLevel.error,
          'message',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });
  });

  group('LoggingPlugin interface', () {
    test('can be implemented', () {
      final plugin = _TestLoggingPlugin();

      expect(plugin, isA<LoggingPlugin>());
      expect(plugin, isA<Plugin>());
    });

    test('convenience methods work', () {
      final plugin = _TestLoggingPlugin();

      expect(() => plugin.debug('debug'), returnsNormally);
      expect(() => plugin.info('info'), returnsNormally);
      expect(() => plugin.warning('warning'), returnsNormally);
      expect(() => plugin.error('error'), returnsNormally);
    });
  });
}

class _TestLoggingPlugin extends LoggingPlugin {
  @override
  String get id => 'test_logging';

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
