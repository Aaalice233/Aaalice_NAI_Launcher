import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/gallery_scan_progress_provider.dart';

const _galleryProgressFlexScale = 1000;
const _galleryProgressStripeWidth = 8.0;
const _galleryProgressStripeGap = 8.0;
const _maxGalleryProgressStripeCount = 4096;

/// Converts a visible progress ratio to a valid [FlexParentData.flex] value.
///
/// Tiny non-zero segments still need a flex of at least one. A zero flex is
/// laid out as a non-flex child by [RenderFlex], which gives it an unbounded
/// main-axis constraint.
@visibleForTesting
int galleryProgressSegmentFlex(double ratio) {
  if (!ratio.isFinite || ratio <= 0) return 0;
  return (ratio * _galleryProgressFlexScale)
      .round()
      .clamp(1, _galleryProgressFlexScale)
      .toInt();
}

/// Returns a finite amount of stripe work for the supplied paint width.
@visibleForTesting
int galleryProgressStripeCountForWidth(double width) {
  if (!width.isFinite || width <= 0) return 0;

  const spacing = _galleryProgressStripeWidth + _galleryProgressStripeGap;
  const maxWidthBeforeCap = (_maxGalleryProgressStripeCount - 1) * spacing;
  if (width >= maxWidthBeforeCap) return _maxGalleryProgressStripeCount;

  return ((width + spacing) / spacing).ceil();
}

/// Rejects invalid paint bounds before any stripe work is attempted.
@visibleForTesting
int galleryProgressStripeCountForSize(Size size) {
  if (!size.width.isFinite ||
      size.width <= 0 ||
      !size.height.isFinite ||
      size.height <= 0) {
    return 0;
  }
  return galleryProgressStripeCountForWidth(size.width);
}

