import 'package:flutter/material.dart';

/// Chart color utilities
/// Enhanced with modern gradient colors and improved palettes
class ChartColors {
  ChartColors._();

  /// Default chart color palette - Modern vibrant colors
  static const List<Color> defaultPalette = [
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  /// Heatmap gradient colors - Smooth modern transition
  static const List<Color> heatmapGradient = [
    Color(0xFF6366F1), // Indigo (cold)
    Color(0xFF10B981), // Emerald
    Color(0xFFFBBF24), // Yellow
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red (hot)
  ];

  /// Stacked area chart colors - Soft harmonious palette
  static const List<Color> stackedAreaPalette = [
    Color(0xFF60A5FA), // Light Blue
    Color(0xFF34D399), // Light Green
    Color(0xFFFCD34D), // Yellow
    Color(0xFFA78BFA), // Light Purple
    Color(0xFFF87171), // Light Red
  ];

  /// Dark mode optimized palette
  static const List<Color> darkModePalette = [
    Color(0xFF34D399), // Emerald light
    Color(0xFF60A5FA), // Blue light
    Color(0xFFFCD34D), // Amber light
    Color(0xFFA78BFA), // Purple light
    Color(0xFFF87171), // Red light
    Color(0xFF22D3EE), // Cyan light
    Color(0xFFFB923C), // Orange light
    Color(0xFF818CF8), // Indigo light
    Color(0xFFF472B6), // Pink light
    Color(0xFF2DD4BF), // Teal light
  ];

  /// Get color for index (cycling through palette)
  static Color getColorForIndex(
    int index, {
    List<Color>? palette,
    bool isDarkMode = false,
  }) {
    final colors = palette ?? (isDarkMode ? darkModePalette : defaultPalette);
    return colors[index % colors.length];
  }

  /// Get color with opacity for chart areas
  static Color getAreaColor(
    Color color, {
    double opacity = 0.15,
    bool isDarkMode = false,
  }) {
    return color.withOpacity(isDarkMode ? opacity * 1.3 : opacity);
  }

  /// Get heatmap color based on value (0.0 to 1.0)
  /// Enhanced with smoother gradient transitions
  static Color getHeatmapColor(double value, {bool isDarkMode = false}) {
    value = value.clamp(0.0, 1.0);

    // Use Bezier-like interpolation for smoother transitions
    Color interpolate(Color a, Color b, double t) {
      // Use smooth step for better visual transition
      t = t * t * (3.0 - 2.0 * t);
      return Color.lerp(a, b, t)!;
    }

    const colors = heatmapGradient;
    if (value <= 0.25) {
      return interpolate(colors[0], colors[1], value * 4);
    } else if (value <= 0.5) {
      return interpolate(colors[1], colors[2], (value - 0.25) * 4);
    } else if (value <= 0.75) {
      return interpolate(colors[2], colors[3], (value - 0.5) * 4);
    } else {
      return interpolate(colors[3], colors[4], (value - 0.75) * 4);
    }
  }

  /// Get contrasting text color for background
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF1F2937) : Colors.white;
  }

  /// Get gradient for charts
  static LinearGradient getChartGradient(
    Color color, {
    bool vertical = true,
    double startOpacity = 0.4,
    double endOpacity = 0.0,
  }) {
    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [
        color.withOpacity(startOpacity),
        color.withOpacity(endOpacity),
      ],
    );
  }

  /// Get themed color that adapts to light/dark mode
  static Color getThemedColor(
    Color lightColor,
    Color darkColor,
    bool isDarkMode,
  ) {
    return isDarkMode ? darkColor : lightColor;
  }
}
