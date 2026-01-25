import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/cooccurrence_service.dart';
import '../../core/services/tag_data_service.dart';
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

  /// 初始化标签数据
  Future<void> initializeTagData() async {
    final tagService = ref.read(tagDataServiceProvider);

    if (tagService.isInitialized) return;

    bool isDownloading = false;

    // 设置下载进度回调（只有真正下载时才会被调用）
    tagService.onDownloadProgress = (fileName, progress, message) {
      if (!isDownloading) {
        // 第一次回调，说明需要下载，添加任务
        isDownloading = true;
        _addTask('tags', _context?.l10n.download_tagsData ?? 'Tags Data');
      }
      _updateTaskProgress('tags', progress, message: message);
    };

    try {
      await tagService.initialize();
      // 只有真正下载了才显示完成提示
      if (isDownloading) {
        _completeTask('tags');
      }
    } catch (e) {
      if (isDownloading) {
        _failTask('tags', e.toString());
      }
    }
  }

  /// 下载共现标签数据（可选）
  Future<bool> downloadCooccurrenceData() async {
    final cooccurrenceService = ref.read(cooccurrenceServiceProvider);

    if (cooccurrenceService.isLoaded) return true;
    if (cooccurrenceService.isDownloading) return false;

    // 先尝试从缓存加载
    final cacheLoaded = await cooccurrenceService.initialize();
    if (cacheLoaded) {
      return true; // 缓存已存在，无需下载
    }

    // 缓存不存在，需要下载
    // 添加下载任务
    _addTask(
      'cooccurrence',
      _context?.l10n.download_cooccurrenceData ?? 'Cooccurrence Data',
    );

    // 设置下载进度回调
    cooccurrenceService.onDownloadProgress = (progress, message) {
      _updateTaskProgress('cooccurrence', progress, message: message);
    };

    try {
      final success = await cooccurrenceService.download();
      if (success) {
        _completeTask('cooccurrence');
      } else {
        _failTask('cooccurrence', '下载失败');
      }
      return success;
    } catch (e) {
      _failTask('cooccurrence', e.toString());
      return false;
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

  /// 更新任务进度
  void _updateTaskProgress(String id, double progress, {String? message}) {
    final task = state.tasks[id];
    if (task == null) return;

    // 将消息 key 转换为本地化字符串
    final localizedMessage = _context != null && message != null
        ? DownloadMessageKeys.localizeMessage(_context!, message)
        : message;

    state = state.copyWith(
      tasks: {
        ...state.tasks,
        id: task.copyWith(progress: progress, message: localizedMessage),
      },
    );

    // 更新 Toast
    _toastController?.updateProgress(
      progress,
      message: localizedMessage,
      subtitle: '${(progress * 100).toInt()}%',
    );
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

    // 失败 Toast
    if (_context != null) {
      _toastController?.fail(
        message: _context!.l10n.download_failed(task.name),
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
