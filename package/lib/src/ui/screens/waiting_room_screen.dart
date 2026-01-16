import 'dart:async';

import 'package:flutter/material.dart';

import '../../client/queue_client_interface.dart';
import '../utils/platform_check.dart';
import '../utils/responsive_layout.dart';
import '../../models/queue_status.dart';
import '../../models/admission_token.dart';
import '../../models/queue_state.dart';
import '../../errors/queue_exception.dart';
import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';
import '../localization/gatekeep_localizations.dart';
import '../components/queue_position_widget.dart';
import '../components/progress_indicator.dart';
import '../components/countdown_timer.dart';
import '../components/status_badge.dart';
import '../components/error_display.dart';
import '../customization/waiting_room_config.dart';

/// Main waiting room screen widget
class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    required this.queueClient,
    required this.eventId,
    this.queueId,
    this.theme,
    this.config,
    this.customHeader,
    this.customFooter,
    this.customBackground,
    this.onAdmitted,
    this.onError,
    this.onCancel,
    this.priorityBucket,
    this.metadata,
    super.key,
  });

  /// Queue client instance
  final QueueClientInterface queueClient;

  /// Event ID to join
  final String eventId;

  /// Optional queue ID if already joined
  final String? queueId;

  /// Custom theme
  final GatekeepThemeData? theme;

  /// Waiting room configuration
  final WaitingRoomConfig? config;

  /// Custom header widget
  final Widget? customHeader;

  /// Custom footer widget
  final Widget? customFooter;

  /// Custom background widget
  final Widget? customBackground;

  /// Callback when user is admitted
  final Function(AdmissionToken)? onAdmitted;

  /// Callback when error occurs
  final Function(QueueException)? onError;

  /// Callback when user cancels
  final VoidCallback? onCancel;

  /// Priority bucket for joining
  final String? priorityBucket;

  /// Metadata for joining
  final Map<String, dynamic>? metadata;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  QueueStatus? _status;
  QueueState _currentState = QueueState.joining;
  StreamSubscription<QueueStatus>? _statusSubscription;
  Timer? _heartbeatTimer;
  bool _isInitializing = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Assert mobile platform
    PlatformCheck.assertMobile();
    _initializeQueue();
  }

  Future<void> _initializeQueue() async {
    try {
      setState(() {
        _isInitializing = true;
        _error = null;
      });

      QueueStatus status;

      if (widget.queueId != null) {
        // Already have a queue ID, get status
        status = await widget.queueClient.getStatus(queueId: widget.queueId!);
      } else {
        // Join the queue
        status = await widget.queueClient.joinEvent(
          eventId: widget.eventId,
          priorityBucket: widget.priorityBucket,
          metadata: widget.metadata,
        );
      }

      if (mounted) {
        setState(() {
          _status = status;
          _currentState = status.state;
          _isInitializing = false;
        });

        _startStatusPolling();
        _startHeartbeat();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _currentState = QueueState.error;
          _isInitializing = false;
        });
        _handleError(e);
      }
    }
  }

  void _startStatusPolling() {
    if (_status == null) {
      return;
    }

    final config = widget.config ?? const WaitingRoomConfig();
    final pollInterval = config.pollInterval;

    _statusSubscription = widget.queueClient
        .listenStatus(queueId: _status!.queueId, pollInterval: pollInterval)
        .listen(
          (status) {
            if (mounted) {
              setState(() {
                _status = status;
                _currentState = status.state;
                _error = null;
              });

              if (status.state == QueueState.admitted &&
                  status.admissionToken != null) {
                widget.onAdmitted?.call(status.admissionToken!);
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = error;
                _currentState = QueueState.error;
              });
              _handleError(error);
            }
          },
        );
  }

  void _startHeartbeat() {
    if (_status == null) {
      return;
    }

    final config = widget.config ?? const WaitingRoomConfig();
    if (!config.autoHeartbeat) {
      return;
    }

    final interval = config.heartbeatInterval ?? const Duration(seconds: 30);

    _heartbeatTimer = Timer.periodic(interval, (timer) async {
      if (!mounted || _status == null) {
        timer.cancel();
        return;
      }

      try {
        final status = await widget.queueClient.sendHeartbeat(
          queueId: _status!.queueId,
        );

        if (mounted) {
          setState(() {
            _status = status;
            _currentState = status.state;

            if (status.state == QueueState.admitted &&
                status.admissionToken != null) {
              widget.onAdmitted?.call(status.admissionToken!);
              timer.cancel();
            }
          });
        }
      } catch (e) {
        // Log error but don't cancel timer - will retry on next interval
        if (mounted) {
          setState(() => _error = e);
        }
      }
    });
  }

  void _handleError(Object error) {
    if (error is QueueException) {
      widget.onError?.call(error);
    }
  }

  void _handleCancel() {
    _statusSubscription?.cancel();
    _heartbeatTimer?.cancel();
    widget.onCancel?.call();
  }

  void _handleRetry() => _initializeQueue();

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        widget.theme ??
        GatekeepThemeProvider.of(context) ??
        GatekeepThemes.light;

    return Theme(
      data: GatekeepThemeBuilder.buildTheme(
        effectiveTheme,
        effectiveTheme.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(body: _buildBody(effectiveTheme)),
    );
  }

  Widget _buildBody(GatekeepThemeData theme) => Stack(
    children: [
      if (widget.customBackground != null)
        widget.customBackground!
      else
        _buildDefaultBackground(theme),
      SafeArea(
        child: Column(
          children: [
            if (widget.customHeader != null)
              widget.customHeader!
            else
              _buildDefaultHeader(theme),
            Expanded(child: _buildStateContent(theme)),
            if (widget.customFooter != null)
              widget.customFooter!
            else
              _buildDefaultFooter(theme),
          ],
        ),
      ),
    ],
  );

  Widget _buildDefaultBackground(GatekeepThemeData theme) {
    if (theme.backgroundGradient != null) {
      return Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
      );
    }

    return Container(color: theme.backgroundColor);
  }

  Widget _buildDefaultHeader(GatekeepThemeData theme) {
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    final spacing = ResponsiveLayout.responsiveSpacing(
      context,
      phone: theme.spacing,
      tablet: theme.spacing * 1.5,
      landscape: theme.spacing * 0.8,
    );

    final fontSize = ResponsiveLayout.responsiveFontSize(
      context,
      phone: 24,
      tablet: 28,
      smallPhone: 20,
      landscape: 22,
    );

    return Padding(
      padding: ResponsiveLayout.responsivePadding(
        context,
        phone: EdgeInsets.all(spacing),
        tablet: EdgeInsets.all(spacing),
        landscape: EdgeInsets.symmetric(
          horizontal: spacing,
          vertical: spacing * 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              localizations.queueTitle,
              style:
                  theme.headingStyle?.copyWith(fontSize: fontSize) ??
                  TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.config?.allowCancel ?? true)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _handleCancel,
              tooltip: localizations.cancel,
            ),
        ],
      ),
    );
  }

  Widget _buildStateContent(GatekeepThemeData theme) {
    if (_isInitializing) {
      return _buildJoiningState(theme);
    }

    if (_error != null && _currentState == QueueState.error) {
      return _buildErrorState(theme);
    }

    switch (_currentState) {
      case QueueState.joining:
        return _buildJoiningState(theme);
      case QueueState.waiting:
        return _buildWaitingState(theme);
      case QueueState.admitted:
        return _buildAdmittedState(theme);
      case QueueState.expired:
        return _buildExpiredState(theme);
      case QueueState.error:
        return _buildErrorState(theme);
    }
  }

  Widget _buildJoiningState(GatekeepThemeData theme) {
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.joiningQueue, style: theme.bodyStyle),
        ],
      ),
    );
  }

  Widget _buildWaitingState(GatekeepThemeData theme) {
    if (_status == null) {
      return _buildJoiningState(theme);
    }

    final config = widget.config ?? const WaitingRoomConfig();
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    final spacing = ResponsiveLayout.responsiveSpacing(
      context,
      phone: theme.spacing,
      tablet: theme.spacing * 1.5,
      landscape: theme.spacing * 0.8,
    );

    final isTablet = ResponsiveLayout.isTablet(context);
    final isLandscape = ResponsiveLayout.isLandscape(context);

    return SingleChildScrollView(
      padding: ResponsiveLayout.responsivePadding(
        context,
        phone: EdgeInsets.all(spacing),
        tablet: EdgeInsets.all(spacing),
        landscape: EdgeInsets.symmetric(
          horizontal: spacing * 2,
          vertical: spacing,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.responsiveMaxWidth(
            context,
            phone: double.infinity,
            tablet: 600,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (config.showPosition) ...[
              QueuePositionWidget(
                position: _status!.position,
                totalInQueue: _status!.totalInQueue,
                theme: theme,
              ),
              SizedBox(height: spacing * (isTablet ? 2.5 : 2)),
            ],
            if (config.showProgress && _status!.totalInQueue != null) ...[
              QueueProgressIndicator(
                currentPosition: _status!.position,
                initialPosition: _status!.totalInQueue,
                targetPosition: 0,
                theme: theme,
              ),
              SizedBox(height: spacing * (isTablet ? 2.5 : 2)),
            ],
            if (config.showETA) ...[
              StatusBadgeWidget(state: _currentState, theme: theme),
              SizedBox(height: spacing),
              CountdownTimerWidget(
                duration: _status!.estimatedWait,
                theme: theme,
              ),
              SizedBox(height: spacing),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? spacing * 2 : 0,
                ),
                child: Text(
                  localizations.formatEstimatedWait(_status!.estimatedWait),
                  style: theme.captionStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdmittedState(GatekeepThemeData theme) {
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: theme.successColor),
          SizedBox(height: theme.spacing),
          Text(
            localizations.admitted,
            style:
                theme.headingStyle?.copyWith(color: theme.successColor) ??
                TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.successColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredState(GatekeepThemeData theme) {
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: theme.errorColor),
          SizedBox(height: theme.spacing),
          Text(
            localizations.tokenExpired,
            style:
                theme.headingStyle?.copyWith(color: theme.errorColor) ??
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.errorColor,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.spacing),
          ElevatedButton(
            onPressed: _handleRetry,
            child: Text(localizations.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(GatekeepThemeData theme) => Center(
    child: Padding(
      padding: EdgeInsets.all(theme.spacing),
      child: ErrorDisplayWidget(
        error: _error ?? 'Unknown error',
        onRetry: _handleRetry,
        theme: theme,
      ),
    ),
  );

  Widget _buildDefaultFooter(GatekeepThemeData theme) {
    final config = widget.config ?? const WaitingRoomConfig();
    if (!config.showHeartbeatStatus || _status == null) {
      return const SizedBox.shrink();
    }

    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    final spacing = ResponsiveLayout.responsiveSpacing(
      context,
      phone: theme.spacing,
      tablet: theme.spacing * 1.5,
      landscape: theme.spacing * 0.5,
    );

    return Padding(
      padding: ResponsiveLayout.responsivePadding(
        context,
        phone: EdgeInsets.all(spacing),
        tablet: EdgeInsets.all(spacing),
        landscape: EdgeInsets.symmetric(
          horizontal: spacing,
          vertical: spacing * 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi,
            size: ResponsiveLayout.responsiveFontSize(
              context,
              phone: 16,
              tablet: 18,
            ),
            color: _error == null ? theme.successColor : theme.errorColor,
          ),
          SizedBox(width: spacing * 0.5),
          Flexible(
            child: Text(
              _error == null
                  ? localizations.heartbeatStatus
                  : localizations.heartbeatFailed,
              style: theme.captionStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
