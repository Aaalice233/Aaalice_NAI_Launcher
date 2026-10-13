/// 提示词数值权重格式化工具。
library;

final RegExp _trailingZeros = RegExp(r'\.?0+$');

/// 按 [fractionDigits] 位小数取整后去掉末尾的零，如 `0.50` → `0.5`、`2.00` → `2`。
String formatEmphasisWeight(double weight, {int fractionDigits = 2}) {
  final fixed = weight.toStringAsFixed(fractionDigits);
  if (!fixed.contains('.')) return fixed;
  final trimmed = fixed.replaceFirst(_trailingZeros, '');
  return trimmed == '-0' ? '0' : trimmed;
}
