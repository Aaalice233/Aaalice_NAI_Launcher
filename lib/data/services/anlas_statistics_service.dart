import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';

part 'anlas_statistics_service.g.dart';

/// 每日Anlas消耗统计
class DailyAnlasStat {
  final DateTime date;
  final int cost;

  const DailyAnlasStat({required this.date, required this.cost});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'cost': cost,
  };

  factory DailyAnlasStat.fromJson(Map<String, dynamic> json) => DailyAnlasStat(
    date: DateTime.parse(json['date'] as String),
    cost: json['cost'] as int,
  );
}

/// 指定统计周期内的 Anlas 汇总。
class AnlasPeriodStats {
  final DateTime requestedStartDate;
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyAnlasStat> dailyStats;
  final int totalCost;

  const AnlasPeriodStats({
    required this.requestedStartDate,
    required this.startDate,
    required this.endDate,
    required this.dailyStats,
    required this.totalCost,
  });

  int get coveredDays => dailyStats.length;

  int get averageDailyCost => coveredDays == 0 ? 0 : totalCost ~/ coveredDays;

  bool get hasPartialCoverage => startDate.isAfter(requestedStartDate);
}

/// Anlas统计服务 - 记录和管理点数消耗数据
@Riverpod(keepAlive: true)
class AnlasStatisticsService extends _$AnlasStatisticsService {
  static const String _storageKey = 'anlas_daily_stats';
  static const String _coverageStartKey = 'anlas_stats_coverage_start';

  late SharedPreferences _prefs;
  late DateTime _coverageStartDate;
  final Map<String, int> _dailyStats = {};

  @override
  Future<AnlasStatisticsService> build() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadStats();
    await _loadCoverageStart();
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

  Future<void> _loadCoverageStart() async {
    final storedValue = _prefs.getString(_coverageStartKey);
    final storedDate = storedValue == null
        ? null
        : DateTime.tryParse(storedValue);
    final earliestStatDate = _dailyStats.keys.isEmpty
        ? null
        : _keyToDate(
            _dailyStats.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
          );

    var coverageStart = storedDate ?? earliestStatDate ?? DateTime.now();
    coverageStart = _dateOnly(coverageStart);

    // 兼容旧版本：首次升级时以仍可用的最早记录作为数据覆盖起点。
    if (earliestStatDate != null && earliestStatDate.isBefore(coverageStart)) {
      coverageStart = earliestStatDate;
    }

    _coverageStartDate = coverageStart;
    final normalizedValue = coverageStart.toIso8601String();
    if (storedValue != normalizedValue) {
      await _prefs.setString(_coverageStartKey, normalizedValue);
    }
  }

  /// 保存统计数据
  Future<void> _saveStats() async {
    try {
      final entries = _dailyStats.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final stats = entries.map((e) {
        return DailyAnlasStat(date: _keyToDate(e.key), cost: e.value).toJson();
      }).toList();

      await _prefs.setString(_storageKey, jsonEncode(stats));
    } catch (e) {
      AppLogger.e('Failed to save Anlas stats: $e', 'AnlasStats');
    }
  }

  /// 记录Anlas消耗
  Future<void> recordCost(int cost, {DateTime? date}) async {
    if (cost <= 0) return;

    final targetDate = _dateOnly(date ?? DateTime.now());
    if (targetDate.isBefore(_coverageStartDate)) {
      _coverageStartDate = targetDate;
      await _prefs.setString(
        _coverageStartKey,
        _coverageStartDate.toIso8601String(),
      );
    }
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

  /// 获取指定天数的每日统计。
  List<DailyAnlasStat> getDailyStats({int days = 14, DateTime? endDate}) {
    return getPeriodStats(days: days, endDate: endDate).dailyStats;
  }

  /// 获取滚动统计周期；[days] 为 null 时返回全部可用数据。
  AnlasPeriodStats getPeriodStats({int? days, DateTime? endDate}) {
    if (days != null && days <= 0) {
      throw ArgumentError.value(days, 'days', 'must be greater than zero');
    }

    final end = _dateOnly(endDate ?? DateTime.now());
    final requestedStart = days == null
        ? _coverageStartDate
        : DateTime(end.year, end.month, end.day - days + 1);
    var start = requestedStart.isBefore(_coverageStartDate)
        ? _coverageStartDate
        : requestedStart;
    if (start.isAfter(end)) {
      start = end;
    }

    final result = <DailyAnlasStat>[];
    var total = 0;
    final coveredDays = _calendarDayCount(start, end);
    for (var i = 0; i < coveredDays; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final cost = _dailyStats[_dateToKey(date)] ?? 0;
      total += cost;
      result.add(DailyAnlasStat(date: date, cost: cost));
    }

    return AnlasPeriodStats(
      requestedStartDate: requestedStart,
      startDate: start,
      endDate: end,
      dailyStats: List.unmodifiable(result),
      totalCost: total,
    );
  }

  DateTime get coverageStartDate => _coverageStartDate;

  bool get hasData => _dailyStats.isNotEmpty;

  /// 获取总消耗
  int get totalCost {
    return _dailyStats.values.fold(0, (sum, cost) => sum + cost);
  }

  /// 获取指定日期范围内的消耗
  int getCostInRange(DateTime start, DateTime end) {
    int total = 0;
    final startKey = _dateToKey(start);
    final endKey = _dateToKey(end);
    for (final entry in _dailyStats.entries) {
      if (entry.key.compareTo(startKey) >= 0 &&
          entry.key.compareTo(endKey) <= 0) {
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

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _calendarDayCount(DateTime start, DateTime end) {
    final utcStart = DateTime.utc(start.year, start.month, start.day);
    final utcEnd = DateTime.utc(end.year, end.month, end.day);
    return utcEnd.difference(utcStart).inDays + 1;
  }
}
