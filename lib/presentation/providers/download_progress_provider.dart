import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/services/services.dart';
import '../../core/utils/app_logger.dart';

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
  @override
  DownloadProgressState build() {
    return const DownloadProgressState();
  }

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
