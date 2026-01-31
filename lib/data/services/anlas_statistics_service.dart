import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';

part 'anlas_statistics_service.g.dart';

/// 每日Anlas消耗统计
class DailyAnlasStat {
  final DateTime date;
  final int cost;

  const DailyAnlasStat({
    required this.date,
    required this.cost,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'cost': cost,
      };

  factory DailyAnlasStat.fromJson(Map<String, dynamic> json) => DailyAnlasStat(
        date: DateTime.parse(json['date'] as String),
        cost: json['cost'] as int,
      );
}

/// Anlas统计服务 - 记录和管理点数消耗数据
@Riverpod(keepAlive: true)
class AnlasStatisticsService extends _$AnlasStatisticsService {
  static const String _storageKey = 'anlas_daily_stats';
  static const int _maxDays = 90; // 保留90天数据

  late SharedPreferences _prefs;
  final Map<String, int> _dailyStats = {};

  @override
  Future<AnlasStatisticsService> build() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadStats();
    return this;
  }

  /// 加载统计数据
  Future<void> _loadStats() async {
    try {
      final jsonStr = _prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _dailyStats.clear();
        for (final item in jsonList) {
          final stat = DailyAnlasStat.fromJson(item as Map<String, dynamic>);
          final key = _dateToKey(stat.date);
          _dailyStats[key] = stat.cost;
        }
        AppLogger.d(
          'Loaded ${_dailyStats.length} days of Anlas stats',
          'AnlasStats',
        );
      }
    } catch (e) {
      AppLogger.e('Failed to load Anlas stats: $e', 'AnlasStats');
    }
  }

  /// 保存统计数据
  Future<void> _saveStats() async {
    try {
      // 清理过期数据
      _cleanOldData();

      final stats = _dailyStats.entries.map((e) {
        return DailyAnlasStat(
          date: _keyToDate(e.key),
          cost: e.value,
        ).toJson();
      }).toList();

      await _prefs.setString(_storageKey, jsonEncode(stats));
    } catch (e) {
      AppLogger.e('Failed to save Anlas stats: $e', 'AnlasStats');
    }
  }

  /// 清理过期数据
  void _cleanOldData() {
    final cutoff = DateTime.now().subtract(const Duration(days: _maxDays));
    final cutoffKey = _dateToKey(cutoff);
    _dailyStats.removeWhere((key, _) => key.compareTo(cutoffKey) < 0);
  }

  /// 记录Anlas消耗
  Future<void> recordCost(int cost, {DateTime? date}) async {
    if (cost <= 0) return;

    final targetDate = date ?? DateTime.now();
    final key = _dateToKey(targetDate);
    _dailyStats[key] = (_dailyStats[key] ?? 0) + cost;

    await _saveStats();
    AppLogger.d(
      'Recorded $cost Anlas on $key, total: ${_dailyStats[key]}',
      'AnlasStats',
    );

    // 通知状态更新
    ref.invalidateSelf();
  }

  /// 获取指定天数的每日统计
  List<DailyAnlasStat> getDailyStats({int days = 14}) {
    final result = <DailyAnlasStat>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _dateToKey(date);
      result.add(
        DailyAnlasStat(
          date: date,
          cost: _dailyStats[key] ?? 0,
        ),
      );
    }

    return result;
  }

  /// 获取总消耗
  int get totalCost {
    return _dailyStats.values.fold(0, (sum, cost) => sum + cost);
  }

  /// 获取指定日期范围内的消耗
  int getCostInRange(DateTime start, DateTime end) {
    int total = 0;
    for (final entry in _dailyStats.entries) {
      final date = _keyToDate(entry.key);
      if (!date.isBefore(start) && !date.isAfter(end)) {
        total += entry.value;
      }
    }
    return total;
  }

  /// 获取今日消耗
  int get todayCost {
    final key = _dateToKey(DateTime.now());
    return _dailyStats[key] ?? 0;
  }

  /// 日期转换为key
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// key转换为日期
  DateTime _keyToDate(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
