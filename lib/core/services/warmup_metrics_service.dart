import 'dart:async';
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
  Box? _box;

  /// 获取指标 Box（懒加载，自动打开）
  Future<Box> _getBox() async {
    if (_box?.isOpen == true) {
      return _box!;
    }
    try {
      _box = Hive.box(StorageKeys.warmupMetricsBox);
    } catch (e) {
      // Box 未打开，尝试打开
      _box = await Hive.openBox(StorageKeys.warmupMetricsBox);
    }
    return _box!;
  }

  /// 保存一次完整的预热会话指标
  ///
  /// [metrics] 本次预热会话的所有任务指标
  /// 会自动清理超过10条的旧会话记录
  Future<void> saveSession(List<WarmupTaskMetrics> metrics) async {
    try {
      final box = await _getBox();
      
      // 生成会话ID（使用当前时间戳）
      final sessionId = DateTime.now().millisecondsSinceEpoch;

      // 将指标列表序列化为JSON字符串
      final jsonList = metrics.map((m) => m.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      // 保存会话
      await box.put(sessionId, jsonStr);

      // 清理旧记录，只保留最近10次会话
      await _cleanupOldSessions(10);
    } catch (e) {
      // 保存失败，记录错误但不影响应用运行
      // 如果是数据损坏，尝试清理并重建
      if (await _isCorruptedAsync()) {
        await _recreateBox();
      }
    }
  }

  /// 获取最近的N次预热会话
  ///
  /// [limit] 返回的会话数量上限
  /// 返回按时间倒序排列的会话列表（最新的在前）
  Future<List<List<WarmupTaskMetrics>>> getRecentSessions(int limit) async {
    try {
      final box = await _getBox();
      
      // 获取所有会话的键并按时间戳倒序排序
      final keys = box.keys.toList()..sort((a, b) => b.compareTo(a));

      // 取前limit个键
      final limitedKeys = keys.take(limit).toList();

      // 反序列化会话数据
      final sessions = <List<WarmupTaskMetrics>>[];
      for (final key in limitedKeys) {
        final session = await _deserializeSession(key);
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
  Future<Map<String, int>?> getStatsForTask(String taskName) async {
    try {
      final sessions = await getRecentSessions(10);
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
  Future<int> get totalSessionCount async {
    try {
      final box = await _getBox();
      return box.length;
    } catch (e) {
      return 0;
    }
  }

  /// 清空所有预热指标
  Future<void> clear() async {
    try {
      final box = await _getBox();
      await box.clear();
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
      final box = await _getBox();
      final keys = box.keys.toList()..sort((a, b) => b.compareTo(a));

      if (keys.length <= keepCount) {
        return;
      }

      // 删除超过keepCount的旧记录
      final keysToDelete = keys.skip(keepCount).toList();
      for (final key in keysToDelete) {
        await box.delete(key);
      }
    } catch (e) {
      // 清理失败，忽略错误
    }
  }

  /// 反序列化单个会话
  ///
  /// 返回会话中的任务指标列表，失败时返回null
  Future<List<WarmupTaskMetrics>?> _deserializeSession(dynamic key) async {
    try {
      final box = await _getBox();
      final jsonStr = box.get(key) as String?;
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

  /// 检查Box是否损坏（异步版本）
  Future<bool> _isCorruptedAsync() async {
    try {
      final box = await _getBox();
      // 尝试访问Box，如果抛出异常则认为损坏
      box.keys; // 仅访问测试
      return false; // 能正常访问则未损坏
    } catch (e) {
      return true; // 抛出异常则认为损坏
    }
  }

  /// 重建Box（用于数据损坏恢复）
  Future<void> _recreateBox() async {
    try {
      // 尝试关闭并重新打开box
      if (_box?.isOpen == true) {
        await _box!.clear();
      } else {
        _box = await Hive.openBox(StorageKeys.warmupMetricsBox);
        await _box!.clear();
      }
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
