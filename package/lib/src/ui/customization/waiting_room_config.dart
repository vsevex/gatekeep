import 'package:flutter/material.dart';

/// Configuration for the waiting room screen
class WaitingRoomConfig {
  const WaitingRoomConfig({
    this.showPosition = true,
    this.showETA = true,
    this.showProgress = true,
    this.showHeartbeatStatus = true,
    this.allowCancel = true,
    this.pollInterval,
    this.heartbeatInterval,
    this.autoHeartbeat = true,
    this.customStateBuilders,
  });

  /// Whether to show queue position
  final bool showPosition;

  /// Whether to show estimated wait time
  final bool showETA;

  /// Whether to show progress indicator
  final bool showProgress;

  /// Whether to show heartbeat status
  final bool showHeartbeatStatus;

  /// Whether to allow canceling the queue
  final bool allowCancel;

  /// Custom poll interval (uses client default if null)
  final Duration? pollInterval;

  /// Custom heartbeat interval (uses client default if null)
  final Duration? heartbeatInterval;

  /// Whether to automatically send heartbeats
  final bool autoHeartbeat;

  /// Custom widget builders for different states
  final Map<String, WidgetBuilder>? customStateBuilders;
}
