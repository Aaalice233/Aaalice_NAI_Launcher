/// Token 计数格式化工具。
library;

/// 将 token 数格式化为紧凑字符串，如 `12.3k`、`1.2m`。
String formatTokenCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final compact = value / 1000;
    return '${compact >= 100 ? compact.round() : compact.toStringAsFixed(1)}k';
  }
  final compact = value / 1000000;
  return '${compact >= 100 ? compact.round() : compact.toStringAsFixed(1)}m';
}
