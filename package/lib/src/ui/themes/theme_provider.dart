import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'gatekeep_theme.dart';

/// Theme provider for managing Gatekeep themes
class GatekeepThemeProvider extends ChangeNotifier {
  GatekeepThemeProvider({GatekeepThemeData? initialTheme})
    : _theme = initialTheme ?? GatekeepThemes.light {
    _isDark = _theme.isDark;
  }

  GatekeepThemeData _theme;
  bool _isDark = false;

  GatekeepThemeData get theme => _theme;
  bool get isDark => _isDark;

  void setTheme(GatekeepThemeData theme) {
    _theme = theme;
    _isDark = theme.isDark;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDark = !_isDark;
    _theme = _isDark ? GatekeepThemes.dark : GatekeepThemes.light;
    notifyListeners();
  }

  /// Get theme from context
  static GatekeepThemeData? of(BuildContext context) {
    try {
      final provider = context.read<GatekeepThemeProvider>();
      return provider.theme;
    } catch (_) {
      return null;
    }
  }

  /// Watch theme from context
  static GatekeepThemeData watch(BuildContext context) =>
      context.watch<GatekeepThemeProvider>().theme;
}
