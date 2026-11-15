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
  /// 已处理的图片数（processed + skipped）
  final int processed;
  /// 有元数据的图片数（解析成功）
  final int withMetadata;
  /// 解析失败的图片数
  final int failedMetadata;
  /// 无元数据的图片数（未解析）
  final int withoutMetadata;
  /// 跳过的文件数（已扫描过且未变化）
  final int skipped;
  /// 当前正在处理的阶段
  final String currentStage;
  /// 当前处理的文件名
  final String currentFile;
  /// 元数据缓存覆盖率 (0.0 - 1.0)
  double get coverage => totalImages > 0 ? withMetadata / totalImages : 0.0;
  /// 需要处理的剩余数量（确保不为负数）
  int get remaining => totalImages > processed ? totalImages - processed : 0;

  const MetadataCacheStats({
    this.totalImages = 0,
    this.processed = 0,
    this.withMetadata = 0,
    this.failedMetadata = 0,
    this.withoutMetadata = 0,
    this.skipped = 0,
    this.currentStage = '',
    this.currentFile = '',
  });

  MetadataCacheStats copyWith({
    int? totalImages,
    int? processed,
    int? withMetadata,
    int? failedMetadata,
    int? withoutMetadata,
    int? skipped,
    String? currentStage,
    String? currentFile,
  }) {
    return MetadataCacheStats(
      totalImages: totalImages ?? this.totalImages,
      processed: processed ?? this.processed,
      withMetadata: withMetadata ?? this.withMetadata,
      failedMetadata: failedMetadata ?? this.failedMetadata,
      withoutMetadata: withoutMetadata ?? this.withoutMetadata,
      skipped: skipped ?? this.skipped,
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

  /// 计算处理进度百分比（已处理 / 总数）
  String get coveragePercentage => '${(progress * 100).toStringAsFixed(1)}%';
  
  /// 计算本次扫描新增的有元数据数量
  int get newlyParsed => cacheStats.withMetadata - baselineStats.withMetadata;
  
  /// 已处理的文件数（直接从 cacheStats 获取）
  int get processedCount => cacheStats.processed;
  
  /// 剩余未处理的文件数
  int get remainingCount => cacheStats.remaining;
  
  /// 计算各状态占总数的比例（用于彩色进度条）
  /// 返回: [跳过的比例, 有元数据的比例, 失败的比例, 处理中的比例]
  List<double> get progressSegments {
    final total = cacheStats.totalImages;
    if (total == 0) return [0.0, 0.0, 0.0, 0.0];
    
    final skipped = cacheStats.skipped / total;
    final withMetadata = cacheStats.withMetadata / total;
    final failed = cacheStats.failedMetadata / total;
    // 处理中的 = 已处理的 - 跳过的 - 有元数据的 - 失败的
    final processed = cacheStats.processed / total;
    final processing = (processed - skipped - (withMetadata - baselineStats.withMetadata / total).clamp(0.0, 1.0) - (failed - baselineStats.failedMetadata / total).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    
    return [skipped, withMetadata, failed, processing];
  }

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
class GalleryScanProgressNotifier extends Notifier<ScanProgressState> {
  StreamSubscription<ScanStatus>? _statusSubscription;
  StreamSubscription<ScanProgressInfo>? _progressSubscription;
  Timer? _hideTimer;

  @override
  ScanProgressState build() {
    _hideTimer?.cancel();
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    // 订阅 ScanStateManager 的状态变化
    _statusSubscription = ScanStateManager.instance.statusStream.listen(
      _onStatusChange,
    );
    // 订阅进度流以获取当前处理文件
    _progressSubscription = ScanStateManager.instance.progressStream.listen(
      _onProgressUpdate,
    );
    ref.onDispose(() {
      _hideTimer?.cancel();
      _statusSubscription?.cancel();
      _progressSubscription?.cancel();
    });
    return const ScanProgressState();
  }
  
  /// 处理进度更新
  void _onProgressUpdate(ScanProgressInfo progress) {
    if (!ref.mounted) return;
    final scanManager = ScanStateManager.instance;
    final total = progress.total;
    final processed = progress.processed;
    final withMetadata = scanManager.metadataCacheCount;
    final skipped = scanManager.skippedCount;
    final failed = scanManager.failedCount;
    
    // 【修复】处理文件名：如果新文件名为空，保留旧值
    final currentFile = progress.currentFile?.isNotEmpty == true
        ? progress.currentFile!
        : state.cacheStats.currentFile;
    
    // 更新状态（从 ScanStateManager 获取元数据计数）
    if (state.isScanning || scanManager.isScanning) {
      state = state.copyWith(
        isScanning: true,
        cacheStats: MetadataCacheStats(
          totalImages: total,
          processed: processed, // 【修复】添加已处理数量
          withMetadata: withMetadata,
          failedMetadata: failed, // 【修复】使用 ScanStateManager 的失败计数
          skipped: skipped, // 【新增】跳过的文件数
          currentStage: progress.phase.name,
          currentFile: currentFile,
        ),
        progress: total > 0 ? processed / total : 0.0,
      );
    }
  }

  /// 处理状态变化（从 ScanStateManager）
  void _onStatusChange(ScanStatus status) {
    if (!ref.mounted) return;
    switch (status) {
      case ScanStatus.scanning:
        if (!state.isScanning) {
          final scanManager = ScanStateManager.instance;
          // 【修复】扫描开始时，使用 ScanStateManager 中已有的元数据计数作为初始值
          final initialMetadataCount = scanManager.metadataCacheCount;
          state = state.copyWith(
            isScanning: true,
            cacheStats: MetadataCacheStats(
              totalImages: 0, // 将在第一个进度更新时设置
              processed: 0,
              withMetadata: initialMetadataCount,
              currentStage: 'scanning',
              currentFile: state.cacheStats.currentFile, // 保留之前的文件名
            ),
          );
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
      if (!ref.mounted) return;
      state = const ScanProgressState();
    });
  }

  /// 重置状态
  void reset() {
    _hideTimer?.cancel();
    state = const ScanProgressState();
  }
}

/// 全局扫描进度Provider
final galleryScanProgressProvider =
    NotifierProvider<GalleryScanProgressNotifier, ScanProgressState>(
      GalleryScanProgressNotifier.new,
    );
