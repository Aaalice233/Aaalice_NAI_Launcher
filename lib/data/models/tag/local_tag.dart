import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_tag.freezed.dart';
part 'local_tag.g.dart';

/// 本地标签数据模型
/// 用于存储从 CSV 加载的标签数据
@freezed
class LocalTag with _$LocalTag {
  const LocalTag._();

  const factory LocalTag({
    /// 标签名称（英文）
    required String tag,

    /// 标签分类
    /// 0 = general (通用)
    /// 1 = artist (艺术家)
    /// 3 = copyright (版权)
    /// 4 = character (角色)
    /// 5 = meta (元数据)
    @Default(0) int category,

    /// 使用次数/频率
    @Default(0) int count,

    /// 标签别名
    String? alias,

    /// 中文翻译
    String? translation,
  }) = _LocalTag;

  factory LocalTag.fromJson(Map<String, dynamic> json) =>
      _$LocalTagFromJson(json);

  /// 从 CSV 行解析
  /// CSV 格式: tag,category,count,alias
  factory LocalTag.fromCsvLine(String line, {String? translation}) {
    final parts = _parseCsvLine(line);
    if (parts.isEmpty) {
      throw FormatException('Invalid CSV line: $line');
    }

    return LocalTag(
      tag: parts[0],
      category: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      count: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
      alias: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      translation: translation,
    );
  }

  /// 获取分类名称
  String get categoryName {
    switch (category) {
      case 1:
        return '艺术家';
      case 3:
        return '版权';
      case 4:
        return '角色';
      case 5:
        return '元数据';
      default:
        return '通用';
    }
  }

  /// 获取分类英文名称
  String get categoryNameEn {
    switch (category) {
      case 1:
        return 'artist';
      case 3:
        return 'copyright';
      case 4:
        return 'character';
      case 5:
        return 'meta';
      default:
        return 'general';
    }
  }

  /// 格式化显示的计数
  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// 获取显示文本
  /// 如果有翻译，返回 "tag (翻译)"
  String get displayText {
    final displayTag = tag.replaceAll('_', ' ');
    if (translation != null && translation!.isNotEmpty) {
      return '$displayTag ($translation)';
    }
    return displayTag;
  }
}

/// 解析 CSV 行，处理引号包裹的字段
List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
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

/// 标签分类枚举
enum LocalTagCategory {
  general(0, '通用', 'general'),
  artist(1, '艺术家', 'artist'),
  copyright(3, '版权', 'copyright'),
  character(4, '角色', 'character'),
  meta(5, '元数据', 'meta');

  final int value;
  final String displayName;
  final String nameEn;

  const LocalTagCategory(this.value, this.displayName, this.nameEn);

  static LocalTagCategory fromValue(int value) {
    return LocalTagCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LocalTagCategory.general,
    );
  }
}

