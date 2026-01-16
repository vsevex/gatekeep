import 'package:flutter/material.dart';

/// Responsive layout utilities for mobile devices
/// Handles different screen sizes and orientations on iOS and Android
class ResponsiveLayout {
  const ResponsiveLayout._();

  /// Breakpoints for mobile devices
  static const double smallPhone = 360.0; // Small phones
  static const double mediumPhone = 414.0; // Medium phones (iPhone Pro Max)
  static const double largePhone = 480.0; // Large phones
  static const double smallTablet = 600.0; // Small tablets (7")
  static const double mediumTablet = 768.0; // Medium tablets (10")
  static const double largeTablet = 1024.0; // Large tablets (12")

  /// Check if device is a phone
  static bool isPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < smallTablet;
  }

  /// Check if device is a tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= smallTablet;
  }

  /// Check if device is a small phone
  static bool isSmallPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < smallPhone;
  }

  /// Check if device is a large phone
  static bool isLargePhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mediumPhone && width < smallTablet;
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Get responsive value based on device type
  static T responsiveValue<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? smallPhone,
    T? largePhone,
    T? landscape,
    T? portrait,
  }) {
    // Orientation-specific values take precedence
    if (isLandscape(context) && landscape != null) {
      return landscape;
    }
    if (isPortrait(context) && portrait != null) {
      return portrait;
    }

    // Device size-specific values
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    if (isSmallPhone(context) && smallPhone != null) {
      return smallPhone;
    }
    if (isLargePhone(context) && largePhone != null) {
      return largePhone;
    }

    return phone;
  }

  /// Get responsive padding
  static EdgeInsets responsivePadding(
    BuildContext context, {
    EdgeInsets? phone,
    EdgeInsets? tablet,
    EdgeInsets? smallPhone,
    EdgeInsets? landscape,
  }) => EdgeInsets.fromLTRB(
    responsiveValue(
      context,
      phone: phone?.left ?? 16.0,
      tablet: tablet?.left,
      smallPhone: smallPhone?.left,
      landscape: landscape?.left,
    ),
    responsiveValue(
      context,
      phone: phone?.top ?? 16.0,
      tablet: tablet?.top,
      smallPhone: smallPhone?.top,
      landscape: landscape?.top,
    ),
    responsiveValue(
      context,
      phone: phone?.right ?? 16.0,
      tablet: tablet?.right,
      smallPhone: smallPhone?.right,
      landscape: landscape?.right,
    ),
    responsiveValue(
      context,
      phone: phone?.bottom ?? 16.0,
      tablet: tablet?.bottom,
      smallPhone: smallPhone?.bottom,
      landscape: landscape?.bottom,
    ),
  );

  /// Get responsive spacing
  static double responsiveSpacing(
    BuildContext context, {
    double phone = 16.0,
    double? tablet,
    double? smallPhone,
    double? landscape,
  }) => responsiveValue(
    context,
    phone: phone,
    tablet: tablet ?? phone * 1.5,
    smallPhone: smallPhone ?? phone * 0.75,
    landscape: landscape ?? phone * 0.8,
  );

  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context, {
    required double phone,
    double? tablet,
    double? smallPhone,
    double? landscape,
  }) => responsiveValue(
    context,
    phone: phone,
    tablet: tablet ?? phone * 1.2,
    smallPhone: smallPhone ?? phone * 0.9,
    landscape: landscape ?? phone * 0.95,
  );

  /// Get responsive width percentage
  static double responsiveWidth(
    BuildContext context, {
    double phone = 1.0,
    double? tablet,
    double? landscape,
  }) {
    final width = MediaQuery.of(context).size.width;
    final percentage = responsiveValue(
      context,
      phone: phone,
      tablet: tablet ?? phone,
      landscape: landscape ?? phone,
    );

    return width * percentage;
  }

  /// Get responsive max width
  static double responsiveMaxWidth(
    BuildContext context, {
    double? phone,
    double? tablet,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return phone ?? width;
  }

  /// Get number of columns for grid layout
  static int responsiveColumns(
    BuildContext context, {
    int phone = 1,
    int? tablet,
    int? landscape,
  }) => responsiveValue(
    context,
    phone: phone,
    tablet: tablet ?? 2,
    landscape: landscape ?? (isTablet(context) ? 2 : 1),
  );

  /// Check if device has safe area insets (notch, etc.)
  static bool hasSafeArea(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return padding.top > 0 || padding.bottom > 0;
  }

  /// Get safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) =>
      MediaQuery.of(context).padding;
}
