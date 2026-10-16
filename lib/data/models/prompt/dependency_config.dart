import 'package:freezed_annotation/freezed_annotation.dart';

import 'rule_tag_match.dart';

part 'dependency_config.freezed.dart';
part 'dependency_config.g.dart';

/// 依赖类型枚举
enum DependencyType {
  /// 数量依赖 - 选择数量依赖其他类别的结果数量
  count,

  /// 存在依赖 - 只有当依赖的标签存在时才生效
  exists,

  /// 值依赖 - 依赖特定标签的值
  value,

  /// 排斥依赖 - 当依赖的标签存在时不生效
  excludes,
}

/// 依赖配置模型
///
/// 实现词组选择数量依赖其他类别结果的功能
/// 例如: 配饰数量根据角色总数变化 - 1人(0-3个), 2人(0-2个), 3人(0-1个)
@freezed
class DependencyConfig with _$DependencyConfig {
  const DependencyConfig._();

  const factory DependencyConfig({
    /// 依赖类型
    @Default(DependencyType.count) DependencyType type,

    /// 依赖的源类别ID
    required String sourceCategoryId,

    /// 依赖的源变量名（可选，用于更精确的依赖）
    String? sourceVariable,

    /// 依赖映射规则
    /// 对于 count 类型: {"1": "0-3", "2": "0-2", "3": "0-1"}
    /// 对于 value 类型: {"expected_value": "result_value"}
    /// exists 与 excludes 类型只判断是否生成，不使用映射
    @Default({}) Map<String, String> mappingRules,

    /// 默认值（当没有匹配的规则时使用）
    String? defaultValue,

    /// 是否启用
    @Default(true) bool enabled,

    /// 描述
    String? description,
  }) = _DependencyConfig;

  factory DependencyConfig.fromJson(Map<String, dynamic> json) =>
      _$DependencyConfigFromJson(json);

  /// 解析范围字符串
  ///
  /// [rangeStr] 范围字符串，如 "0-3", "1", "2-5"
  /// 返回 (min, max) 元组
  static (int, int) parseRange(String rangeStr) {
    final parts = rangeStr.split('-');
    if (parts.length == 1) {
      final value = int.tryParse(parts[0].trim()) ?? 0;
      return (value, value);
    }
    final min = int.tryParse(parts[0].trim()) ?? 0;
    final max = int.tryParse(parts[1].trim()) ?? min;
    return (min, max);
  }

  /// 按源的结果查映射，都没有匹配时使用默认值
  ///
  /// 数量依赖先按 [sourceCount] 匹配；随后与值依赖一样取第一个有映射的
  /// [sourceValues]（类别为已选标签，角色数量为人数）
  String? getResultForSource({
    required int sourceCount,
    required Iterable<String> sourceValues,
  }) {
    if (type == DependencyType.count) {
      final byCount = _matchMapping('$sourceCount');
      if (byCount != null) return byCount;
    }
    // 已选值可能带权重括号，映射键可能用下划线，按比较键匹配
    final resultsByKey = <String, String>{};
    for (final entry in mappingRules.entries) {
      final key = ruleTagMatchKey(entry.key);
      if (key.isNotEmpty) resultsByKey.putIfAbsent(key, () => entry.value);
    }
    for (final value in sourceValues) {
      final result = resultsByKey[ruleTagMatchKey(value)];
      if (result != null) return result;
    }
    return defaultValue;
  }

  String? _matchMapping(String sourceValue) {
    // 直接匹配
    if (mappingRules.containsKey(sourceValue)) {
      return mappingRules[sourceValue];
    }

    // 尝试数值匹配（对于 count 类型）
    if (type == DependencyType.count) {
      final sourceNum = int.tryParse(sourceValue);
      if (sourceNum != null) {
        // 查找最接近的规则
        for (final entry in mappingRules.entries) {
          final ruleNum = int.tryParse(entry.key);
          if (ruleNum != null && ruleNum == sourceNum) {
            return entry.value;
          }
        }
        // 查找范围规则（如 "1-3": "value"）
        for (final entry in mappingRules.entries) {
          if (entry.key.contains('-')) {
            final (min, max) = parseRange(entry.key);
            if (sourceNum >= min && sourceNum <= max) {
              return entry.value;
            }
          }
        }
      }
    }

    return null;
  }

  /// 把映射结果（如 "0-3"）换算为选取数量，没有结果时为 0
  int getCountForResult(String? result, int Function() randomInt) {
    if (result == null) return 0;

    final (min, max) = parseRange(result);
    if (min == max) return min;

    return min + (randomInt() % (max - min + 1));
  }

  /// 数量与值依赖决定选取数量；存在与排斥依赖只决定是否生成
  bool get controlsSelectionCount =>
      type == DependencyType.count || type == DependencyType.value;

  /// 检查依赖是否满足
  ///
  /// [sourceCount] 源的结果数：类别为已选标签数，角色数量为人数。
  /// 存在依赖要求结果数大于 0，排斥依赖要求为 0
  bool isSatisfiedBy(int sourceCount) {
    switch (type) {
      case DependencyType.exists:
        return sourceCount > 0;

      case DependencyType.excludes:
        return sourceCount == 0;

      case DependencyType.count:
      case DependencyType.value:
        return true;
    }
  }
}
