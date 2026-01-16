import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';
import '../utils/responsive_layout.dart';

/// Progress indicator for queue position
enum ProgressIndicatorStyle { linear, circular }

/// Widget displaying queue progress
class QueueProgressIndicator extends StatefulWidget {
  const QueueProgressIndicator({
    required this.currentPosition,
    this.initialPosition,
    this.targetPosition,
    this.theme,
    this.style = ProgressIndicatorStyle.linear,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showPercentage = false,
    super.key,
  });

  final int currentPosition;
  final int? initialPosition;
  final int? targetPosition;
  final GatekeepThemeData? theme;
  final ProgressIndicatorStyle style;
  final Duration animationDuration;
  final bool showPercentage;

  @override
  State<QueueProgressIndicator> createState() => _QueueProgressIndicatorState();
}

class _QueueProgressIndicatorState extends State<QueueProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _updateProgress();
  }

  @override
  void didUpdateWidget(QueueProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.initialPosition != widget.initialPosition ||
        oldWidget.targetPosition != widget.targetPosition) {
      _previousProgress = _calculateProgress();
      _updateProgress();
    }
  }

  void _updateProgress() {
    final newProgress = _calculateProgress();
    _animation = Tween<double>(
      begin: _previousProgress,
      end: newProgress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward(from: 0.0);
  }

  double _calculateProgress() {
    if (widget.initialPosition == null || widget.targetPosition == null) {
      return 0.0;
    }

    final initial = widget.initialPosition!;
    final target = widget.targetPosition!;
    final current = widget.currentPosition;

    if (initial == target) {
      return 1.0;
    }

    final progress = 1.0 - ((current - target) / (initial - target));
    return progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        widget.theme ??
        GatekeepThemeProvider.of(context) ??
        GatekeepThemes.light;

    switch (widget.style) {
      case ProgressIndicatorStyle.linear:
        return _buildLinearProgress(effectiveTheme);
      case ProgressIndicatorStyle.circular:
        return _buildCircularProgress(effectiveTheme);
    }
  }

  Widget _buildLinearProgress(GatekeepThemeData theme) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final minHeight = ResponsiveLayout.responsiveValue(
          context,
          phone: 8.0,
          tablet: 10.0,
          landscape: 6.0,
        );
        final fontSize = ResponsiveLayout.responsiveFontSize(
          context,
          phone: 12,
          tablet: 14,
          landscape: 11,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.borderRadius),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.surfaceColor,
                valueColor: AlwaysStoppedAnimation<Color>(theme.progressColor),
                minHeight: minHeight,
              ),
            ),
            if (widget.showPercentage) ...[
              SizedBox(
                height: ResponsiveLayout.responsiveSpacing(
                  context,
                  phone: 8,
                  tablet: 10,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style:
                    theme.captionStyle?.copyWith(fontSize: fontSize) ??
                    TextStyle(
                      fontSize: fontSize,
                      color: theme.textSecondaryColor,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCircularProgress(GatekeepThemeData theme) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) {
      final progress = _animation.value;
      final size = ResponsiveLayout.responsiveValue(
        context,
        phone: 80.0,
        tablet: 100.0,
        landscape: 70.0,
      );
      final strokeWidth = ResponsiveLayout.responsiveValue(
        context,
        phone: 6.0,
        tablet: 8.0,
        landscape: 5.0,
      );
      final fontSize = ResponsiveLayout.responsiveFontSize(
        context,
        phone: 14,
        tablet: 16,
        landscape: 12,
      );

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              backgroundColor: theme.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.progressColor),
              strokeWidth: strokeWidth,
            ),
            if (widget.showPercentage)
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style:
                    theme.captionStyle?.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ) ??
                    TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
              ),
          ],
        ),
      );
    },
  );
}
