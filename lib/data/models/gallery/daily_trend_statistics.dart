import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_trend_statistics.freezed.dart';

/// 每日趋势统计
///
/// 用于统计每日的图片生成数量和趋势数据
/// 支持按日/周/月聚合的时间序列分析
@freezed
class DailyTrendStatistics with _$DailyTrendStatistics {
  const factory DailyTrendStatistics({
    /// 日期（该统计数据的日期）
    required DateTime date,

    /// 生成的图片数量
    required int count,

    /// 总磁盘大小（字节）
    @Default(0) int totalSizeBytes,

    /// 收藏图片数量
    @Default(0) int favoriteCount,

    /// 有标签的图片数量
    @Default(0) int taggedImageCount,

    /// 占比（相对于总数的百分比）
    @Default(0) double percentage,
  }) = _DailyTrendStatistics;

  const DailyTrendStatistics._();

  /// 获取格式化的日期字符串
  ///
  /// 根据当前locale返回格式化的日期
  String getFormattedDate([String locale = 'zh_CN']) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    if (locale == 'zh_CN') {
      return '$year年$month月$day日';
    } else {
      // Default to English format
      return '$month/$day/$year';
    }
  }

  /// 获取格式化的日期字符串（短格式）
  ///
  /// 用于图表显示的紧凑格式
  String getFormattedDateShort([String locale = 'zh_CN']) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    if (locale == 'zh_CN') {
      return '$month/$day';
    } else {
      return '$month/$day';
    }
  }

  /// 获取格式化的总大小字符串
  ///
  /// 自动选择合适的单位（B/KB/MB/GB）
  String get totalSizeFormatted {
    return _formatBytes(totalSizeBytes);
  }

  /// 格式化字节数为可读字符串
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(2);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$gb GB';
    }
  }

  /// 获取收藏图片占比
  double get favoritePercentage {
    if (count == 0) return 0.0;
    return (favoriteCount / count) * 100;
  }

  /// 获取有标签图片占比
  double get taggedImagePercentage {
    if (count == 0) return 0.0;
    return (taggedImageCount / count) * 100;
  }
}

/// 每周趋势统计
///
/// 用于统计每周的图片生成数量和趋势数据
@freezed
class WeeklyTrendStatistics with _$WeeklyTrendStatistics {
  const factory WeeklyTrendStatistics({
    /// 周起始日期
    required DateTime weekStart,

    /// 周结束日期
    required DateTime weekEnd,

    /// 生成的图片数量
    required int count,

    /// 总磁盘大小（字节）
    @Default(0) int totalSizeBytes,

    /// 收藏图片数量
    @Default(0) int favoriteCount,

    /// 有标签的图片数量
    @Default(0) int taggedImageCount,

    /// 占比（相对于总数的百分比）
    @Default(0) double percentage,
  }) = _WeeklyTrendStatistics;

  const WeeklyTrendStatistics._();

  /// 获取格式化的周范围字符串
  String getFormattedWeekRange([String locale = 'zh_CN']) {
    final startMonth = weekStart.month.toString().padLeft(2, '0');
    final startDay = weekStart.day.toString().padLeft(2, '0');
    final endMonth = weekEnd.month.toString().padLeft(2, '0');
    final endDay = weekEnd.day.toString().padLeft(2, '0');

    if (locale == 'zh_CN') {
      return '$startMonth月$startDay日 - $endMonth月$endDay日';
    } else {
      return '$startMonth/$startDay - $endMonth/$endDay';
    }
  }
}

/// 每月趋势统计
///
/// 用于统计每月的图片生成数量和趋势数据
@freezed
class MonthlyTrendStatistics with _$MonthlyTrendStatistics {
  const factory MonthlyTrendStatistics({
    /// 年份
    required int year,

    /// 月份（1-12）
    required int month,

    /// 生成的图片数量
    required int count,

    /// 总磁盘大小（字节）
    @Default(0) int totalSizeBytes,

    /// 收藏图片数量
    @Default(0) int favoriteCount,

    /// 有标签的图片数量
    @Default(0) int taggedImageCount,

    /// 占比（相对于总数的百分比）
    @Default(0) double percentage,
  }) = _MonthlyTrendStatistics;

  const MonthlyTrendStatistics._();

  /// 获取格式化的月份字符串
  String getFormattedMonth([String locale = 'zh_CN']) {
    if (locale == 'zh_CN') {
      return '$year年${month.toString().padLeft(2, '0')}月';
    } else {
      // English format
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${monthNames[month - 1]} $year';
    }
  }
}
