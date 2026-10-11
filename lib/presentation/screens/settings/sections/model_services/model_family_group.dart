/// 中转站与 Ollama 的 `/`、`:` 前缀就是家族；其余取前两段，如 `gpt-4o-mini` 归入 `gpt-4o`。
String modelFamilyGroup(String modelId) {
  final id = modelId.trim().toLowerCase();
  final prefixEnd = id.indexOf(RegExp(r'[/:]'));
  if (prefixEnd > 0) return id.substring(0, prefixEnd);
  final segments = id.split(RegExp(r'[-_]')).where((part) => part.isNotEmpty);
  return segments.take(2).join('-');
}
