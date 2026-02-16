import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import 'app_state_storage.dart';

part 'crash_recovery_service.g.dart';

/// 会话状态日志条目
///
/// 用于记录会话状态的变更历史，支持崩溃恢复
class SessionJournalEntry {
  /// 条目ID（时间戳+随机数）
  final String id;

  /// 记录时间
  final DateTime timestamp;

  /// 条目类型
  final JournalEntryType type;

  /// 会话状态快照
  final AppSessionState? sessionState;

  /// 额外上下文信息（如错误信息、操作名称等）
  final Map<String, dynamic>? metadata;

  const SessionJournalEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    this.sessionState,
    this.metadata,
  });

  /// 从JSON创建
  factory SessionJournalEntry.fromJson(Map<String, dynamic> json) {
    return SessionJournalEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: JournalEntryType.values.byName(json['type'] as String),
      sessionState: json['sessionState'] != null
          ? AppSessionState.fromJson(
              json['sessionState'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'sessionState': sessionState?.toJson(),
      'metadata': metadata,
    };
  }
}

/// 日志条目类型
enum JournalEntryType {
  /// 会话开始
  sessionStart,

  /// 会话心跳（定期更新）
  heartbeat,

  /// 队列执行开始
  queueStart,

  /// 队列进度更新
  queueProgress,

  /// 队列执行完成
  queueComplete,

  /// 队列执行失败
  queueFailed,

  /// 恢复点创建
  checkpoint,

  /// 崩溃恢复尝试
  recoveryAttempt,

  /// 会话正常结束
  sessionEnd,
}

/// 崩溃恢复服务
///
/// 使用 Hive 存储会话状态日志，支持：
/// 1. 定期记录会话状态（journaling）
/// 2. 创建恢复点（checkpoints）
/// 3. 检测崩溃并恢复状态
/// 4. 清理过期的日志条目
class CrashRecoveryService {
  Box<String>? _box;

