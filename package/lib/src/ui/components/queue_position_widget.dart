import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';
import '../localization/gatekeep_localizations.dart';
import '../utils/responsive_layout.dart';

/// Widget displaying the user's position in the queue
class QueuePositionWidget extends StatelessWidget {
  const QueuePositionWidget({
    required this.position,
    this.totalInQueue,
    this.theme,
    this.textStyle,
    this.customIndicator,
    this.showLabel = true,
    this.customLabel,
    super.key,
  });

  final int position;
  final int? totalInQueue;
  final GatekeepThemeData? theme;
  final TextStyle? textStyle;
  final Widget? customIndicator;
  final bool showLabel;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        theme ?? GatekeepThemeProvider.of(context) ?? GatekeepThemes.light;
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Text(
            customLabel ?? localizations.positionInQueue(position),
            style:
                textStyle ??
                effectiveTheme.headingStyle ??
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        if (customIndicator != null)
          customIndicator!
        else
          _buildDefaultIndicator(context, effectiveTheme, position),
        if (totalInQueue != null) ...[
          const SizedBox(height: 4),
          Text(
            'of $totalInQueue',
            style:
                effectiveTheme.captionStyle ??
                TextStyle(
                  fontSize: 14,
                  color: effectiveTheme.textSecondaryColor,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildDefaultIndicator(
    BuildContext context,
    GatekeepThemeData theme,
    int position,
  ) {
    final fontSize = ResponsiveLayout.responsiveFontSize(
      context,
      phone: 48,
      tablet: 64,
      smallPhone: 40,
      landscape: 42,
    );

    final padding = ResponsiveLayout.responsivePadding(
      context,
      phone: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      tablet: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      smallPhone: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      landscape: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.queuePositionColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(theme.borderRadius),
        border: Border.all(
          color: theme.queuePositionColor,
          width: ResponsiveLayout.isTablet(context) ? 3 : 2,
        ),
      ),
      child: Text(
        '#$position',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: theme.queuePositionColor,
        ),
      ),
    );
  }
}
