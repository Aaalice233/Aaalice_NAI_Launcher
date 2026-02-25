import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/gallery_cache_manager.dart';
import '../../../../core/database/datasources/gallery_data_source.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../../data/services/gallery/gallery_stream_scanner.dart';
import '../../../../data/services/gallery/index.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import 'cache_statistics_tile.dart';

/// 画廊重建索引按钮
/// 
/// 一键完成：清空数据库 + 重新扫描所有文件 + 自动提取元数据
class GalleryCacheActions extends ConsumerStatefulWidget {
  const GalleryCacheActions({super.key});

  @override
  ConsumerState<GalleryCacheActions> createState() => _GalleryCacheActionsState();
}

class _GalleryCacheActionsState extends ConsumerState<GalleryCacheActions>
    with TickerProviderStateMixin {
  late AnimationController _rebuildController;
  
  bool _isRebuilding = false;
  bool _isFixingConsistency = false;
  
  // 重建进度
  double? _rebuildProgress;
  String? _rebuildPhase;
  int _processedCount = 0;
  int _totalCount = 0;
  
  // 修复进度
  int _fixedCount = 0;
  int _checkedCount = 0;

  @override
  void initState() {
    super.initState();
    _rebuildController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rebuildController.dispose();
    super.dispose();
  }

  /// 修复数据一致性
  /// 
  /// 检查数据库中所有标记为未删除的记录，如果文件不存在则标记为已删除
  Future<void> _fixDataConsistency() async {
    if (_isFixingConsistency) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.healing_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('修复数据一致性'),
        content: const Text(
          '这将执行以下操作：\n\n'
          '1. 扫描数据库中的所有图片记录\n'
          '2. 检查每个文件是否实际存在\n'
          '3. 标记不存在的文件为已删除\n\n'
          '此操作不会删除任何图片文件，只是更新数据库状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.healing),
            label: const Text('开始修复'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() {
      _isFixingConsistency = true;
      _fixedCount = 0;
      _checkedCount = 0;
    });

    try {
      final dataSource = GalleryDataSource();
      final scanService = GalleryScanService(dataSource: dataSource);
      
      final result = await scanService.fixDataConsistency(
        onProgress: ({required processed, required total, currentFile, required phase, filesSkipped, confirmed}) {
          if (mounted) {
            setState(() {
              _checkedCount = processed;
              _totalCount = total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _fixedCount = result.filesDeleted;
        _isFixingConsistency = false;
      });

      // 刷新统计
      ref.invalidate(cacheStatisticsProvider);
      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (result.filesDeleted > 0) {
        AppToast.success(context, '修复完成：已标记 ${result.filesDeleted} 个失效记录');
      } else {
        AppToast.success(context, '数据一致性良好，无需修复');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFixingConsistency = false);
      AppLogger.e('Data consistency fix failed', e, null, 'GalleryCacheActions');
      AppToast.error(context, '修复失败: $e');
    }
  }

  /// 重建索引（清空 + 扫描 + 提取元数据）
  Future<void> _rebuildIndex() async {
    if (_isRebuilding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.refresh_rounded,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('重建画廊索引'),
        content: const Text(
          '这将执行以下操作：\n\n'
          '1. 清空数据库中的现有索引\n'
          '2. 重新扫描所有图片文件\n'
          '3. 自动提取所有 PNG 的元数据\n\n'
          '此操作不会删除图片文件，但可能需要几分钟完成。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.refresh),
            label: const Text('开始重建'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    
    final currentContext = context;
    
    // 检查是否已有扫描在进行中
    if (ScanStateManager.instance.isScanning) {
      if (currentContext.mounted) {
        AppToast.warning(currentContext, '已有扫描任务在进行中，请等待完成后再试');
      }
      return;
    }

    setState(() {
      _isRebuilding = true;
      _rebuildProgress = 0.0;
      _rebuildPhase = '准备中...';
      _processedCount = 0;
      _totalCount = 0;
    });
    _rebuildController.repeat();

    try {
      // 步骤1：清空所有缓存（L1内存 + L2 Hive + L3数据库）
      setState(() => _rebuildPhase = '正在清空旧索引...');
      
      // 清除 L1/L2 缓存
      await GalleryCacheManager().clearAll();
      
      // 清除 L3 数据库
      final dataSource = GalleryDataSource();
      await dataSource.execute('clearAllForRebuild', (db) async {
        await db.delete('gallery_images');
        await db.delete('gallery_metadata');
      });
      
      // 清除断点续传状态（避免增量扫描跳过文件）
      await ScanStateManager.instance.clearCheckpoint();
      AppLogger.i('All caches and checkpoints cleared for rebuild', 'RebuildIndex');

      // 步骤2：获取所有文件
      setState(() => _rebuildPhase = '正在扫描文件...');
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      
      if (!mounted) return;
      
      if (rootPath == null) {
        AppToast.error(context, '未设置画廊目录');
        return;
      }

      final dir = Directory(rootPath);
      if (!await dir.exists()) {
        if (!mounted) return;
        AppToast.error(context, '画廊目录不存在');
        return;
      }

      // 步骤3：使用流式扫描器处理文件（边扫描边处理，实时更新）
      setState(() => _rebuildPhase = '开始流式扫描...');
      
      final scanner = GalleryStreamScanner(dataSource: dataSource);
      var processedFiles = 0;
      var addedFiles = 0;
      
      // 订阅统计流以实时更新UI
      final statsSubscription = scanner.statsStream.listen((stats) {
        if (!mounted) return;
        setState(() {
          _totalCount = stats.totalDiscovered;
          _processedCount = stats.processed + stats.skipped;
          _rebuildProgress = stats.progress;
          _rebuildPhase = '正在重建 ${stats.processed + stats.skipped}/${stats.totalDiscovered}...';
        });
      });

      await scanner.startScanning(
        dir,
        onFileProcessed: (result, stats) {
          if (result.stage == FileProcessingStage.completed) {
            processedFiles++;
            if (result.isNewFile) addedFiles++;
          }
          AppLogger.d(
            '[Rebuild] Processed: ${result.path.split(Platform.pathSeparator).last}, '
            'stage: ${result.stage}',
            'RebuildIndex',
          );
        },
      );

      await statsSubscription.cancel();

      if (!mounted) return;

      // 步骤4：刷新 Provider（这会触发缓存统计更新）
      ref.invalidate(localGalleryNotifierProvider);
      ref.invalidate(cacheStatisticsProvider);

      AppToast.success(
        context,
        '重建完成！已处理 $processedFiles 张图片',
      );

      AppLogger.i(
        'Rebuild completed: $processedFiles files processed, $addedFiles added',
        'RebuildIndex',
      );
    } catch (e, stack) {
      AppLogger.e('Rebuild failed', e, stack, 'RebuildIndex');
      if (!mounted) return;
      AppToast.error(context, '重建失败: $e');
    } finally {
      _rebuildController.stop();
      _rebuildController.reset();
      if (mounted) {
        setState(() {
          _isRebuilding = false;
          _rebuildProgress = null;
          _rebuildPhase = null;
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
        // 重建索引按钮
        ListTile(
      leading: AnimatedBuilder(
        animation: _rebuildController,
        builder: (context, child) {
          return RotationTransition(
            turns: _isRebuilding ? _rebuildController : const AlwaysStoppedAnimation(0),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.2),
                    Colors.lightGreen.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRebuilding
                      ? Colors.green
                      : Colors.green.withOpacity(0.3),
                  width: _isRebuilding ? 2 : 1,
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: _isRebuilding ? Colors.green : Colors.green.withOpacity(0.8),
                size: 22,
              ),
            ),
          );
        },
      ),
      title: Text(
        '重建索引',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isRebuilding
                ? (_rebuildPhase ?? '正在重建...')
                : '清空数据库并重新扫描所有图片',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (_isRebuilding && _rebuildProgress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _rebuildProgress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              borderRadius: BorderRadius.circular(4),
            ),
            if (_totalCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$_processedCount / $_totalCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ],
      ),
      trailing: _isRebuilding
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '重建',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
      onTap: _isRebuilding ? null : _rebuildIndex,
    ),
    const Divider(height: 1),
    // 修复数据一致性按钮
    ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withOpacity(0.2),
              Colors.amber.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFixingConsistency
                ? Colors.orange
                : Colors.orange.withOpacity(0.3),
            width: _isFixingConsistency ? 2 : 1,
          ),
        ),
        child: Icon(
          Icons.healing_rounded,
          color: _isFixingConsistency ? Colors.orange : Colors.orange.withOpacity(0.8),
          size: 22,
        ),
      ),
      title: Text(
        '修复数据一致性',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFixingConsistency
                ? '正在检查: $_checkedCount / $_totalCount'
                : _fixedCount > 0
                    ? '上次修复标记了 $_fixedCount 个失效记录'
                    : '标记数据库中不存在的文件为已删除',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (_isFixingConsistency) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _totalCount > 0 ? _checkedCount / _totalCount : null,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
      trailing: _isFixingConsistency
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.healing,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '修复',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
      onTap: _isFixingConsistency ? null : _fixDataConsistency,
    ),
      ],
    );
  }
}
