import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/services/services.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/download_message_keys.dart';
import '../../core/utils/localization_extension.dart';
import '../widgets/common/app_toast.dart';

part 'download_progress_provider.g.dart';

/// 下载任务状态
enum DownloadTaskStatus {
  pending,
  downloading,
  completed,
  failed,
}

/// 下载任务
class DownloadTask {
  final String id;
  final String name;
  final DownloadTaskStatus status;
  final double progress;
  final String? message;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.name,
    this.status = DownloadTaskStatus.pending,
    this.progress = 0,
    this.message,
    this.error,
  });

  DownloadTask copyWith({
    String? id,
    String? name,
    DownloadTaskStatus? status,
    double? progress,
    String? message,
    String? error,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}

/// 下载进度状态
class DownloadProgressState {
  final Map<String, DownloadTask> tasks;
  final bool isDownloading;

  const DownloadProgressState({
    this.tasks = const {},
    this.isDownloading = false,
  });

  DownloadProgressState copyWith({
    Map<String, DownloadTask>? tasks,
    bool? isDownloading,
  }) {
    return DownloadProgressState(
      tasks: tasks ?? this.tasks,
      isDownloading: isDownloading ?? this.isDownloading,
    );
  }

  /// 获取当前正在下载的任务
  DownloadTask? get currentTask {
    try {
      return tasks.values.firstWhere(
        (t) => t.status == DownloadTaskStatus.downloading,
      );
    } catch (_) {
      return null;
    }
  }

  /// 是否有正在下载的任务
  bool get hasActiveDownload =>
      tasks.values.any((t) => t.status == DownloadTaskStatus.downloading);
}

/// 下载进度管理器
@riverpod
class DownloadProgressNotifier extends _$DownloadProgressNotifier {
  ToastController? _toastController;
  BuildContext? _context;

  @override
  DownloadProgressState build() {
    return const DownloadProgressState();
  }

  /// 设置上下文（用于显示 Toast）
  void setContext(BuildContext context) {
    _context = context;
  }

  /// 上次报告的进度里程碑（用于去重）
  int _lastReportedProgressMilestone = -1;

  /// 下载共现标签数据（简化版 - 预打包数据库无需下载）
  ///
  /// 注意：当前使用预打包数据库，此方法仅初始化服务并返回状态。
  /// [force] 参数保留用于向后兼容，但不再使用。
  Future<bool> downloadCooccurrenceData({bool force = false}) async {
    final cooccurrenceService =
        await ref.watch(cooccurrenceServiceProvider.future);

    AppLogger.i(
      'downloadCooccurrenceData called: isLoaded=${cooccurrenceService.isLoaded}, force=$force',
      'DownloadProgress',
    );

    // 预打包数据库，只需初始化即可
    if (!cooccurrenceService.isLoaded) {
      final initialized = await cooccurrenceService.initialize();
      AppLogger.i(
        'Cooccurrence service initialized: $initialized',
        'DownloadProgress',
      );
      return initialized;
    }

    return true;
  }

  /// 上次报告的消息（用于检测消息变化）
  String? _lastReportedMessage;

  /// 更新任务进度（带10%去重，但消息变化时立即更新）
  void _updateTaskProgressWithDeduplication(
    String id,
    double progress, {
    String? message,
  }) {
    final task = state.tasks[id];
    if (task == null) return;

    final percent = (progress * 100).toInt();
    final milestone = (percent ~/ 10) * 10; // 0, 10, 20, ..., 100

    // 检测消息是否变化
    final messageChanged = message != null && message != _lastReportedMessage;

    // 更新内部状态（每次进度都更新）
    state = state.copyWith(
      tasks: {
        ...state.tasks,
        id: task.copyWith(progress: progress, message: message),
      },
    );

    // 去重：只在跨越10%边界或消息变化时更新Toast
    if (milestone > _lastReportedProgressMilestone || messageChanged) {
      _lastReportedProgressMilestone = milestone;
      if (message != null) {
        _lastReportedMessage = message;
      }

      // 将消息 key 转换为本地化字符串
      final localizedMessage = _context != null && message != null
          ? DownloadMessageKeys.localizeMessage(_context!, message)
          : message;

      // 更新 Toast
      _toastController?.updateProgress(
        progress,
        message: localizedMessage ?? '共现标签数据下载中...',
      );
    }
  }

  /// 添加下载任务
  void _addTask(String id, String name) {
    final task = DownloadTask(
      id: id,
      name: name,
      status: DownloadTaskStatus.downloading,
    );

    state = state.copyWith(
      tasks: {...state.tasks, id: task},
      isDownloading: true,
    );

    // 显示 Toast
    if (_context != null) {
      _toastController?.dismiss();
      _toastController = AppToast.showProgress(
        _context!,
        _context!.l10n.download_downloading(name),
        progress: 0,
      );
    }
  }

  /// 完成任务
  void _completeTask(String id) {
    final task = state.tasks[id];
    if (task == null) return;

    state = state.copyWith(
      tasks: {
        ...state.tasks,
        id: task.copyWith(status: DownloadTaskStatus.completed, progress: 1.0),
      },
      isDownloading: state.tasks.values
          .where((t) => t.id != id)
          .any((t) => t.status == DownloadTaskStatus.downloading),
    );

    // 完成 Toast
    if (_context != null) {
      // 共现数据使用导入完成提示，其他使用下载完成提示
      final message = id == 'cooccurrence'
          ? _context!.l10n.import_completed(task.name)
          : _context!.l10n.download_completed(task.name);
      _toastController?.complete(message: message);
    }
    _toastController = null;
  }

  /// 任务失败
  void _failTask(String id, String error) {
    final task = state.tasks[id];
    if (task == null) return;

    state = state.copyWith(
      tasks: {
        ...state.tasks,
        id: task.copyWith(status: DownloadTaskStatus.failed, error: error),
      },
      isDownloading: state.tasks.values
          .where((t) => t.id != id)
          .any((t) => t.status == DownloadTaskStatus.downloading),
    );

    // 失败 Toast - 显示简要错误信息
    if (_context != null) {
      var errorMsg = error;
      // 截断过长的错误信息
      if (errorMsg.length > 50) {
        errorMsg = '${errorMsg.substring(0, 50)}...';
      }
      _toastController?.fail(
        message: '${_context!.l10n.download_failed(task.name)}\n$errorMsg',
      );
    }
    _toastController = null;
  }

  /// 清除已完成的任务
  void clearCompletedTasks() {
    state = state.copyWith(
      tasks: Map.fromEntries(
        state.tasks.entries.where(
          (e) =>
              e.value.status != DownloadTaskStatus.completed &&
              e.value.status != DownloadTaskStatus.failed,
        ),
      ),
    );
  }
}
