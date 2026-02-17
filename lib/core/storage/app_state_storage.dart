import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';

part 'app_state_storage.g.dart';

/// 应用状态存储版本，用于数据迁移
const int _appStateVersion = 1;

/// 应用会话状态数据
class AppSessionState {
  /// 会话开始时间
  final DateTime sessionStartTime;

  /// 最后活跃时间
  final DateTime lastActiveTime;

  /// 是否有活跃的队列执行
  final bool hasActiveQueueExecution;

  /// 当前队列任务ID（如果有）
  final String? currentTaskId;

  /// 当前队列索引
  final int currentQueueIndex;

  /// 队列总任务数
  final int totalQueueTasks;

  /// 应用状态版本
  final int version;

  const AppSessionState({
    required this.sessionStartTime,
    required this.lastActiveTime,
    this.hasActiveQueueExecution = false,
    this.currentTaskId,
    this.currentQueueIndex = 0,
    this.totalQueueTasks = 0,
    this.version = _appStateVersion,
  });

  /// 从JSON创建
  factory AppSessionState.fromJson(Map<String, dynamic> json) {
    return AppSessionState(
      sessionStartTime: DateTime.parse(json['sessionStartTime'] as String),
      lastActiveTime: DateTime.parse(json['lastActiveTime'] as String),
      hasActiveQueueExecution: json['hasActiveQueueExecution'] as bool? ?? false,
      currentTaskId: json['currentTaskId'] as String?,
      currentQueueIndex: json['currentQueueIndex'] as int? ?? 0,
      totalQueueTasks: json['totalQueueTasks'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'sessionStartTime': sessionStartTime.toIso8601String(),
      'lastActiveTime': lastActiveTime.toIso8601String(),
      'hasActiveQueueExecution': hasActiveQueueExecution,
      'currentTaskId': currentTaskId,
      'currentQueueIndex': currentQueueIndex,
      'totalQueueTasks': totalQueueTasks,
      'version': version,
    };
  }

  /// 复制并修改
  AppSessionState copyWith({
    DateTime? sessionStartTime,
    DateTime? lastActiveTime,
    bool? hasActiveQueueExecution,
    String? currentTaskId,
    int? currentQueueIndex,
    int? totalQueueTasks,
    int? version,
    bool clearCurrentTaskId = false,
  }) {
    return AppSessionState(
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      hasActiveQueueExecution:
          hasActiveQueueExecution ?? this.hasActiveQueueExecution,
      currentTaskId: clearCurrentTaskId ? null : (currentTaskId ?? this.currentTaskId),
      currentQueueIndex: currentQueueIndex ?? this.currentQueueIndex,
      totalQueueTasks: totalQueueTasks ?? this.totalQueueTasks,
      version: version ?? this.version,
    );
  }
}

/// 应用状态存储服务
///
/// 用于集中管理应用会话状态，支持崩溃恢复
class AppStateStorage {
  Box<String>? _box;

  /// 获取状态 Box（懒加载）
  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(StorageKeys.appStateBox);
    return _box!;
  }

  /// 保存应用会话状态
  Future<void> saveSessionState(AppSessionState state) async {
    try {
      final box = await _getBox();
      final jsonString = jsonEncode(state.toJson());
      await box.put(StorageKeys.lastSessionState, jsonString);
    } catch (e) {
      // 保存失败时静默处理，避免影响主流程
    }
  }

  /// 加载应用会话状态
  Future<AppSessionState?> loadSessionState() async {
    try {
      final box = await _getBox();
      final jsonString = box.get(StorageKeys.lastSessionState);

      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final state = AppSessionState.fromJson(json);

      // 版本检查，如果版本不匹配可能需要迁移
      if (state.version != _appStateVersion) {
        // 这里可以添加迁移逻辑
        // 目前直接返回null，让调用方创建新状态
        return null;
      }

      return state;
    } catch (e) {
      // 加载失败时返回null
      return null;
    }
  }

  /// 更新最后活跃时间
  Future<void> updateLastActiveTime() async {
    try {
      final currentState = await loadSessionState();
      final now = DateTime.now();

      if (currentState != null) {
        await saveSessionState(
          currentState.copyWith(lastActiveTime: now),
        );
      } else {
        await saveSessionState(
          AppSessionState(
            sessionStartTime: now,
            lastActiveTime: now,
          ),
        );
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 开始队列执行时记录状态
  Future<void> recordQueueExecutionStart({
    required String taskId,
    required int currentIndex,
    required int totalTasks,
  }) async {
    try {
      final currentState = await loadSessionState();
      final now = DateTime.now();

      if (currentState != null) {
        await saveSessionState(
          currentState.copyWith(
            lastActiveTime: now,
            hasActiveQueueExecution: true,
            currentTaskId: taskId,
            currentQueueIndex: currentIndex,
            totalQueueTasks: totalTasks,
          ),
        );
      } else {
        await saveSessionState(
          AppSessionState(
            sessionStartTime: now,
            lastActiveTime: now,
            hasActiveQueueExecution: true,
            currentTaskId: taskId,
            currentQueueIndex: currentIndex,
            totalQueueTasks: totalTasks,
          ),
        );
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 更新队列执行进度
  Future<void> updateQueueExecutionProgress({
    required int currentIndex,
    String? currentTaskId,
  }) async {
    try {
      final currentState = await loadSessionState();
      if (currentState == null) return;

      await saveSessionState(
        currentState.copyWith(
          lastActiveTime: DateTime.now(),
          currentQueueIndex: currentIndex,
          currentTaskId: currentTaskId ?? currentState.currentTaskId,
        ),
      );
    } catch (e) {
      // 静默处理
    }
  }

  /// 结束队列执行时清除状态
  Future<void> clearQueueExecutionState() async {
    try {
      final currentState = await loadSessionState();
      if (currentState == null) return;

      await saveSessionState(
        currentState.copyWith(
          lastActiveTime: DateTime.now(),
          hasActiveQueueExecution: false,
          clearCurrentTaskId: true,
          currentQueueIndex: 0,
          totalQueueTasks: 0,
        ),
      );
    } catch (e) {
      // 静默处理
    }
  }

  /// 检查是否需要恢复（异常退出后）
  Future<bool> shouldRecover() async {
    try {
      final state = await loadSessionState();
      if (state == null) return false;

      // 如果有活跃的队列执行，可能需要恢复
      if (!state.hasActiveQueueExecution) return false;

      // 检查最后活跃时间，如果超过一定时间（如5分钟）则认为需要恢复
      final now = DateTime.now();
      final inactiveDuration = now.difference(state.lastActiveTime);

      // 如果最后活跃时间在5分钟以内，可能是在执行过程中异常退出
      return inactiveDuration.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  /// 清除所有状态
  Future<void> clearAll() async {
    try {
      final box = await _getBox();
      await box.delete(StorageKeys.lastSessionState);
    } catch (e) {
      // 静默处理
    }
  }

  /// 关闭存储
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}

/// 应用状态存储服务 Provider
@riverpod
AppStateStorage appStateStorage(Ref ref) {
  return AppStateStorage();
}
