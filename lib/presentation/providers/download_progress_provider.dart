import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/cooccurrence_service.dart';
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

  /// 下载共现标签数据（支持首次下载和刷新）
  ///
  /// [force] 是否强制下载，忽略刷新间隔检查
  Future<bool> downloadCooccurrenceData({bool force = false}) async {
    final cooccurrenceService = ref.read(cooccurrenceServiceProvider);

    AppLogger.i(
        'downloadCooccurrenceData called: isDownloading=${cooccurrenceService.isDownloading}, isLoaded=${cooccurrenceService.isLoaded}, force=$force',
        'DownloadProgress',);

    if (cooccurrenceService.isDownloading) {
      AppLogger.w(
          'Cooccurrence is already downloading, skip', 'DownloadProgress',);
      return false;
    }

    // 启动期默认使用懒加载 + SQLite 模式。
    // 该模式下若立即触发完整缓存加载，会在进入主页时出现明显卡顿。
    // 非强制刷新时直接跳过，由用户手动刷新（force=true）或后续后台策略触发。
    final isLazyMode =
        cooccurrenceService.loadMode == CooccurrenceLoadMode.lazy;
    if (!force && isLazyMode) {
      AppLogger.i(
        'Skip cooccurrence full bootstrap in lazy mode to avoid UI freeze on startup',
        'DownloadProgress',
      );
      return true;
    }

    // 检查是否需要下载/刷新
    if (!force) {
      // 1. 如果已经加载且不需要刷新，跳过
      if (cooccurrenceService.isLoaded) {
        final needsRefresh = await cooccurrenceService.shouldRefresh();
        AppLogger.i('Cooccurrence isLoaded=true, needsRefresh=$needsRefresh',
            'DownloadProgress',);
        if (!needsRefresh) {
          return true; // 数据新鲜，无需刷新
        }
      }

      // 2. 尝试从缓存加载
      AppLogger.i(
          'Trying to load cooccurrence from cache...', 'DownloadProgress',);
      final cacheLoaded = await cooccurrenceService.initialize();
      AppLogger.i(
          'Cooccurrence cache loaded: $cacheLoaded', 'DownloadProgress',);
      if (cacheLoaded) {
        // 缓存加载成功，检查是否需要刷新
        final needsRefresh = await cooccurrenceService.shouldRefresh();
        if (!needsRefresh) {
          return true; // 缓存数据新鲜，无需下载
        }
        // 缓存存在但需要刷新，继续下载
      }
    }

    // 使用新的后台导入流程替代下载
    AppLogger.i('Starting cooccurrence import...', 'DownloadProgress');
    _lastReportedProgressMilestone = -1;
    _lastReportedMessage = null;

    // 添加导入任务
    _addTask(
      'cooccurrence',
      _context?.l10n.download_cooccurrenceData ?? 'Cooccurrence Data',
    );

    // 设置导入进度回调（带10%去重）
    cooccurrenceService.onProgress = (progress, message) {
      _updateTaskProgressWithDeduplication(
        'cooccurrence',
        progress,
        message: message,
      );
    };

    try {
      await cooccurrenceService.performBackgroundImport(
        onProgress: cooccurrenceService.onProgress,
      );
      _completeTask('cooccurrence');
      return true;
    } catch (e) {
      _failTask('cooccurrence', e.toString());
      return false;
    }
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
        subtitle: '$milestone%',
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
      _toastController?.complete(
        message: _context!.l10n.download_completed(task.name),
      );
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
