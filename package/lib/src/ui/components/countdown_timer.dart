import 'dart:async';

import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';

/// Widget displaying a countdown timer
class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({
    this.duration,
    this.targetTime,
    this.textStyle,
    this.showHours = false,
    this.showMinutes = true,
    this.showSeconds = true,
    this.onComplete,
    this.customFormat,
    this.theme,
    super.key,
  }) : assert(
         duration != null || targetTime != null,
         'Either duration or targetTime must be provided',
       );

  final Duration? duration;
  final DateTime? targetTime;
  final TextStyle? textStyle;
  final bool showHours;
  final bool showMinutes;
  final bool showSeconds;
  final VoidCallback? onComplete;
  final String? customFormat;
  final GatekeepThemeData? theme;

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.targetTime != widget.targetTime) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    if (widget.targetTime != null) {
      final now = DateTime.now();
      final difference = widget.targetTime!.difference(now);
      _remaining = difference.isNegative ? Duration.zero : difference;
    } else if (widget.duration != null) {
      _remaining = widget.duration!;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (widget.targetTime != null) {
            final now = DateTime.now();
            final difference = widget.targetTime!.difference(now);
            _remaining = difference.isNegative ? Duration.zero : difference;
          } else {
            _remaining = Duration(seconds: _remaining.inSeconds - 1);
          }

          if (_remaining.inSeconds <= 0) {
            timer.cancel();
            widget.onComplete?.call();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        widget.theme ??
        GatekeepThemeProvider.of(context) ??
        GatekeepThemes.light;

    if (widget.customFormat != null) {
      return Text(
        _formatCustom(_remaining, widget.customFormat!),
        style:
            widget.textStyle ??
            effectiveTheme.bodyStyle ??
            const TextStyle(fontSize: 16),
      );
    }

    final parts = <String>[];

    if (widget.showHours && _remaining.inHours > 0) {
      parts.add('${_remaining.inHours.toString().padLeft(2, '0')}h');
    }
    if (widget.showMinutes) {
      parts.add(
        '${_remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}m',
      );
    }
    if (widget.showSeconds) {
      parts.add(
        '${_remaining.inSeconds.remainder(60).toString().padLeft(2, '0')}s',
      );
    }

    if (parts.isEmpty) {
      parts.add('0s');
    }

    return Text(
      parts.join(' '),
      style:
          widget.textStyle ??
          effectiveTheme.bodyStyle ??
          const TextStyle(fontSize: 16),
    );
  }

  String _formatCustom(Duration duration, String format) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return format
        .replaceAll('HH', hours.toString().padLeft(2, '0'))
        .replaceAll('mm', minutes.toString().padLeft(2, '0'))
        .replaceAll('ss', seconds.toString().padLeft(2, '0'))
        .replaceAll('H', hours.toString())
        .replaceAll('m', minutes.toString())
        .replaceAll('s', seconds.toString());
  }
}
