import 'package:freezed_annotation/freezed_annotation.dart';

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
    /// 对于 exists 类型: {"tag_name": "true/false"}
    /// 对于 value 类型: {"expected_value": "result_value"}
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

  /// 根据源值获取结果
  ///
  /// [sourceValue] 源类别的值（数量或标签名）
  String? getResult(String sourceValue) {
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

    return defaultValue;
  }

  /// 根据源值获取数量范围
  ///
  /// [sourceValue] 源类别的值
  /// [randomInt] 随机数生成函数
  int getCount(String sourceValue, int Function() randomInt) {
    final result = getResult(sourceValue);
    if (result == null) return 0;

    final (min, max) = parseRange(result);
    if (min == max) return min;

    return min + (randomInt() % (max - min + 1));
  }

  /// 检查依赖是否满足
  ///
  /// [context] 当前上下文，包含已选择的标签
  bool checkDependency(Map<String, List<String>> context) {
    final sourceValues = context[sourceCategoryId] ?? [];

    switch (type) {
      case DependencyType.exists:
        // 检查源标签是否存在
        return sourceValues.isNotEmpty;

      case DependencyType.excludes:
        // 检查源标签是否不存在
        return sourceValues.isEmpty;

      case DependencyType.count:
      case DependencyType.value:
        // count 和 value 类型总是满足，只影响结果
        return true;
    }
  }
}
