import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/datasources/gallery_data_source.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../../data/services/gallery/index.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import 'cache_statistics_tile.dart';

/// 画廊重新扫描按钮
///
/// 触发全局扫描任务（与自动扫描使用同一套逻辑）：
/// - 检查数据一致性（标记不存在的文件）
/// - 查漏补缺（新文件、变更文件）
/// - 提取元数据
///
/// 注意：不清空数据，只做增量更新
class GalleryCacheActions extends ConsumerStatefulWidget {
  const GalleryCacheActions({super.key});

  @override
  ConsumerState<GalleryCacheActions> createState() =>
      _GalleryCacheActionsState();
}

class _GalleryCacheActionsState extends ConsumerState<GalleryCacheActions>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  bool _disableAnimations = false;

  bool _isScanning = false;

  // 扫描进度（来自全局 ScanStateManager）
  double? _scanProgress;
  String? _scanPhase;
  int _processedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _scanController
        ..stop()
        ..reset();
    } else if (_isScanning) {
      _scanController.repeat();
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  /// 重新扫描
  ///
  /// 触发全局扫描任务（与自动扫描使用同一套逻辑）：
  /// - 检查数据一致性（标记不存在的文件）
  /// - 查漏补缺（新文件、变更文件）
  /// - 提取元数据
  Future<void> _rescanGallery() async {
    if (_isScanning) return;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.galleryCache_rescanTitle,
      content: context.l10n.galleryCache_rescanContent,
      confirmText: context.l10n.galleryCache_startScan,
      cancelText: context.l10n.common_cancel,
      icon: Icons.refresh_rounded,
    );

    if (!confirmed) return;

    if (!mounted) return;

    // 检查是否已有扫描在进行中
    if (ScanStateManager.instance.isScanning) {
      AppToast.warning(context, context.l10n.galleryCache_scanAlreadyRunning);
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanPhase = context.l10n.galleryCache_preparing;
      _processedCount = 0;
      _totalCount = 0;
    });
    if (!_disableAnimations) _scanController.repeat();

    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();

      if (!mounted) return;

      if (rootPath == null) {
        AppToast.error(context, context.l10n.galleryCache_noGalleryFolder);
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (!mounted) return;
        AppToast.error(context, context.l10n.galleryCache_galleryFolderMissing);
        return;
      }

      // 使用流式扫描器处理文件（边扫描边处理，实时更新）
      // 这与自动扫描使用同一套逻辑
      final dataSource = GalleryDataSource();
      final scanner = GalleryStreamScanner(dataSource: dataSource);

      // 订阅统计流以实时更新UI
      final statsSubscription = scanner.statsStream.listen((stats) {
        if (!mounted) return;
        setState(() {
          _totalCount = stats.totalDiscovered;
          _processedCount = stats.processed + stats.skipped;
          _scanProgress = stats.progress;
          _scanPhase = context.l10n.galleryCache_scanningPhase(
            stats.processed + stats.skipped,
            stats.totalDiscovered,
          );
        });
      });

      await scanner.startScanning(
        dir,
        retryMissingMetadata: true,
        retryFailedMetadata: true,
        onFileProcessed: (result, stats) {
          AppLogger.d(
            '[Rescan] Processed: ${result.path.split(Platform.pathSeparator).last}, '
                'stage: ${result.stage}',
            'RescanGallery',
          );
        },
      );

      await statsSubscription.cancel();

      if (!mounted) return;

      // 刷新 Provider
      ref.invalidate(localGalleryNotifierProvider);
      ref.invalidate(cacheStatisticsProvider);

      AppToast.success(context, context.l10n.galleryCache_scanComplete);
    } catch (e, stack) {
      AppLogger.e('Rescan failed', e, stack, 'RescanGallery');
      if (!mounted) return;
      AppToast.error(context, context.l10n.galleryCache_scanFailed(e));
    } finally {
      _scanController.stop();
      _scanController.reset();
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = null;
          _scanPhase = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // 重新扫描按钮（与自动扫描使用同一套逻辑）
        ListTile(
          leading: AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return RotationTransition(
                turns: _isScanning
                    ? _scanController
                    : const AlwaysStoppedAnimation(0),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withValues(alpha: 0.2),
                        Colors.lightGreen.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isScanning
                          ? Colors.green
                          : Colors.green.withValues(alpha: 0.3),
                      width: _isScanning ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: _isScanning
                        ? Colors.green
                        : Colors.green.withValues(alpha: 0.8),
                    size: 22,
                  ),
                ),
              );
            },
          ),
          title: Text(
            context.l10n.galleryCache_rescan,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isScanning
                    ? (_scanPhase ?? context.l10n.galleryCache_scanning)
                    : context.l10n.galleryCache_rescanSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (_isScanning && _scanProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _scanProgress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                if (_totalCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$_processedCount / $_totalCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ],
          ),
          trailing: _isScanning
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.1),
                        colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.galleryCache_scanAction,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
          onTap: _isScanning ? null : _rescanGallery,
        ),
      ],
    );
  }
}
