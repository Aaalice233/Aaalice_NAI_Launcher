import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../data/services/gallery/scan_state_manager.dart';

/// 元数据缓存统计
/// 
/// 统一显示本地画廊的元数据缓存状态
class MetadataCacheStats {
  /// 总图片数（流式扫描中动态更新）
  final int totalImages;
  /// 有元数据的图片数（解析成功）
  final int withMetadata;
  /// 解析失败的图片数
  final int failedMetadata;
  /// 无元数据的图片数（未解析）
  final int withoutMetadata;
  /// 当前正在处理的阶段
  final String currentStage;
  /// 当前处理的文件名
  final String currentFile;
  /// 元数据缓存覆盖率 (0.0 - 1.0)
  double get coverage => totalImages > 0 ? withMetadata / totalImages : 0.0;
  /// 需要处理的剩余数量
  int get remaining => totalImages - withMetadata;

  const MetadataCacheStats({
    this.totalImages = 0,
    this.withMetadata = 0,
    this.failedMetadata = 0,
    this.withoutMetadata = 0,
    this.currentStage = '',
    this.currentFile = '',
  });

  MetadataCacheStats copyWith({
    int? totalImages,
    int? withMetadata,
    int? failedMetadata,
    int? withoutMetadata,
    String? currentStage,
    String? currentFile,
  }) {
    return MetadataCacheStats(
      totalImages: totalImages ?? this.totalImages,
      withMetadata: withMetadata ?? this.withMetadata,
      failedMetadata: failedMetadata ?? this.failedMetadata,
      withoutMetadata: withoutMetadata ?? this.withoutMetadata,
      currentStage: currentStage ?? this.currentStage,
      currentFile: currentFile ?? this.currentFile,
    );
  }

}

/// 扫描进度状态 - 流式扫描视角
/// 
/// 实时反映单文件流水线的处理状态
class ScanProgressState {
  final bool isScanning;
  /// 元数据缓存统计（实时更新）
  final MetadataCacheStats cacheStats;
  /// 本次扫描前的基准统计
  final MetadataCacheStats baselineStats;
  /// 当前进度 (0.0 - 1.0)
  final double progress;
  final List<String> errors;

  const ScanProgressState({
    this.isScanning = false,
    this.cacheStats = const MetadataCacheStats(),
    this.baselineStats = const MetadataCacheStats(),
    this.progress = 0.0,
    this.errors = const [],
  });

  /// 计算覆盖率百分比
  String get coveragePercentage => '${(cacheStats.coverage * 100).toStringAsFixed(1)}%';
  
  /// 计算本次扫描新增的有元数据数量
  int get newlyParsed => cacheStats.withMetadata - baselineStats.withMetadata;
  
  /// 计算已处理的文件数
  int get processedCount => cacheStats.withMetadata + cacheStats.failedMetadata;

  ScanProgressState copyWith({
    bool? isScanning,
    MetadataCacheStats? cacheStats,
    MetadataCacheStats? baselineStats,
    double? progress,
    List<String>? errors,
  }) {
    return ScanProgressState(
      isScanning: isScanning ?? this.isScanning,
      cacheStats: cacheStats ?? this.cacheStats,
      baselineStats: baselineStats ?? this.baselineStats,
      progress: progress ?? this.progress,
      errors: errors ?? this.errors,
    );
  }
}

/// 画廊扫描进度Provider
///
/// 使用流式扫描器实时接收单文件处理状态
class GalleryScanProgressNotifier extends StateNotifier<ScanProgressState> {
  StreamSubscription<ScanStatus>? _statusSubscription;
  StreamSubscription<ScanProgressInfo>? _progressSubscription;
  Timer? _hideTimer;

  GalleryScanProgressNotifier() : super(const ScanProgressState()) {
    // 订阅 ScanStateManager 的状态变化
    _statusSubscription = ScanStateManager.instance.statusStream.listen(_onStatusChange);
    // 订阅进度流以获取当前处理文件
    _progressSubscription = ScanStateManager.instance.progressStream.listen(_onProgressUpdate);
  }
  
  /// 处理进度更新
  void _onProgressUpdate(ScanProgressInfo progress) {
    final scanManager = ScanStateManager.instance;
    final total = progress.total;
    final processed = progress.processed;
    final withMetadata = scanManager.metadataCacheCount;
    
    // 更新状态（从 ScanStateManager 获取元数据计数）
    if (state.isScanning || scanManager.isScanning) {
      state = state.copyWith(
        isScanning: true,
        cacheStats: MetadataCacheStats(
          totalImages: total,
          withMetadata: withMetadata,
          failedMetadata: state.cacheStats.failedMetadata,
          currentStage: progress.phase.name,
          currentFile: progress.currentFile ?? state.cacheStats.currentFile,
        ),
        progress: total > 0 ? processed / total : 0.0,
      );
    }
  }

  /// 处理状态变化（从 ScanStateManager）
  void _onStatusChange(ScanStatus status) {
    switch (status) {
      case ScanStatus.scanning:
        if (!state.isScanning) {
          state = state.copyWith(isScanning: true);
        }
        break;
      case ScanStatus.completed:
        if (state.isScanning) {
          completeScan();
        }
        break;
      case ScanStatus.error:
      case ScanStatus.cancelled:
        if (state.isScanning) {
          state = state.copyWith(isScanning: false);
        }
        break;
      default:
        break;
    }
  }

  /// 完成扫描
  void completeScan() {
    state = state.copyWith(isScanning: false);
    AppLogger.i(
      '[ScanProgress] Scan completed: ${state.cacheStats.withMetadata}/${state.cacheStats.totalImages}',
      'GalleryScanProgress',
    );

    // 3秒后自动隐藏进度条
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      state = const ScanProgressState();
    });
  }

  /// 重置状态
  void reset() {
    _hideTimer?.cancel();
    state = const ScanProgressState();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
}

/// 全局扫描进度Provider
final galleryScanProgressProvider =
    StateNotifierProvider<GalleryScanProgressNotifier, ScanProgressState>(
  (ref) => GalleryScanProgressNotifier(),
);
