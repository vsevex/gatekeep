import 'package:flutter/material.dart';

import '../themes/gatekeep_theme.dart';
import 'waiting_room_config.dart';

/// Configuration for UI customization
class CustomizationConfig {
  const CustomizationConfig({
    this.theme,
    this.waitingRoomConfig,
    this.customWidgets,
    this.customTexts,
    this.customImages,
    this.customTextStyles,
  });

  /// Custom theme
  final GatekeepThemeData? theme;

  /// Waiting room configuration
  final WaitingRoomConfig? waitingRoomConfig;

  /// Custom widget builders
  final Map<String, WidgetBuilder>? customWidgets;

  /// Custom text overrides
  final Map<String, String>? customTexts;

  /// Custom images
  final Map<String, AssetImage>? customImages;

  /// Custom text styles
  final Map<String, TextStyle>? customTextStyles;

  /// Create a copy with updated fields
  CustomizationConfig copyWith({
    GatekeepThemeData? theme,
    WaitingRoomConfig? waitingRoomConfig,
    Map<String, WidgetBuilder>? customWidgets,
    Map<String, String>? customTexts,
    Map<String, AssetImage>? customImages,
    Map<String, TextStyle>? customTextStyles,
  }) => CustomizationConfig(
    theme: theme ?? this.theme,
    waitingRoomConfig: waitingRoomConfig ?? this.waitingRoomConfig,
    customWidgets: customWidgets ?? this.customWidgets,
    customTexts: customTexts ?? this.customTexts,
    customImages: customImages ?? this.customImages,
    customTextStyles: customTextStyles ?? this.customTextStyles,
  );
}

/// Style provider for accessing customization config
class StyleProvider extends InheritedWidget {
  const StyleProvider({required this.config, required super.child, super.key});

  final CustomizationConfig config;

  static CustomizationConfig? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StyleProvider>()?.config;
  }

  @override
  bool updateShouldNotify(StyleProvider oldWidget) =>
      config != oldWidget.config;
}
