// 编码 Vibe 的强度归一化，与官网前端提交前的客户端缩放逐字对齐。

/// 开启且多于一张时，绝对值之和超过 1 就按总和等比缩小；其余情况原样返回。
List<double> normalizeReferenceStrengths(
  List<double> strengths, {
  required bool enabled,
}) {
  if (!enabled || strengths.length < 2) {
    return strengths;
  }
  final total = strengths.fold<double>(0, (sum, value) => sum + value.abs());
  if (total <= 1) {
    return strengths;
  }
  return strengths.map((value) => value / total).toList(growable: false);
}
