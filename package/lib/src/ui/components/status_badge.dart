import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';
import '../../models/queue_state.dart';

/// Badge style options
enum BadgeStyle { filled, outlined, minimal }

/// Widget displaying queue status as a badge
class StatusBadgeWidget extends StatelessWidget {
  const StatusBadgeWidget({
    required this.state,
    this.theme,
    this.customText,
    this.customIcon,
    this.style = BadgeStyle.filled,
    super.key,
  });

  final QueueState state;
  final GatekeepThemeData? theme;
  final String? customText;
  final IconData? customIcon;
  final BadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        theme ?? GatekeepThemeProvider.of(context) ?? GatekeepThemes.light;

    final color = _getColorForState(state, effectiveTheme);
    final text = customText ?? state.displayName;
    final icon = customIcon ?? _getIconForState(state);

    switch (style) {
      case BadgeStyle.filled:
        return _buildFilledBadge(context, effectiveTheme, color, text, icon);
      case BadgeStyle.outlined:
        return _buildOutlinedBadge(context, effectiveTheme, color, text, icon);
      case BadgeStyle.minimal:
        return _buildMinimalBadge(context, effectiveTheme, color, text, icon);
    }
  }

  Widget _buildFilledBadge(
    BuildContext context,
    GatekeepThemeData theme,
    Color color,
    String text,
    IconData? icon,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(theme.borderRadius),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildOutlinedBadge(
    BuildContext context,
    GatekeepThemeData theme,
    Color color,
    String text,
    IconData? icon,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(theme.borderRadius),
      border: Border.all(color: color, width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildMinimalBadge(
    BuildContext context,
    GatekeepThemeData theme,
    Color color,
    String text,
    IconData? icon,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
      ],
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Color _getColorForState(QueueState state, GatekeepThemeData theme) {
    switch (state) {
      case QueueState.joining:
        return theme.warningColor;
      case QueueState.waiting:
        return theme.primaryColor;
      case QueueState.admitted:
        return theme.successColor;
      case QueueState.expired:
        return theme.errorColor;
      case QueueState.error:
        return theme.errorColor;
    }
  }

  IconData? _getIconForState(QueueState state) {
    switch (state) {
      case QueueState.joining:
        return Icons.hourglass_empty;
      case QueueState.waiting:
        return Icons.access_time;
      case QueueState.admitted:
        return Icons.check_circle;
      case QueueState.expired:
        return Icons.error_outline;
      case QueueState.error:
        return Icons.error;
    }
  }
}
