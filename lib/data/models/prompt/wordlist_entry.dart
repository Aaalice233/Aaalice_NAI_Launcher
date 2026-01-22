import 'package:freezed_annotation/freezed_annotation.dart';

part 'wordlist_entry.freezed.dart';
part 'wordlist_entry.g.dart';

/// 词库条目数据模型
/// 用于存储从 CSV 加载的词库数据
@freezed
class WordlistEntry with _$WordlistEntry {
  const WordlistEntry._();

  const factory WordlistEntry({
    /// 变量名 (如 tk, char, etc.)
    required String variable,

    /// 分类 (如 camera_angle, expression, etc.)
    required String category,

    /// 标签文本
    required String tag,

    /// 权重
    @Default(1) int weight,

    /// 排斥列表 - 当此标签被选中时，这些标签不会被选中
    @Default([]) List<String> exclude,

    /// 依赖列表 - 只有当这些标签存在时，此标签才会被选中
    @Default([]) List<String> require,

    /// 额外信息
    @Default([]) List<String> extra,
  }) = _WordlistEntry;

  factory WordlistEntry.fromJson(Map<String, dynamic> json) =>
      _$WordlistEntryFromJson(json);

  /// 从 CSV 行解析
  /// CSV 格式: Variable,Category,Tag,Weight,Exclude,Require,Extra
  /// 示例: tk,camera_angle,dutch angle,12,[],[],[]
  factory WordlistEntry.fromCsvLine(String line) {
    final parts = _parseCsvLine(line);
    if (parts.length < 3) {
      throw FormatException('Invalid CSV line (need at least 3 fields): $line');
    }

    return WordlistEntry(
      variable: parts[0],
      category: parts[1],
      tag: parts[2],
      weight: parts.length > 3 ? int.tryParse(parts[3]) ?? 1 : 1,
      exclude: parts.length > 4 ? _parseListField(parts[4]) : [],
      require: parts.length > 5 ? _parseListField(parts[5]) : [],
      extra: parts.length > 6 ? _parseListField(parts[6]) : [],
    );
  }

  /// 获取显示文本
  String get displayText => tag.replaceAll('_', ' ');

  /// 获取带权重的显示文本
  String get displayTextWithWeight => '$displayText (权重: $weight)';

  /// 检查是否有排斥规则
  bool get hasExcludeRules => exclude.isNotEmpty;

  /// 检查是否有依赖规则
  bool get hasRequireRules => require.isNotEmpty;

  /// 检查是否有任何规则
  bool get hasRules => hasExcludeRules || hasRequireRules;
}

/// 解析 CSV 行，处理引号包裹的字段
List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;
  bool inBrackets = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == '[' && !inQuotes) {
      inBrackets = true;
      buffer.write(char);
    } else if (char == ']' && !inQuotes) {
      inBrackets = false;
      buffer.write(char);
    } else if (char == ',' && !inQuotes && !inBrackets) {
      result.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  // 添加最后一个字段
  result.add(buffer.toString().trim());

  return result;
}

/// 解析列表字段，如 "[a,b,c]" -> ["a", "b", "c"]
List<String> _parseListField(String field) {
  final trimmed = field.trim();
  if (trimmed.isEmpty || trimmed == '[]') {
    return [];
  }

  // 移除方括号
  String content = trimmed;
  if (content.startsWith('[') && content.endsWith(']')) {
    content = content.substring(1, content.length - 1);
  }

  if (content.isEmpty) {
    return [];
  }

  // 分割并清理
  return content
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
