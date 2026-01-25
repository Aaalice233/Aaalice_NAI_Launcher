import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../../data/models/warmup/warmup_metrics.dart';

part 'warmup_metrics_service.g.dart';

/// 预热指标持久化服务
///
/// 使用 Hive 存储预热任务执行指标，支持会话管理和统计分析
class WarmupMetricsService {
  /// 获取指标 Box
  Box get _metricsBox => Hive.box(StorageKeys.warmupMetricsBox);

  /// 保存一次完整的预热会话指标
  ///
  /// [metrics] 本次预热会话的所有任务指标
  /// 会自动清理超过10条的旧会话记录
  Future<void> saveSession(List<WarmupTaskMetrics> metrics) async {
    try {
      // 生成会话ID（使用当前时间戳）
      final sessionId = DateTime.now().millisecondsSinceEpoch;

      // 将指标列表序列化为JSON字符串
      final jsonList = metrics.map((m) => m.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      // 保存会话
      await _metricsBox.put(sessionId, jsonStr);

      // 清理旧记录，只保留最近10次会话
      await _cleanupOldSessions(10);
    } catch (e) {
      // 保存失败，记录错误但不影响应用运行
      // 如果是数据损坏，尝试清理并重建
      if (_isCorrupted()) {
        await _recreateBox();
      }
    }
  }

  /// 获取最近的N次预热会话
  ///
  /// [limit] 返回的会话数量上限
  /// 返回按时间倒序排列的会话列表（最新的在前）
  List<List<WarmupTaskMetrics>> getRecentSessions(int limit) {
    try {
      // 获取所有会话的键并按时间戳倒序排序
      final keys = _metricsBox.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      // 取前limit个键
      final limitedKeys = keys.take(limit).toList();

      // 反序列化会话数据
      final sessions = <List<WarmupTaskMetrics>>[];
      for (final key in limitedKeys) {
        final session = _deserializeSession(key);
        if (session != null) {
          sessions.add(session);
        }
      }

      return sessions;
    } catch (e) {
      // 读取失败，返回空列表
      return [];
    }
  }

  /// 获取指定任务的统计信息
  ///
  /// [taskName] 任务名称（例如：warmup_loadingTranslation）
  /// 返回包含平均值、最小值、最大值的统计信息，如果没有数据则返回null
  Map<String, int>? getStatsForTask(String taskName) {
    try {
      final sessions = getRecentSessions(10);
      if (sessions.isEmpty) {
        return null;
      }

      // 收集所有成功的任务执行时长
      final durations = <int>[];
      for (final session in sessions) {
        final task = session.cast<WarmupTaskMetrics?>().firstWhere(
              (m) => m?.taskName == taskName && m?.isSuccess == true,
              orElse: () => null,
            );
        if (task != null) {
          durations.add(task.durationMs);
        }
      }

      if (durations.isEmpty) {
        return null;
      }

      // 计算统计数据
      durations.sort();
      final min = durations.first;
      final max = durations.last;
      final average = durations.reduce((a, b) => a + b) ~/ durations.length;

      return {
        'average': average,
        'min': min,
        'max': max,
        'count': durations.length,
      };
    } catch (e) {
      // 统计失败，返回null
      return null;
    }
  }

  /// 获取所有预热会话的总数
  int get totalSessionCount {
    try {
      return _metricsBox.length;
    } catch (e) {
      return 0;
    }
  }

  /// 清空所有预热指标
  Future<void> clear() async {
    try {
      await _metricsBox.clear();
    } catch (e) {
      // 清空失败，尝试重建
      await _recreateBox();
    }
  }

  /// 清理旧会话记录，只保留最近的指定数量
  ///
  /// [keepCount] 保留的会话数量
  Future<void> _cleanupOldSessions(int keepCount) async {
    try {
      final keys = _metricsBox.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      if (keys.length <= keepCount) {
        return;
      }

      // 删除超过keepCount的旧记录
      final keysToDelete = keys.skip(keepCount).toList();
      for (final key in keysToDelete) {
        await _metricsBox.delete(key);
      }
    } catch (e) {
      // 清理失败，忽略错误
    }
  }

  /// 反序列化单个会话
  ///
  /// 返回会话中的任务指标列表，失败时返回null
  List<WarmupTaskMetrics>? _deserializeSession(dynamic key) {
    try {
      final jsonStr = _metricsBox.get(key) as String?;
      if (jsonStr == null) return null;

      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .cast<Map<String, dynamic>>()
          .map((json) => WarmupTaskMetrics.fromJson(json))
          .toList();
    } catch (e) {
      // 反序列化失败，返回null
      return null;
    }
  }

  /// 检查Box是否损坏
  bool _isCorrupted() {
    try {
      // 尝试访问Box，如果抛出异常则认为损坏
      return _metricsBox.keys.isEmpty ? false : true;
    } catch (e) {
      return true;
    }
  }

  /// 重建Box（用于数据损坏恢复）
  Future<void> _recreateBox() async {
    try {
      await _metricsBox.clear();
    } catch (e) {
      // 重建失败，忽略
    }
  }
}

/// WarmupMetricsService Provider
@riverpod
WarmupMetricsService warmupMetricsService(Ref ref) {
  return WarmupMetricsService();
}
