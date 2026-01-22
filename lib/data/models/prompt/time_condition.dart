import 'package:freezed_annotation/freezed_annotation.dart';

part 'time_condition.freezed.dart';
part 'time_condition.g.dart';

/// 时间条件模型
///
/// 词组在特定日期范围内启用
/// 例如: 圣诞节词库 12月1-31日启用
/// 注意: 首版不支持跨年日期范围
@freezed
class TimeCondition with _$TimeCondition {
  const TimeCondition._();

  const factory TimeCondition({
    /// 条件ID
    required String id,

    /// 条件名称
    required String name,

    /// 开始月份 (1-12)
    required int startMonth,

    /// 开始日期 (1-31)
    required int startDay,

    /// 结束月份 (1-12)
    required int endMonth,

    /// 结束日期 (1-31)
    required int endDay,

    /// 是否每年重复
    @Default(true) bool recurring,

    /// 特定年份（仅当 recurring 为 false 时有效）
    int? specificYear,

    /// 是否启用
    @Default(true) bool enabled,

    /// 描述
    String? description,
  }) = _TimeCondition;

  factory TimeCondition.fromJson(Map<String, dynamic> json) =>
      _$TimeConditionFromJson(json);

  /// 创建圣诞节条件（12月1-31日）
  factory TimeCondition.christmas({String? id}) => TimeCondition(
        id: id ?? 'christmas',
        name: '圣诞节',
        startMonth: 12,
        startDay: 1,
        endMonth: 12,
        endDay: 31,
        description: '圣诞节特殊词库，12月1日至31日启用',
      );

  /// 创建万圣节条件（10月1-31日）
  factory TimeCondition.halloween({String? id}) => TimeCondition(
        id: id ?? 'halloween',
        name: '万圣节',
        startMonth: 10,
        startDay: 1,
        endMonth: 10,
        endDay: 31,
        description: '万圣节特殊词库，10月1日至31日启用',
      );

  /// 创建情人节条件（2月1-14日）
  factory TimeCondition.valentines({String? id}) => TimeCondition(
        id: id ?? 'valentines',
        name: '情人节',
        startMonth: 2,
        startDay: 1,
        endMonth: 2,
        endDay: 14,
        description: '情人节特殊词库，2月1日至14日启用',
      );

  /// 检查指定日期是否在条件范围内
  ///
  /// [date] 要检查的日期
  bool isActive([DateTime? date]) {
    if (!enabled) return false;

    final checkDate = date ?? DateTime.now();

    // 检查特定年份
    if (!recurring && specificYear != null) {
      if (checkDate.year != specificYear) return false;
    }

    final month = checkDate.month;
    final day = checkDate.day;

    // 首版不支持跨年，所以简单比较
    // 注意：如果 startMonth > endMonth，说明跨年，首版不支持
    if (startMonth > endMonth) {
      // 跨年情况：首版不支持，返回 false
      return false;
    }

    // 同年内的日期范围
    if (month < startMonth || month > endMonth) {
      return false;
    }

    if (month == startMonth && day < startDay) {
      return false;
    }

    if (month == endMonth && day > endDay) {
      return false;
    }

    return true;
  }

  /// 获取显示文本
  String get displayText {
    final start = '$startMonth月$startDay日';
    final end = '$endMonth月$endDay日';
    return '$name ($start - $end)';
  }

  /// 获取简短显示文本
  String get shortDisplayText => '$startMonth/$startDay - $endMonth/$endDay';

  /// 检查是否跨年（首版不支持）
  bool get isCrossYear => startMonth > endMonth;

  /// 获取剩余天数（如果当前在范围内）
  int? getRemainingDays([DateTime? date]) {
    if (!isActive(date)) return null;

    final checkDate = date ?? DateTime.now();
    final endDate = DateTime(checkDate.year, endMonth, endDay);

    return endDate.difference(checkDate).inDays;
  }
}

/// 时间条件组
///
/// 管理多个时间条件
@freezed
class TimeConditionGroup with _$TimeConditionGroup {
  const TimeConditionGroup._();

  const factory TimeConditionGroup({
    /// 条件列表
    @Default([]) List<TimeCondition> conditions,

    /// 匹配模式 - any: 任一满足即可, all: 所有都满足
    @Default(true) bool matchAny,
  }) = _TimeConditionGroup;

  factory TimeConditionGroup.fromJson(Map<String, dynamic> json) =>
      _$TimeConditionGroupFromJson(json);

  /// 检查是否有任何条件满足
  bool isAnyActive([DateTime? date]) {
    if (conditions.isEmpty) return true;
    return conditions.any((c) => c.isActive(date));
  }

  /// 检查是否所有条件都满足
  bool isAllActive([DateTime? date]) {
    if (conditions.isEmpty) return true;
    return conditions.every((c) => c.isActive(date));
  }

  /// 检查是否满足（根据 matchAny 模式）
  bool isActive([DateTime? date]) {
    return matchAny ? isAnyActive(date) : isAllActive(date);
  }

  /// 获取当前激活的条件
  List<TimeCondition> getActiveConditions([DateTime? date]) {
    return conditions.where((c) => c.isActive(date)).toList();
  }
}
