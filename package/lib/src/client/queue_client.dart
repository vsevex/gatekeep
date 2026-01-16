import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/gatekeep_config.dart';
import '../models/queue_status.dart';
import '../models/admission_token.dart';
import '../models/queue_state.dart' show QueueStateExtension;
import '../models/join_request.dart';
import '../models/heartbeat_request.dart';
import '../network/http_client_interface.dart';
import '../storage/storage_interface.dart';
import '../utils/retry_strategy.dart';
import '../errors/gatekeep_exception.dart';
import '../plugins/analytics_plugin.dart';
import '../plugins/logging_plugin.dart';
import 'queue_client_interface.dart';

/// Concrete exception for disposed client
class _DisposedException extends GatekeepException {
  const _DisposedException() : super('QueueClient has been disposed');
}

/// Main queue client implementation
class QueueClient implements QueueClientInterface {
  QueueClient(this._config)
    : _httpClient = _config.httpClient!,
      _storage = _config.storage!,
      _retryStrategy = _config.retryStrategy!,
      _queueRetryStrategy = _config.queueRetryStrategy! {
    _config.validate();
    _config.pluginRegistry?.notifyInitialized();
  }

  final GatekeepConfig _config;
  final HttpClientInterface _httpClient;
  final StorageInterface _storage;
  final RetryStrategy _retryStrategy;
  final RetryStrategy _queueRetryStrategy;

  final Map<String, StreamController<QueueStatus>> _statusControllers = {};
  final Map<String, Timer> _pollTimers = {};
  final Map<String, Timer> _heartbeatTimers = {};

  bool _disposed = false;

  @override
  Future<QueueStatus> joinEvent({
    required String eventId,
    String? priorityBucket,
    Map<String, dynamic>? metadata,
  }) async {
    _checkDisposed();

    final request = JoinRequest(
      eventId: eventId,
      deviceId: _config.deviceId,
      userId: _config.userId,
      priorityBucket: priorityBucket,
      metadata: metadata,
    );

    _log('Joining queue for event: $eventId');
    _trackEvent('queue_join', {'event_id': eventId});

    try {
      final response = await _queueRetryStrategy.execute(() async {
        return await _httpClient.post(
          '${_config.baseUrl}/queue/join',
          body: request.toJson(),
        );
      });

      final status = QueueStatus.fromJson(response.json);

      _log('Successfully joined queue: ${status.queueId}');
      _trackEvent('queue_join_success', {
        'event_id': eventId,
        'queue_id': status.queueId,
        'position': status.position,
      });

      return status;
    } catch (e) {
      _logError('Failed to join queue', e);
      _trackError('queue_join_error', e);
      rethrow;
    }
  }

  @override
  Future<QueueStatus> getStatus({required String queueId}) async {
    _checkDisposed();

    try {
      final response = await _retryStrategy.execute(() async {
        return await _httpClient.get(
          '${_config.baseUrl}/queue/status',
          queryParameters: {'queue_id': queueId},
        );
      });

      return QueueStatus.fromJson(response.json);
    } catch (e) {
      _logError('Failed to get queue status', e);
      rethrow;
    }
  }

  @override
  Future<QueueStatus> sendHeartbeat({required String queueId}) async {
    _checkDisposed();

    final request = HeartbeatRequest(queueId: queueId);

    try {
      final response = await _retryStrategy.execute(() async {
        return await _httpClient.post(
          '${_config.baseUrl}/queue/heartbeat',
          body: request.toJson(),
        );
      });

      final status = QueueStatus.fromJson(response.json);

      // If admitted, save token
      if (status.isAdmitted && status.admissionToken != null) {
        await saveToken(
          eventId: status.admissionToken!.eventId,
          token: status.admissionToken!,
        );

        _trackEvent('admission_granted', {
          'queue_id': queueId,
          'event_id': status.admissionToken!.eventId,
        });
      }

      return status;
    } catch (e) {
      _logError('Failed to send heartbeat', e);
      rethrow;
    }
  }

