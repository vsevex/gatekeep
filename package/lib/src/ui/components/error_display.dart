import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import '../themes/theme_provider.dart';
import '../localization/gatekeep_localizations.dart';
import '../../errors/gatekeep_exception.dart';

/// Widget displaying error messages
class ErrorDisplayWidget extends StatelessWidget {
  const ErrorDisplayWidget({
    required this.error,
    this.onRetry,
    this.theme,
    this.showRetryButton = true,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final GatekeepThemeData? theme;
  final bool showRetryButton;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme =
        theme ?? GatekeepThemeProvider.of(context) ?? GatekeepThemes.light;
    final localizations =
        GatekeepLocalizations.of(context) ??
        const GatekeepLocalizations(Locale('en', 'US'));

    String errorMessage = localizations.errorOccurred;
    if (error is GatekeepException) {
      errorMessage = (error as GatekeepException).message;
    } else if (error is Exception) {
      errorMessage = error.toString();
    } else {
      errorMessage = error.toString();
    }

    return Container(
      padding: EdgeInsets.all(effectiveTheme.spacing),
      decoration: BoxDecoration(
        color: effectiveTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(effectiveTheme.borderRadius),
        border: Border.all(color: effectiveTheme.errorColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: effectiveTheme.errorColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.errorOccurred,
                  style:
                      effectiveTheme.headingStyle?.copyWith(
                        color: effectiveTheme.errorColor,
                      ) ??
                      TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: effectiveTheme.errorColor,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style:
                effectiveTheme.bodyStyle?.copyWith(
                  color: effectiveTheme.textColor,
                ) ??
                TextStyle(fontSize: 14, color: effectiveTheme.textColor),
            textAlign: TextAlign.center,
          ),
          if (showRetryButton && onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: effectiveTheme.errorColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
