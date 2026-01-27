import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../data/repositories/local_gallery_repository.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../providers/collection_provider.dart';
import '../../providers/bulk_operation_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../widgets/local_image_card.dart';
import '../../widgets/gallery_filter_panel.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/bulk_export_dialog.dart';
import '../../widgets/bulk_metadata_edit_dialog.dart';
import '../../widgets/collection_select_dialog.dart';

/// 本地画廊屏幕
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  /// Key for accessing GroupedGridView's scrollToGroup method
  /// 用于访问 GroupedGridView 的 scrollToGroup 方法的键
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey =
      GlobalKey<GroupedGridViewState>();

  /// Focus node for keyboard shortcuts
  /// 用于键盘快捷键的焦点节点
  final FocusNode _shortcutsFocusNode = FocusNode();

  /// 宽高比缓存
  /// Aspect ratio cache for storing calculated aspect ratios
  final Map<String, double> _aspectRatioCache = {};

  @override
  void initState() {
    super.initState();
    // 首次加载时检查权限并扫描图片
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _shortcutsFocusNode.dispose();
    super.dispose();
  }

  /// 搜索防抖
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
    });
  }

  /// 批量加入队列
  Future<void> _addSelectedToQueue() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final tasks = selectedImages
        .where((img) => img.metadata?.prompt.isNotEmpty == true)
        .map(
          (img) => ReplicationTask.create(
            prompt: img.metadata!.prompt,
            thumbnailUrl: img.path, // 本地路径
            source: ReplicationTaskSource.local,
          ),
        )
        .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的图片没有 Prompt 信息')),
      );
      return;
    }

    final addedCount =
        await ref.read(replicationQueueNotifierProvider.notifier).addAll(tasks);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $addedCount 个任务到队列')),
      );
      ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    }
  }

  /// 批量删除选中的图片
  Future<void> _deleteSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text(
          '确定要删除选中的 ${selectedImages.length} 张图片吗？\n\n'
          '此操作将从文件系统中永久删除这些图片，无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 存储已删除图片信息，用于撤销
    final deletedImages = <LocalImageRecord>[];
    final deleteErrors = <String>[];

    try {
      // 删除文件
      for (final image in selectedImages) {
        try {
          final file = File(image.path);
          if (await file.exists()) {
            await file.delete();
            deletedImages.add(image);
          }
        } catch (e) {
          deleteErrors.add('${path.basename(image.path)}: $e');
        }
      }

      // 退出选择模式
      ref.read(localGallerySelectionNotifierProvider.notifier).exit();

      // 刷新画廊
      await ref.read(localGalleryNotifierProvider.notifier).refresh();

      // 显示成功提示和撤销按钮
      if (mounted && deletedImages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 ${deletedImages.length} 张图片'),
            duration: const Duration(seconds: 5),
            action: deletedImages.length <= 50
                ? SnackBarAction(
                    label: '撤销',
                    onPressed: () => _restoreDeletedImages(deletedImages),
                  )
                : null,
          ),
        );
      }

      // 显示错误提示
      if (deleteErrors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deleteErrors.length} 张图片删除失败'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 恢复已删除的图片（撤销操作）
  Future<void> _restoreDeletedImages(List<LocalImageRecord> deletedImages) async {
    final restoreErrors = <String>[];

    try {
      for (final image in deletedImages) {
        try {
          final file = File(image.path);
          if (!await file.exists()) {
            // 文件不存在，无法恢复
            restoreErrors.add('${path.basename(image.path)}: 文件不存在');
            continue;
          }
          // 文件已存在，说明已恢复或其他原因
        } catch (e) {
          restoreErrors.add('${path.basename(image.path)}: $e');
        }
      }

      // 刷新画廊
      await ref.read(localGalleryNotifierProvider.notifier).refresh();

      // 显示恢复结果提示
      if (mounted) {
        final successCount = deletedImages.length - restoreErrors.length;
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已恢复 $successCount 张图片'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (restoreErrors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${restoreErrors.length} 张图片恢复失败'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
  }

  /// 撤销上一步操作
  /// Undo last operation
  Future<void> _undo() async {
    final notifier = ref.read(bulkOperationNotifierProvider.notifier);
    await notifier.undo();

    // 刷新画廊以显示撤销后的状态
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    // 显示撤销成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已撤销'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 重做上一步撤销的操作
  /// Redo last undone operation
  Future<void> _redo() async {
    final notifier = ref.read(bulkOperationNotifierProvider.notifier);
    await notifier.redo();

    // 刷新画廊以显示重做后的状态
    await ref.read(localGalleryNotifierProvider.notifier).refresh();

    // 显示重做成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重做'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 批量导出选中的图片元数据
  /// Export metadata for selected images
  Future<void> _exportSelectedImages() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    if (!mounted) return;

    // 显示导出选项对话框
    // Show export options dialog
    // The dialog will handle the export operation and show progress
    // 对话框将处理导出操作并显示进度
    showBulkExportDialog(context);

    // Note: The bulk export dialog will:
    // 1. Show format selection options
    // 2. Call bulkExport when user confirms
    // 3. The bulkExport method will update operation state
    // 4. User should see progress indication
    // 5. Exit selection mode when done
    //
    // 注：批量导出对话框将：
    // 1. 显示格式选择选项
    // 2. 用户确认时调用 bulkExport
    // 3. bulkExport 方法将更新操作状态
    // 4. 用户应该看到进度指示
    // 5. 完成后退出选择模式
  }

  /// 批量编辑选中的图片元数据
  /// Edit metadata for selected images
  Future<void> _editSelectedMetadata() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    if (!mounted) return;

    // 显示批量元数据编辑对话框
    // Show bulk metadata edit dialog
    showBulkMetadataEditDialog(context);
  }

  /// 批量添加选中的图片到集合
  /// Add selected images to a collection
  Future<void> _addSelectedToCollection() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    if (!mounted) return;

    // 显示集合选择对话框
    // Show collection selection dialog
    final result = await CollectionSelectDialog.show(
      context,
      theme: Theme.of(context),
    );

    if (result == null) {
      // 用户取消了选择
      // User cancelled the selection
      return;
    }

    // 添加图片到集合
    // Add images to collection
    final imagePaths = selectedImages.map((img) => img.path).toList();
    final addedCount = await ref
        .read(collectionNotifierProvider.notifier)
        .addImagesToCollection(result.collectionId, imagePaths);

    if (mounted) {
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已添加 $addedCount 张图片到集合「${result.collectionName}」',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        // 退出选择模式
        // Exit selection mode
        ref.read(localGallerySelectionNotifierProvider.notifier).exit();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加图片到集合失败'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 计算图片宽高比
  /// Calculate aspect ratio from metadata or image file
  Future<double> _calculateAspectRatio(LocalImageRecord record) async {
    // 首先尝试从元数据获取尺寸
    // Try to get dimensions from metadata first
    final metadata = record.metadata;
    if (metadata != null && metadata.width != null && metadata.height != null) {
      final width = metadata.width!;
      final height = metadata.height!;
      if (width > 0 && height > 0) {
        return width / height;
      }
    }

    // 如果元数据中没有尺寸信息，从图片文件读取
    // If metadata doesn't have dimensions, read from image file
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(record.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width > 0 && height > 0) {
        return width / height;
      }
    } catch (e) {
      // 如果读取失败，返回默认宽高比
      // If reading fails, return default aspect ratio
    }

    // 默认宽高比（基于常见的 NAI 生成尺寸）
    // Default aspect ratio (based on common NAI generation dimensions)
    return 1.0;
  }

  /// 检查权限并扫描图片
  Future<void> _checkPermissionsAndScan() async {
    // 检查权限状态
    final hasPermission = await PermissionUtils.checkGalleryPermission();

    if (!hasPermission) {
      // 请求权限
      final granted = await PermissionUtils.requestGalleryPermission();

      if (!granted && mounted) {
        // 权限被拒绝，显示引导对话框
        _showPermissionDeniedDialog();
        return;
      }
    }

    // 有权限，开始扫描
    if (mounted) {
      ref.read(localGalleryNotifierProvider.notifier).initialize();
    }
  }

  /// 显示权限被拒绝对话框
  void _showPermissionDeniedDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        title: Text(
          '需要存储权限',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n'
          '请在设置中授予权限后重试。',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              PermissionUtils.openAppSettings();
            },
            child: Text(
              '打开设置',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示首次使用提示
  Future<void> _showFirstTimeTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTip =
        prefs.getBool(StorageKeys.hasSeenLocalGalleryTip) ?? false;

    if (hasSeenTip || !mounted) return;

    // 标记已显示
    await prefs.setBool(StorageKeys.hasSeenLocalGalleryTip, true);

    // 延迟显示，避免与权限对话框冲突
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        title: Text(
          '💡 使用提示',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          '右键点击（桌面端）或长按（移动端）图片可以：\n\n'
          '• 复制 Prompt\n'
          '• 复制 Seed\n'
          '• 查看完整元数据',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '知道了',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开图片保存文件夹
  Future<void> _openImageFolder() async {
    try {
      final dir = await LocalGalleryRepository.instance.getImageDirectory();

      // 确保目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 获取绝对路径
      final absolutePath = dir.absolute.path;

      // 显示路径信息（调试用）
      debugPrint('Opening folder: $absolutePath');

      // 使用系统资源管理器打开文件夹
      if (Platform.isWindows) {
        // Windows: 将正斜杠替换为反斜杠，直接使用 explorer.exe
        final windowsPath = absolutePath.replaceAll('/', '\\');
        debugPrint('Windows path: $windowsPath');

        // 直接调用 explorer.exe，路径作为参数
        await Process.run('explorer.exe', [windowsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absolutePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [absolutePath]);
      } else {
        // 其他平台使用 url_launcher
        final uri = Uri.directory(absolutePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final bulkOpState = ref.watch(bulkOperationNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = screenWidth / columns;

    return KeyboardListener(
      focusNode: _shortcutsFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        // Handle keyboard shortcuts for undo/redo
        // 处理撤销/重做的键盘快捷键
        if (event is KeyDownEvent) {
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

          if (isCtrlPressed) {
            // Ctrl+Z for undo
            if (event.logicalKey == LogicalKeyboardKey.keyZ) {
              if (bulkOpState.canUndo) {
                _undo();
              }
            }
            // Ctrl+Y for redo
            else if (event.logicalKey == LogicalKeyboardKey.keyY) {
              if (bulkOpState.canRedo) {
                _redo();
              }
            }
            // Ctrl+Shift+Z for redo
            else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                HardwareKeyboard.instance.isShiftPressed) {
              if (bulkOpState.canRedo) {
                _redo();
              }
            }
          }
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // 顶部工具栏
            _buildToolbar(theme, state, bulkOpState),
            // 主体内容
            Expanded(
              child: state.error != null
                  ? _buildErrorState(theme, state)
                  : state.isIndexing
                      ? _buildIndexingState()
                      : state.allFiles.isEmpty
                          ? _buildEmptyState(context)
                          : _buildContent(theme, state, columns, itemWidth),
            ),
            // 底部分页条
            if (!state.isIndexing &&
                state.filteredFiles.isNotEmpty &&
                state.totalPages > 1)
              PaginationBar(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: (p) =>
                    ref.read(localGalleryNotifierProvider.notifier).loadPage(p),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部工具栏
  Widget _buildToolbar(ThemeData theme, LocalGalleryState state, BulkOperationState bulkOpState) {
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final isDark = theme.brightness == Brightness.dark;

    if (selectionState.isActive) {
      return BulkActionBar(
        onExit: () =>
            ref.read(localGallerySelectionNotifierProvider.notifier).exit(),
        onAddToCollection: selectionState.selectedIds.isNotEmpty
            ? _addSelectedToCollection
            : null,
        onDelete: selectionState.selectedIds.isNotEmpty
            ? _deleteSelectedImages
            : null,
        onExport: selectionState.selectedIds.isNotEmpty
            ? _exportSelectedImages
            : null,
        onEditMetadata: selectionState.selectedIds.isNotEmpty
            ? _editSelectedMetadata
            : null,
      );
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              // 第一行：标题 + 操作按钮
              Row(
                children: [
                  Text(
                    '本地画廊',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 图片计数
                  if (!state.isIndexing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.primaryContainer
                                .withOpacity(0.4)
                            : theme.colorScheme.primaryContainer
                                .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.hasFilters
                            ? '${state.filteredCount} / ${state.totalCount}'
                            : '${state.totalCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // 撤销/重做按钮组
                  if (bulkOpState.canUndo || bulkOpState.canRedo) ...[
                    // 撤销按钮
                    _RoundedIconButton(
                      icon: Icons.undo,
                      tooltip: '撤销 (Ctrl+Z)',
                      onPressed: bulkOpState.canUndo ? _undo : null,
                      color: bulkOpState.canUndo
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    // 重做按钮
                    _RoundedIconButton(
                      icon: Icons.redo,
                      tooltip: '重做 (Ctrl+Y)',
                      onPressed: bulkOpState.canRedo ? _redo : null,
                      color: bulkOpState.canRedo
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 多选模式切换
                  _RoundedIconButton(
                    icon: Icons.checklist,
                    tooltip: '多选模式',
                    onPressed: () {
                      ref
                          .read(localGallerySelectionNotifierProvider.notifier)
                          .enter();
                    },
                  ),
                  const SizedBox(width: 8),
                  // 打开文件夹按钮
                  _RoundedTextButton(
                    icon: Icons.folder_open,
                    label: '打开文件夹',
                    onPressed: _openImageFolder,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  // 刷新按钮
                  if (state.isIndexing)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    _RoundedTextButton(
                      icon: Icons.refresh,
                      label: '刷新',
                      onPressed: () {
                        ref
                            .read(localGalleryNotifierProvider.notifier)
                            .refresh();
                      },
                      color: theme.colorScheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 第二行：搜索框 + 日期过滤
              Row(
                children: [
                  // 搜索框
                  Expanded(
                    child: _buildSearchField(theme, state),
                  ),
                  const SizedBox(width: 12),
                  // 日期范围过滤按钮
                  _buildDateRangeButton(theme, state),
                  const SizedBox(width: 8),
                  // 日期选择器按钮（跳转到指定日期）
                  _buildDatePickerButton(theme),
                  const SizedBox(width: 8),
                  // 高级筛选按钮
                  _RoundedIconButton(
                    icon: Icons.tune,
                    tooltip: '高级筛选',
                    onPressed: () => showGalleryFilterPanel(context),
                  ),
                  // 清除过滤按钮
                  if (state.hasFilters) ...[
                    const SizedBox(width: 8),
                    _RoundedIconButton(
                      icon: Icons.filter_alt_off,
                      tooltip: '清除所有过滤',
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(localGalleryNotifierProvider.notifier)
                            .clearAllFilters();
                      },
                      color: theme.colorScheme.error,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, LocalGalleryState state) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: '搜索文件名或 Prompt...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.6 : 0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.7 : 0.6),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(isDark ? 0.7 : 0.6),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(localGalleryNotifierProvider.notifier)
                        .setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {}); // 更新清除按钮显示状态
          _onSearchChanged(value);
        },
        onSubmitted: (value) {
          _debounceTimer?.cancel();
          ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  /// 构建日期范围按钮
  Widget _buildDateRangeButton(ThemeData theme, LocalGalleryState state) {
    final hasDateRange = state.dateStart != null || state.dateEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasDateRange
            ? _formatDateRange(state.dateStart, state.dateEnd)
            : '日期过滤',
        style: TextStyle(
          fontSize: 12,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side:
            hasDateRange ? BorderSide(color: theme.colorScheme.primary) : null,
      ),
    );
  }

  /// 格式化日期范围显示
  String _formatDateRange(DateTime? start, DateTime? end) {
    final format = DateFormat('MM-dd');
    if (start != null && end != null) {
      return '${format.format(start)}~${format.format(end)}';
    } else if (start != null) {
      return '${format.format(start)}~';
    } else if (end != null) {
      return '~${format.format(end)}';
    }
    return '';
  }

  /// 构建日期选择器按钮（跳转到指定日期）
  Widget _buildDatePickerButton(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return OutlinedButton.icon(
      onPressed: () => _pickDateAndJump(context),
      icon: const Icon(
        Icons.calendar_today,
        size: 16,
      ),
      label: Text(
        l10n.localGallery_jumpToDate,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 选择日期范围
  Future<void> _selectDateRange(
    BuildContext context,
    LocalGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: state.dateStart != null && state.dateEnd != null
          ? DateTimeRange(start: state.dateStart!, end: state.dateEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(localGalleryNotifierProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
    }
  }

  /// 选择日期并跳转到对应分组
  /// Select date and jump to corresponding group
  Future<void> _pickDateAndJump(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (pickerContext, child) {
        return Theme(
          data: Theme.of(pickerContext).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // 确保分组视图已激活
      // Ensure grouped view is activated
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        notifier.setGroupedView(true);
      }

      // 等待分组数据加载完成
      // Wait for grouped data to load
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // 计算选中日期属于哪个分组
      // Calculate which group the selected date belongs to
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      ImageDateGroup? targetGroup;

      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
      } else if (selectedDate.isAfter(thisWeekStart) &&
          selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // 跳转到对应分组
      // Jump to corresponding group
      _groupedGridViewKey.currentState?.scrollToGroup(targetGroup);

      // 显示提示消息
      // Show hint message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 构建错误状态
  Widget _buildErrorState(ThemeData theme, LocalGalleryState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败: ${state.error}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(localGalleryNotifierProvider.notifier).refresh(),
            child: Text(
              '重试',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建索引状态
  Widget _buildIndexingState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '索引本地图片中...',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.6 : 1.0),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无本地图片',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '生成的图片将保存在此处',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant
                  .withOpacity(isDark ? 0.7 : 1.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容区
  Widget _buildContent(
    ThemeData theme,
    LocalGalleryState state,
    int columns,
    double itemWidth,
  ) {
    // 分组视图
    // Grouped view
    if (state.isGroupedView) {
      // 分组视图中加载骨架屏
      // Loading skeleton in grouped view
      if (state.isGroupedLoading) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '加载分组图片中...',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }

      // 分组视图无结果
      // No results in grouped view
      if (state.groupedImages.isEmpty) {
        final isDark = theme.brightness == Brightness.dark;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant
                    .withOpacity(isDark ? 0.6 : 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                '无匹配结果',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ref
                      .read(localGalleryNotifierProvider.notifier)
                      .clearAllFilters();
                },
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('清除过滤'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }

      // 显示分组视图
      // Show grouped view
      final selectionState = ref.watch(localGallerySelectionNotifierProvider);

      return GroupedGridView(
        key: _groupedGridViewKey,
        images: state.groupedImages,
        columns: columns,
        itemWidth: itemWidth,
        selectionMode: selectionState.isActive,
        buildSelected: (path) => selectionState.selectedIds.contains(path),
        buildCard: (record) {
          final isSelected = selectionState.selectedIds.contains(record.path);

          // Get or calculate aspect ratio for grouped view
          final double aspectRatio = _aspectRatioCache[record.path] ?? 1.0;

          // Calculate and cache aspect ratio asynchronously if not cached
          if (!_aspectRatioCache.containsKey(record.path)) {
            _calculateAspectRatio(record).then((value) {
              if (mounted && value != aspectRatio) {
                setState(() {
                  _aspectRatioCache[record.path] = value;
                });
              }
            });
          }

          return LocalImageCard(
            record: record,
            itemWidth: itemWidth,
            aspectRatio: aspectRatio,
            selectionMode: selectionState.isActive,
            isSelected: isSelected,
            onSelectionToggle: () {
              ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .toggle(record.path);
            },
            onLongPress: () {
              if (!selectionState.isActive) {
                ref
                    .read(localGallerySelectionNotifierProvider.notifier)
                    .enterAndSelect(record.path);
              }
            },
            onDeleted: () {
              // 刷新分组视图
              ref.read(localGalleryNotifierProvider.notifier).refresh();
            },
          );
        },
      );
    }

    // 过滤后无结果
    if (state.filteredFiles.isEmpty && state.hasFilters) {
      final isDark = theme.brightness == Brightness.dark;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant
                  .withOpacity(isDark ? 0.6 : 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '无匹配结果',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref
                    .read(localGalleryNotifierProvider.notifier)
                    .clearAllFilters();
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('清除过滤'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    // 加载中骨架屏
    if (state.isPageLoading) {
      return GridView.builder(
        key: const PageStorageKey<String>('local_gallery_grid_loading'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount:
            state.currentImages.isNotEmpty ? state.currentImages.length : 20,
        itemBuilder: (c, i) {
          return const Card(
            clipBehavior: Clip.antiAlias,
            child: _ShimmerSkeleton(height: 250),
          );
        },
      );
    }

    // 正常内容
    return MasonryGridView.count(
      key: const PageStorageKey<String>('local_gallery_grid'),
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: state.currentImages.length,
      itemBuilder: (c, i) {
        final record = state.currentImages[i];
        final selectionState = ref.watch(localGallerySelectionNotifierProvider);
        final isSelected = selectionState.selectedIds.contains(record.path);

        // 获取或计算宽高比
        // Get or calculate aspect ratio
        final double aspectRatio = _aspectRatioCache[record.path] ?? 1.0;

        // 异步计算并缓存宽高比
        // Calculate and cache aspect ratio asynchronously
        _calculateAspectRatio(record).then((value) {
          if (mounted && value != aspectRatio) {
            setState(() {
              _aspectRatioCache[record.path] = value;
            });
          }
        });

        return LocalImageCard(
          record: record,
          itemWidth: itemWidth,
          aspectRatio: aspectRatio,
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          onSelectionToggle: () {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .toggle(record.path);
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .enterAndSelect(record.path);
            }
          },
          onDeleted: () {
            // 刷新当前页
            ref
                .read(localGalleryNotifierProvider.notifier)
                .loadPage(state.currentPage);
          },
        );
      },
    );
  }
}

/// 圆角图标按钮（带悬停动画）
class _RoundedIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const _RoundedIconButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  State<_RoundedIconButton> createState() => _RoundedIconButtonState();
}

class _RoundedIconButtonState extends State<_RoundedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = widget.color ?? theme.colorScheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? effectiveColor.withOpacity(isDark ? 0.2 : 0.15)
              : effectiveColor.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectiveColor.withOpacity(isDark ? 0.15 : 0.2),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(widget.icon),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          color: effectiveColor,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆角文本按钮（带悬停动画）
class _RoundedTextButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _RoundedTextButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
  });

  @override
  State<_RoundedTextButton> createState() => _RoundedTextButtonState();
}

class _RoundedTextButtonState extends State<_RoundedTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withOpacity(isDark ? 0.25 : 0.2)
              : widget.color.withOpacity(isDark ? 0.12 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color.withOpacity(isDark ? 0.25 : 0.3),
            width: 1,
          ),
        ),
        child: TextButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 18),
          label: Text(widget.label),
          style: TextButton.styleFrom(
            foregroundColor: widget.color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

/// 简单的 Shimmer 骨架屏组件
class _ShimmerSkeleton extends StatefulWidget {
  final double height;

  const _ShimmerSkeleton({required this.height});

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Dark mode: use lighter shimmer on dark surface
    // Light mode: use darker shimmer on light surface
    final baseColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.2)
        : colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : colorScheme.surfaceContainerHighest.withOpacity(0.6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + (_controller.value * 2),
                -0.3,
              ), // 稍微倾斜
              end: Alignment(
                1.0 + (_controller.value * 2),
                0.3,
              ),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