  @override
  Stream<QueueStatus> listenStatus({
    required String queueId,
    Duration? pollInterval,
  }) {
    _checkDisposed();

    final interval = pollInterval ?? _config.pollInterval;

    // Return existing stream if available
    if (_statusControllers.containsKey(queueId)) {
      return _statusControllers[queueId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<QueueStatus>.broadcast();
    _statusControllers[queueId] = controller;

    // Start polling
    _startPolling(queueId, interval, controller);

    // Start heartbeat if enabled
    if (_config.autoHeartbeat) {
      _startHeartbeat(queueId);
    }

    return controller.stream;
  }

  void _startPolling(
    String queueId,
    Duration interval,
    StreamController<QueueStatus> controller,
  ) {
    // Get initial status
    getStatus(queueId: queueId)
        .then((status) {
          if (!controller.isClosed) {
            controller.add(status);
          }
        })
        .catchError((e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        });

    // Schedule periodic polling
    _pollTimers[queueId] = Timer.periodic(interval, (timer) async {
      if (_disposed || controller.isClosed) {
        timer.cancel();
        return;
      }

      try {
        final status = await getStatus(queueId: queueId);

        if (!controller.isClosed) {
          controller.add(status);

          // Track position updates
          _trackPosition(queueId, status.position);
        }

        // Stop polling if terminal state
        final stateExtension = status.state;
        if (stateExtension.isTerminal) {
          timer.cancel();
          _pollTimers.remove(queueId);

          if (status.isAdmitted) {
            controller.close();
            _statusControllers.remove(queueId);
          }
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    });
  }

  void _startHeartbeat(String queueId) {
    _heartbeatTimers[queueId] = Timer.periodic(_config.heartbeatInterval, (
      timer,
    ) async {
      if (_disposed) {
        timer.cancel();
        return;
      }

      try {
        await sendHeartbeat(queueId: queueId);
      } catch (e) {
        _logError('Heartbeat failed', e);
        // Don't cancel timer, will retry on next interval
      }
    });
  }

  @override
  Future<AdmissionToken?> restoreToken({required String eventId}) async {
    _checkDisposed();

    try {
      final tokenJson = await _storage.read('token_$eventId');
      if (tokenJson == null) {
        return null;
      }

      final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
      final token = AdmissionToken.fromJson(tokenData);

      // Check if token is still valid
      if (!token.isValid()) {
        _storage.delete('token_$eventId');
        return null;
      }

      return token;
    } catch (e) {
      _logError('Failed to restore token', e);
      return null;
    }
  }

  @override
  Future<void> saveToken({
    required String eventId,
    required AdmissionToken token,
  }) async {
    _checkDisposed();

    try {
      final tokenJson = jsonEncode(token.toJson());
      _storage.write('token_$eventId', tokenJson);
    } catch (e) {
      _logError('Failed to save token', e);
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    // Cancel all timers
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();

    for (final timer in _heartbeatTimers.values) {
      timer.cancel();
    }
    _heartbeatTimers.clear();

    // Close all stream controllers
    for (final controller in _statusControllers.values) {
      controller.close();
    }
    _statusControllers.clear();

    // Close HTTP client
    _httpClient.close();

    // Notify plugins
    _config.pluginRegistry?.notifyDisposed();
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const _DisposedException();
    }
  }

  void _log(String message) {
    if (_config.debug) {
      final loggingPlugins =
          _config.pluginRegistry?.getPlugins<LoggingPlugin>() ?? [];
      if (loggingPlugins.isEmpty) {
        if (kDebugMode) {
          print('[Gatekeep] $message');
        }
      } else {
        for (final plugin in loggingPlugins) {
          plugin.info(message);
        }
      }
    }
  }

  void _logError(String message, Object error) {
    final loggingPlugins =
        _config.pluginRegistry?.getPlugins<LoggingPlugin>() ?? [];
    if (loggingPlugins.isEmpty) {
      if (kDebugMode) {
        print('[Gatekeep ERROR] $message: $error');
      }
    } else {
      for (final plugin in loggingPlugins) {
        plugin.error(message, error: error);
      }
    }
  }

  void _trackEvent(String eventName, Map<String, dynamic> properties) {
    final analyticsPlugins =
        _config.pluginRegistry?.getPlugins<AnalyticsPlugin>() ?? [];
    for (final plugin in analyticsPlugins) {
      plugin.trackEvent(eventName, properties: properties);
    }
  }

  void _trackPosition(String queueId, int position) {
    final analyticsPlugins =
        _config.pluginRegistry?.getPlugins<AnalyticsPlugin>() ?? [];
    for (final plugin in analyticsPlugins) {
      plugin.trackQueuePosition(queueId, position);
    }
  }

  void _trackError(String errorType, Object error) {
    final analyticsPlugins =
        _config.pluginRegistry?.getPlugins<AnalyticsPlugin>() ?? [];
    for (final plugin in analyticsPlugins) {
      plugin.trackError(errorType, error.toString());
    }
  }
}
