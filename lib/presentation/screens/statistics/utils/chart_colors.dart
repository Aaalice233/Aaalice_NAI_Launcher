import 'package:flutter/material.dart';

/// Chart color utilities
/// 图表配色工具
class ChartColors {
  ChartColors._();

  /// Default chart color palette
  static const List<Color> defaultPalette = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFFFFEB3B), // Yellow
  ];

  /// Heatmap gradient colors (cold to hot)
  static const List<Color> heatmapGradient = [
    Color(0xFF2196F3), // Blue (cold)
    Color(0xFF4CAF50), // Green
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red (hot)
  ];

  /// Stacked area chart colors
  static const List<Color> stackedAreaPalette = [
    Color(0xFF42A5F5), // Light Blue
    Color(0xFF66BB6A), // Light Green
    Color(0xFFFFCA28), // Amber
    Color(0xFFAB47BC), // Purple
    Color(0xFFEF5350), // Red
  ];

  /// Get color for index (cycling through palette)
  static Color getColorForIndex(int index, {List<Color>? palette}) {
    final colors = palette ?? defaultPalette;
    return colors[index % colors.length];
  }

  /// Get color with opacity for chart areas
  static Color getAreaColor(Color color, {double opacity = 0.15}) {
    return color.withOpacity(opacity);
  }

  /// Get heatmap color based on value (0.0 to 1.0)
  static Color getHeatmapColor(double value) {
    value = value.clamp(0.0, 1.0);

    if (value <= 0.25) {
      return Color.lerp(heatmapGradient[0], heatmapGradient[1], value * 4)!;
    } else if (value <= 0.5) {
      return Color.lerp(
          heatmapGradient[1], heatmapGradient[2], (value - 0.25) * 4,)!;
    } else if (value <= 0.75) {
      return Color.lerp(
          heatmapGradient[2], heatmapGradient[3], (value - 0.5) * 4,)!;
    } else {
      return Color.lerp(
          heatmapGradient[3], heatmapGradient[4], (value - 0.75) * 4,)!;
    }
  }

  /// Get contrasting text color for background
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