/// 画廊扫描进度面板
///
/// 显示流式扫描的实时状态：
/// - 总发现文件数（动态增长）
/// - 当前处理阶段（单文件流水线）
/// - 元数据缓存统计（实时更新）
class GalleryScanProgressPanel extends ConsumerWidget {
  const GalleryScanProgressPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(galleryScanProgressProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 只有在扫描中或刚完成时显示
    if (!scanState.isScanning) {
      return const SizedBox.shrink();
    }

    final stats = scanState.cacheStats;
    final progress = scanState.progress;
    // 使用处理进度百分比（processed/total），而非覆盖率
    final percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：状态 + 覆盖率
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.localGallery_cachingMetadata,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percentage%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 彩色分段进度条
          _buildSegmentedProgressBar(theme, scanState),
          const SizedBox(height: 6),
          // 进度条图例
          _buildProgressLegend(context, theme, scanState),
          const SizedBox(height: 8),
          // 当前阶段标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stats.currentStage,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              // 处理进度计数
              Text(
                '${scanState.processedCount} / ${stats.totalImages}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 元数据缓存统计
          _buildMetadataStatsCard(context, theme, stats),
          // 当前文件名
          if (stats.currentFile.isNotEmpty)
            _buildCurrentFile(theme, stats.currentFile),
        ],
      ),
    );
  }

  /// 构建元数据缓存统计卡片
  Widget _buildMetadataStatsCard(
    BuildContext context,
    ThemeData theme,
    MetadataCacheStats stats,
  ) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.localGallery_metadataCacheStats,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 四列统计（新增跳过列）
          Row(
            children: [
              Expanded(
                child: _buildStatColumn(
                  theme,
                  label: l10n.localGallery_totalImages,
                  value: '${stats.totalImages}',
                  icon: Icons.photo_library_outlined,
                ),
              ),
              Expanded(
                child: _buildStatColumn(
                  theme,
                  label: l10n.localGallery_withMetadata,
                  value: '${stats.withMetadata}',
                  icon: Icons.check_circle_outline,
                  valueColor: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatColumn(
                  theme,
                  label: l10n.localGallery_skipped,
                  value: '${stats.skipped}',
                  icon: Icons.skip_next_outlined,
                  valueColor: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatColumn(
                  theme,
                  label: l10n.localGallery_remaining,
                  value: '${stats.remaining}',
                  icon: Icons.pending_outlined,
                  valueColor: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建单列统计
  Widget _buildStatColumn(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// 构建当前文件名显示
  Widget _buildCurrentFile(ThemeData theme, String filePath) {
    final fileName = filePath.split('/').last.split('\\').last;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 12,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fileName,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建彩色分段进度条
  ///
  /// 使用不同颜色显示不同状态的文件：
  /// - 绿色：已扫描过且跳过（缓存命中）
  /// - 蓝色：有元数据（解析成功）
  /// - 红色：扫描错误
  /// - 灰色/默认：待处理
  Widget _buildSegmentedProgressBar(
    ThemeData theme,
    ScanProgressState scanState,
  ) {
    final stats = scanState.cacheStats;
    final total = stats.totalImages;

    if (total == 0) {
      // 初始状态显示灰色进度条
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: null, // 不确定进度
          minHeight: 8,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    // 计算各状态的比例
    final skippedRatio = stats.skipped / total;
    final withMetadataRatio = stats.withMetadata / total;
    final failedRatio = stats.failedMetadata / total;
    final processedRatio = stats.processed / total;

    // 当前正在处理的部分 = 已处理 - 已分类
    final processingRatio =
        (processedRatio - skippedRatio - withMetadataRatio - failedRatio).clamp(
          0.0,
          1.0,
        );

    // 待处理的部分
    final pendingRatio = (1.0 - processedRatio).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            // 绿色：跳过的（已扫描过，缓存命中）
            ..._buildProgressSegment(
              ratio: skippedRatio,
              child: Container(color: Colors.green.shade400),
            ),
            // 蓝色：有元数据的（解析成功）
            ..._buildProgressSegment(
              ratio: withMetadataRatio,
              child: Container(color: Colors.blue.shade400),
            ),
            // 红色：扫描错误的
            ..._buildProgressSegment(
              ratio: failedRatio,
              child: Container(color: Colors.red.shade400),
            ),
            // 紫色：正在处理的
            ..._buildProgressSegment(
              ratio: processingRatio,
              child: Container(
                color: theme.colorScheme.primary,
                child: const _AnimatedStripes(),
              ),
            ),
            // 灰色：待处理的
            ..._buildProgressSegment(
              ratio: pendingRatio,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProgressSegment({
    required double ratio,
    required Widget child,
  }) {
    final flex = galleryProgressSegmentFlex(ratio);
    if (flex == 0) return const [];
    return [Expanded(flex: flex, child: child)];
  }

  /// 构建进度条图例
  Widget _buildProgressLegend(
    BuildContext context,
    ThemeData theme,
    ScanProgressState scanState,
  ) {
    final stats = scanState.cacheStats;
    final l10n = context.l10n;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (stats.skipped > 0)
          _buildLegendItem(
            Colors.green.shade400,
            l10n.galleryScan_skipped(stats.skipped),
          ),
        if (stats.withMetadata > 0)
          _buildLegendItem(
            Colors.blue.shade400,
            l10n.galleryScan_withMetadata(stats.withMetadata),
          ),
        if (stats.failedMetadata > 0)
          _buildLegendItem(
            Colors.red.shade400,
            l10n.galleryScan_failed(stats.failedMetadata),
          ),
        _buildLegendItem(
          theme.colorScheme.primary,
          l10n.galleryScan_processing,
        ),
        _buildLegendItem(
          theme.colorScheme.surfaceContainerHighest,
          l10n.galleryScan_pending,
        ),
      ],
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// 动画条纹效果（表示处理中）
class _AnimatedStripes extends StatefulWidget {
  const _AnimatedStripes();

  @override
  State<_AnimatedStripes> createState() => _AnimatedStripesState();
}

class _AnimatedStripesState extends State<_AnimatedStripes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StripesPainter(
          progress: _controller,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 条纹绘制器
class _StripesPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _StripesPainter({required this.progress, required this.color})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final stripeCount = galleryProgressStripeCountForSize(size);
    if (stripeCount == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const spacing = _galleryProgressStripeWidth + _galleryProgressStripeGap;
    final offset = progress.value * spacing;

    for (var index = 0; index < stripeCount; index++) {
      final x = -_galleryProgressStripeWidth + index * spacing;
      canvas.drawLine(
        Offset(x + offset, 0),
        Offset(x + offset - _galleryProgressStripeWidth / 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