  /// 获取日志 Box（懒加载）
  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(StorageKeys.appStateBox);
    return _box!;
  }

  /// 生成唯一ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
  }

  /// 生成随机后缀
  String _randomSuffix() {
    return (1000 + DateTime.now().microsecond % 9000).toString();
  }

  /// 记录会话状态日志
  ///
  /// [type] - 日志条目类型
  /// [sessionState] - 会话状态快照（可选）
  /// [metadata] - 额外上下文信息（可选）
  Future<SessionJournalEntry?> logSessionState({
    required JournalEntryType type,
    AppSessionState? sessionState,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final box = await _getBox();
      final entry = SessionJournalEntry(
        id: _generateId(),
        timestamp: DateTime.now(),
        type: type,
        sessionState: sessionState,
        metadata: metadata,
      );

      // 获取现有日志
      final journal = await _loadJournal(box);

      // 添加新条目
      journal.add(entry);

      // 限制日志大小，只保留最近100条
      while (journal.length > 100) {
        journal.removeAt(0);
      }

      // 保存日志
      await _saveJournal(box, journal);

      return entry;
    } catch (e) {
      // 日志记录失败时不抛出异常，避免影响主流程
      return null;
    }
  }

  /// 创建恢复点
  ///
  /// 在关键操作前调用，保存当前会话状态的完整快照
  Future<SessionJournalEntry?> createCheckpoint(
    AppSessionState sessionState, {
    String? operationName,
  }) async {
    return logSessionState(
      type: JournalEntryType.checkpoint,
      sessionState: sessionState,
      metadata: operationName != null ? {'operation': operationName} : null,
    );
  }

  /// 记录队列执行开始
  Future<SessionJournalEntry?> logQueueStart(AppSessionState sessionState) async {
    return logSessionState(
      type: JournalEntryType.queueStart,
      sessionState: sessionState,
      metadata: {
        'taskId': sessionState.currentTaskId,
        'totalTasks': sessionState.totalQueueTasks,
      },
    );
  }

  /// 记录队列进度更新
  Future<SessionJournalEntry?> logQueueProgress(
    AppSessionState sessionState, {
    String? message,
  }) async {
    return logSessionState(
      type: JournalEntryType.queueProgress,
      sessionState: sessionState,
      metadata: message != null ? {'message': message} : null,
    );
  }

  /// 记录队列执行完成
  Future<SessionJournalEntry?> logQueueComplete(AppSessionState sessionState) async {
    return logSessionState(
      type: JournalEntryType.queueComplete,
      sessionState: sessionState,
    );
  }

  /// 记录队列执行失败
  Future<SessionJournalEntry?> logQueueFailed(
    AppSessionState sessionState,
    String error, {
    StackTrace? stackTrace,
  }) async {
    return logSessionState(
      type: JournalEntryType.queueFailed,
      sessionState: sessionState,
      metadata: {
        'error': error,
        'stackTrace': stackTrace?.toString(),
      },
    );
  }

  /// 加载会话状态日志
  Future<List<SessionJournalEntry>> loadJournal() async {
    try {
      final box = await _getBox();
      return _loadJournal(box);
    } catch (e) {
      return [];
    }
  }

  /// 从存储加载日志（内部方法）
  List<SessionJournalEntry> _loadJournal(Box<String> box) {
    try {
      final jsonString = box.get('session_journal');

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final entriesJson = json['entries'] as List<dynamic>;

      return entriesJson
          .map((e) => SessionJournalEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 保存日志到存储（内部方法）
  Future<void> _saveJournal(
    Box<String> box,
    List<SessionJournalEntry> journal,
  ) async {
    final json = {
      'entries': journal.map((e) => e.toJson()).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await box.put('session_journal', jsonEncode(json));
  }

  /// 获取最近的恢复点
  ///
  /// 返回最近的 checkpoint 或 queueStart 类型的日志条目
  Future<SessionJournalEntry?> getLastRecoveryPoint() async {
    try {
      final journal = await loadJournal();

      // 从后向前查找最近的恢复点
      for (final entry in journal.reversed) {
        if (entry.type == JournalEntryType.checkpoint ||
            entry.type == JournalEntryType.queueStart) {
          return entry;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 分析崩溃情况
  ///
  /// 返回崩溃分析结果，包括：
  /// - 是否检测到崩溃
  /// - 崩溃时的会话状态
  /// - 建议的恢复操作
  Future<CrashAnalysisResult> analyzeCrash() async {
    try {
      final journal = await loadJournal();

      if (journal.isEmpty) {
        return const CrashAnalysisResult(
          hasCrashDetected: false,
          canRecover: false,
        );
      }

      // 获取最后一个条目
      final lastEntry = journal.last;

      // 检查会话是否正常结束
      if (lastEntry.type == JournalEntryType.sessionEnd) {
        return const CrashAnalysisResult(
          hasCrashDetected: false,
          canRecover: false,
        );
      }

      // 检查最后活跃时间
      final now = DateTime.now();
      final inactiveDuration = now.difference(lastEntry.timestamp);

      // 如果最后记录在5分钟以内，可能是在执行过程中异常退出
      if (inactiveDuration.inMinutes >= 5) {
        return const CrashAnalysisResult(
          hasCrashDetected: false,
          canRecover: false,
          reason: '会话已过期',
        );
      }

      // 检测是否有正在执行的队列任务
      final hasActiveQueue = journal.any((e) =>
          e.type == JournalEntryType.queueStart ||
          e.type == JournalEntryType.queueProgress);

      final hasCompletedQueue = journal.any(
        (e) =>
            e.type == JournalEntryType.queueComplete ||
            e.type == JournalEntryType.queueFailed,
      );

      // 如果有开始但没有完成，可能存在未完成的队列任务
      if (hasActiveQueue && !hasCompletedQueue) {
        final recoveryPoint = await getLastRecoveryPoint();

        return CrashAnalysisResult(
          hasCrashDetected: true,
          canRecover: recoveryPoint?.sessionState != null,
          recoveryPoint: recoveryPoint,
          reason: '检测到未完成的队列任务',
          suggestedAction: CrashRecoveryAction.resumeQueue,
        );
      }

      return CrashAnalysisResult(
        hasCrashDetected: true,
        canRecover: true,
        recoveryPoint: await getLastRecoveryPoint(),
        reason: '检测到异常退出的会话',
        suggestedAction: CrashRecoveryAction.restoreSession,
      );
    } catch (e) {
      return CrashAnalysisResult(
        hasCrashDetected: false,
        canRecover: false,
        reason: '分析失败: $e',
      );
    }
  }

  /// 记录恢复尝试
  Future<SessionJournalEntry?> logRecoveryAttempt({
    required bool success,
    String? error,
    AppSessionState? recoveredState,
  }) async {
    return logSessionState(
      type: JournalEntryType.recoveryAttempt,
      sessionState: recoveredState,
      metadata: {
        'success': success,
        'error': error,
        'recoveryTime': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 记录会话正常结束
  Future<SessionJournalEntry?> logSessionEnd() async {
    return logSessionState(
      type: JournalEntryType.sessionEnd,
      metadata: {'endTime': DateTime.now().toIso8601String()},
    );
  }

  /// 清理过期日志
  ///
  /// [maxAge] - 最大保留时间，超过此时间的日志将被删除
  Future<void> cleanupOldEntries({Duration? maxAge}) async {
    try {
      final box = await _getBox();
      final journal = await _loadJournal(box);

      if (journal.isEmpty) return;

      final cutoff = DateTime.now().subtract(maxAge ?? const Duration(days: 7));

      // 保留最近7天的日志，以及所有 checkpoint
      final filtered = journal.where((entry) {
        // 始终保留 checkpoint
        if (entry.type == JournalEntryType.checkpoint) return true;

        // 保留指定时间内的日志
        return entry.timestamp.isAfter(cutoff);
      }).toList();

      await _saveJournal(box, filtered);
    } catch (e) {
      // 静默处理
    }
  }

  /// 清除所有日志
  Future<void> clearJournal() async {
    try {
      final box = await _getBox();
      await box.delete('session_journal');
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

/// 崩溃分析结果
class CrashAnalysisResult {
  /// 是否检测到崩溃
  final bool hasCrashDetected;

  /// 是否可以恢复
  final bool canRecover;

  /// 恢复点（如果有）
  final SessionJournalEntry? recoveryPoint;

  /// 原因说明
  final String? reason;

  /// 建议的恢复操作
  final CrashRecoveryAction? suggestedAction;

  const CrashAnalysisResult({
    required this.hasCrashDetected,
    required this.canRecover,
    this.recoveryPoint,
    this.reason,
    this.suggestedAction,
  });
}

/// 崩溃恢复操作
enum CrashRecoveryAction {
  /// 恢复会话状态
  restoreSession,

  /// 恢复队列执行
  resumeQueue,

  /// 重置状态
  resetState,
}

/// 崩溃恢复服务 Provider
@riverpod
CrashRecoveryService crashRecoveryService(Ref ref) {
  return CrashRecoveryService();
}
