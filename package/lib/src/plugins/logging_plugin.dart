import 'package:flutter/foundation.dart';

import 'plugin_interface.dart';

/// Log level for logging plugin
enum LogLevel { debug, info, warning, error }

/// Plugin for logging
abstract class LoggingPlugin extends Plugin {
  /// Log a message
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });

  /// Log debug message
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }
}

/// Default console logging plugin
class ConsoleLoggingPlugin extends LoggingPlugin {
  ConsoleLoggingPlugin({this.minLevel = LogLevel.info});

  final LogLevel minLevel;

  @override
  String get id => 'console_logging';

  @override
  String get name => 'Console Logging';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {
    // No-op
  }

  @override
  Future<void> dispose() async {
    // No-op
  }

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) {
      return;
    }

    final prefix = '[${level.name.toUpperCase()}]';
    if (kDebugMode) {
      print('$prefix $message');
    }

    if (error != null) {
      if (kDebugMode) {
        print('Error: $error');
      }
    }

    if (stackTrace != null) {
      if (kDebugMode) {
        print('StackTrace: $stackTrace');
      }
    }
  }
}
