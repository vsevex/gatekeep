import 'package:flutter/material.dart';

/// Theme data for Gatekeep UI components
class GatekeepThemeData {
  const GatekeepThemeData({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.errorColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.queuePositionColor,
    required this.progressColor,
    required this.successColor,
    required this.warningColor,
    this.headingStyle,
    this.bodyStyle,
    this.captionStyle,
    this.borderRadius = 8.0,
    this.spacing = 16.0,
    this.cardShadow,
    this.backgroundGradient,
    this.backgroundImage,
    this.logoImage,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color errorColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color queuePositionColor;
  final Color progressColor;
  final Color successColor;
  final Color warningColor;

  final TextStyle? headingStyle;
  final TextStyle? bodyStyle;
  final TextStyle? captionStyle;

  final double borderRadius;
  final double spacing;

  final BoxShadow? cardShadow;
  final Gradient? backgroundGradient;
  final String? backgroundImage;
  final String? logoImage;

  /// Create a copy with updated fields
  GatekeepThemeData copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? errorColor,
    Color? textColor,
    Color? textSecondaryColor,
    Color? queuePositionColor,
    Color? progressColor,
    Color? successColor,
    Color? warningColor,
    TextStyle? headingStyle,
    TextStyle? bodyStyle,
    TextStyle? captionStyle,
    double? borderRadius,
    double? spacing,
    BoxShadow? cardShadow,
    Gradient? backgroundGradient,
    String? backgroundImage,
    String? logoImage,
  }) {
    return GatekeepThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      errorColor: errorColor ?? this.errorColor,
      textColor: textColor ?? this.textColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      queuePositionColor: queuePositionColor ?? this.queuePositionColor,
      progressColor: progressColor ?? this.progressColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      headingStyle: headingStyle ?? this.headingStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      captionStyle: captionStyle ?? this.captionStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      spacing: spacing ?? this.spacing,
      cardShadow: cardShadow ?? this.cardShadow,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      logoImage: logoImage ?? this.logoImage,
    );
  }

  /// Create light theme
  static GatekeepThemeData light() {
    return GatekeepThemeData(
      primaryColor: Colors.blue,
      secondaryColor: Colors.blueAccent,
      backgroundColor: Colors.white,
      surfaceColor: Colors.grey[100]!,
      errorColor: Colors.red,
      textColor: Colors.black87,
      textSecondaryColor: Colors.black54,
      queuePositionColor: Colors.blue,
      progressColor: Colors.blue,
      successColor: Colors.green,
      warningColor: Colors.orange,
      headingStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      bodyStyle: const TextStyle(fontSize: 16, color: Colors.black87),
      cardShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    );
  }

  /// Create dark theme
  static GatekeepThemeData dark() => GatekeepThemeData(
    primaryColor: Colors.blue[300]!,
    secondaryColor: Colors.blueAccent[200]!,
    backgroundColor: Colors.grey[900]!,
    surfaceColor: Colors.grey[800]!,
    errorColor: Colors.red[300]!,
    textColor: Colors.white,
    textSecondaryColor: Colors.white70,
    queuePositionColor: Colors.blue[300]!,
    progressColor: Colors.blue[300]!,
    successColor: Colors.green[300]!,
    warningColor: Colors.orange[300]!,
    headingStyle: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    bodyStyle: const TextStyle(fontSize: 16, color: Colors.white),
    captionStyle: const TextStyle(fontSize: 14, color: Colors.white70),
    cardShadow: BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  );

  /// Check if theme is dark
  bool get isDark => backgroundColor.computeLuminance() < 0.5;
}

/// Predefined themes
class GatekeepThemes {
  const GatekeepThemes._();

  static final GatekeepThemeData light = GatekeepThemeData.light();
  static final GatekeepThemeData dark = GatekeepThemeData.dark();
}

/// Theme extension for Flutter's ThemeData
class GatekeepThemeExtension extends ThemeExtension<GatekeepThemeExtension> {
  const GatekeepThemeExtension({
    required this.queuePositionColor,
    required this.progressColor,
    this.backgroundGradient,
    this.backgroundImage,
  });

  final Color queuePositionColor;
  final Color progressColor;
  final Gradient? backgroundGradient;
  final String? backgroundImage;

  @override
  ThemeExtension<GatekeepThemeExtension> copyWith({
    Color? queuePositionColor,
    Color? progressColor,
    Gradient? backgroundGradient,
    String? backgroundImage,
  }) => GatekeepThemeExtension(
    queuePositionColor: queuePositionColor ?? this.queuePositionColor,
    progressColor: progressColor ?? this.progressColor,
    backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    backgroundImage: backgroundImage ?? this.backgroundImage,
  );

  @override
  ThemeExtension<GatekeepThemeExtension> lerp(
    ThemeExtension<GatekeepThemeExtension>? other,
    double t,
  ) {
    if (other is! GatekeepThemeExtension) {
      return this;
    }

    return GatekeepThemeExtension(
      queuePositionColor: Color.lerp(
        queuePositionColor,
        other.queuePositionColor,
        t,
      )!,
      progressColor: Color.lerp(progressColor, other.progressColor, t)!,
      backgroundGradient: t < 0.5
          ? backgroundGradient
          : other.backgroundGradient,
      backgroundImage: t < 0.5 ? backgroundImage : other.backgroundImage,
    );
  }
}

/// Theme builder utility
class GatekeepThemeBuilder {
  const GatekeepThemeBuilder._();

  static ThemeData buildTheme(
    GatekeepThemeData gatekeepTheme,
    Brightness brightness,
  ) => ThemeData(
    brightness: brightness,
    primaryColor: gatekeepTheme.primaryColor,
    scaffoldBackgroundColor: gatekeepTheme.backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gatekeepTheme.primaryColor,
      brightness: brightness,
    ),
    extensions: [
      GatekeepThemeExtension(
        queuePositionColor: gatekeepTheme.queuePositionColor,
        progressColor: gatekeepTheme.progressColor,
        backgroundGradient: gatekeepTheme.backgroundGradient,
        backgroundImage: gatekeepTheme.backgroundImage,
      ),
    ],
  );
}
