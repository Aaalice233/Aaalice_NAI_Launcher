import 'package:intl/intl.dart';

import '../utils/app_logger.dart';

/// 日期格式化服务
/// 封装日期和日期范围格式化逻辑
class DateFormattingService {
  /// 格式化日期为 ISO 格式 (YYYY-MM-DD)
  ///
  /// [date] 要格式化的日期
  /// 返回格式为 'YYYY-MM-DD' 的字符串，例如 '2024-01-15'
  String formatDate(DateTime date) {
    try {
      final formatted =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      AppLogger.d('Formatted date: $formatted', 'DateFormattingService');
      return formatted;
    } catch (e) {
      AppLogger.e('Failed to format date: $e', 'DateFormattingService');
      rethrow;
    }
  }

  /// 格式化日期范围为显示格式 (MM-dd~MM-dd)
  ///
  /// [start] 起始日期，可以为 null
  /// [end] 结束日期，可以为 null
  /// 返回格式化的日期范围字符串：
  /// - 如果 start 和 end 都不为 null：'MM-dd~MM-dd'
  /// - 如果只有 start 不为 null：'MM-dd~'
  /// - 如果只有 end 不为 null：'~MM-dd'
  /// - 如果都为 null：空字符串
  String formatDateRange(DateTime? start, DateTime? end) {
    try {
      final format = DateFormat('MM-dd');

      if (start != null && end != null) {
        final result = '${format.format(start)}~${format.format(end)}';
        AppLogger.d('Formatted date range: $result', 'DateFormattingService');
        return result;
      } else if (start != null) {
        final result = '${format.format(start)}~';
        AppLogger.d(
          'Formatted date range (start only): $result',
          'DateFormattingService',
        );
        return result;
      } else if (end != null) {
        final result = '~${format.format(end)}';
        AppLogger.d(
          'Formatted date range (end only): $result',
          'DateFormattingService',
        );
        return result;
      }

      AppLogger.d(
          'Formatted date range (empty): empty', 'DateFormattingService');
      return '';
    } catch (e) {
      AppLogger.e('Failed to format date range: $e', 'DateFormattingService');
      rethrow;
    }
  }

  /// 格式化日期为自定义格式
  ///
  /// [date] 要格式化的日期
  /// [pattern] 日期格式模式，例如 'yyyy-MM-dd HH:mm:ss'
  /// 返回按照指定模式格式化的字符串
  String formatWithPattern(DateTime date, String pattern) {
    try {
      final format = DateFormat(pattern);
      final formatted = format.format(date);
      AppLogger.d(
        'Formatted date with pattern "$pattern": $formatted',
        'DateFormattingService',
      );
      return formatted;
    } catch (e) {
      AppLogger.e(
        'Failed to format date with pattern: $e',
        'DateFormattingService',
      );
      rethrow;
    }
  }
}
