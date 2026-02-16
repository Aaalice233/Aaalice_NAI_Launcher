import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/gallery_folder.dart';
import '../../providers/gallery_folder_provider.dart';
import '../common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 文件夹标签栏组件
///
/// 显示画廊文件夹的水平标签栏，支持：
/// - "全部" + 各子文件夹标签
/// - 每个标签显示名称和图片数量
/// - 右侧 "+" 按钮创建新文件夹
class FolderTabs extends ConsumerWidget {
  /// 文件夹选择回调
  final void Function(String? folderId)? onFolderSelected;

  const FolderTabs({
    super.key,
    this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderState = ref.watch(galleryFolderNotifierProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 文件夹标签列表
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "全部" 标签
                  _FolderTab(
                    label: '全部',
                    count: folderState.totalImageCount,
                    isActive: folderState.isAllSelected,
                    folderId: null,
                    onTap: () {
                      ref
                          .read(galleryFolderNotifierProvider.notifier)
                          .selectFolder(null);
                      onFolderSelected?.call(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  // 文件夹标签
                  ...folderState.folders.map((folder) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FolderTab(
                          label: folder.name,
                          count: folder.imageCount,
                          isActive: folderState.selectedFolderId == folder.id,
                          folderId: folder.id,
                          onTap: () {
                            ref
                                .read(galleryFolderNotifierProvider.notifier)
                                .selectFolder(folder.id);
                            onFolderSelected?.call(folder.id);
                          },
                          onContextMenu: (details) {
                            _showFolderContextMenu(
                                context, ref, folder, details.globalPosition,);
                          },
                        ),
                      ),),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 创建文件夹按钮
          _CreateFolderButton(
            onPressed: () => _showCreateFolderDialog(context, ref),
          ),
        ],
      ),
    );
  }

  /// 显示创建文件夹对话框
  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref,) async {
    final result = await _showFolderNameDialog(
      context: context,
      title: '创建文件夹',
      label: '文件夹名称',
      hint: '输入文件夹名称',
      confirmText: '创建',
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      final folder = await ref
          .read(galleryFolderNotifierProvider.notifier)
          .createFolder(result);
      if (folder != null && context.mounted) {
        AppToast.success(context, '文件夹创建成功');
      } else if (context.mounted) {
        AppToast.error(context, '文件夹创建失败');
      }
    }
  }

  /// 显示文件夹右键菜单
  void _showFolderContextMenu(
    BuildContext context,
    WidgetRef ref,
    GalleryFolder folder,
    Offset position,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy,),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('重命名'),
            ],
          ),
          onTap: () => _showRenameFolderDialog(context, ref, folder),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
          onTap: () => _showDeleteFolderDialog(context, ref, folder),
        ),
      ],
    );
  }

  /// 显示重命名对话框
  Future<void> _showRenameFolderDialog(
    BuildContext context,
    WidgetRef ref,
    GalleryFolder folder,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return;

    final result = await _showFolderNameDialog(
      context: context,
      title: '重命名文件夹',
      label: '新名称',
      confirmText: '确定',
      initialValue: folder.name,
    );

    if (result != null &&
        result.isNotEmpty &&
        result != folder.name &&
        context.mounted) {
      final newFolder = await ref
          .read(galleryFolderNotifierProvider.notifier)
          .renameFolder(folder.path, result);
      if (newFolder != null && context.mounted) {
        AppToast.success(context, '重命名成功');
      } else if (context.mounted) {
        AppToast.error(context, '重命名失败');
      }
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteFolderDialog(
    BuildContext context,
    WidgetRef ref,
    GalleryFolder folder,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return;

    final content = folder.imageCount > 0
        ? '文件夹「${folder.name}」包含 ${folder.imageCount} 张图片，确定要删除吗？\n\n注意：此操作会删除文件夹及其中的所有图片，无法恢复。'
        : '确定要删除空文件夹「${folder.name}」吗？';

    final confirmed = await _showConfirmDialog(
      context: context,
      title: '删除文件夹',
      content: content,
      confirmText: '删除',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed && context.mounted) {
      final success =
          await ref.read(galleryFolderNotifierProvider.notifier).deleteFolder(
                folder.path,
                recursive: folder.imageCount > 0,
              );
      if (success && context.mounted) {
        AppToast.success(context, '文件夹已删除');
      } else if (context.mounted) {
        AppToast.error(context, '删除失败');
      }
    }
  }

  /// 通用文件夹名称对话框
  Future<String?> _showFolderNameDialog({
    required BuildContext context,
    required String title,
    required String label,
    required String confirmText,
    String? hint,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ThemedInput(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(context).pop(name);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  /// 通用确认对话框
  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
    Color? confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: confirmColor != null
                    ? FilledButton.styleFrom(backgroundColor: confirmColor)
                    : null,
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// 文件夹标签
///
/// 支持拖拽图片到标签上以移动到对应文件夹
class _FolderTab extends ConsumerStatefulWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final void Function(TapDownDetails)? onContextMenu;
  final String? folderId;

  const _FolderTab({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
    this.onContextMenu,
    this.folderId,
  });

  @override
  ConsumerState<_FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends ConsumerState<_FolderTab> {
  bool _isHovered = false;
  bool _isDraggingOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget tabContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onContextMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _getBackgroundColor(colorScheme, isDark),
            border: Border.all(
              color: _getBorderColor(colorScheme),
              width: _isDraggingOver ? 2 : (widget.isActive ? 1.5 : 1),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.normal,
                  color: widget.isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: widget.isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 包装为拖拽目标
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // 检查是否包含文件
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDraggingOver) {
            setState(() => _isDraggingOver = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        if (_isDraggingOver) {
          setState(() => _isDraggingOver = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDraggingOver = false);
        await _handleDrop(event);
      },
      child: tabContent,
    );
  }

  Color _getBackgroundColor(ColorScheme colorScheme, bool isDark) {
    if (_isDraggingOver) {
      return colorScheme.primaryContainer.withOpacity(isDark ? 0.6 : 0.4);
    }
    if (widget.isActive) {
      return colorScheme.primaryContainer.withOpacity(isDark ? 0.4 : 0.3);
    }
    if (_isHovered) {
      return colorScheme.surfaceContainerHighest.withOpacity(0.5);
    }
    return Colors.transparent;
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    if (_isDraggingOver) {
      return colorScheme.primary;
    }
    if (widget.isActive) {
      return colorScheme.primary;
    }
    if (_isHovered) {
      return colorScheme.outline.withOpacity(0.3);
    }
    return colorScheme.outline.withOpacity(0.15);
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    final imagePaths = <String>[];

    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      final imagePath = await _getImagePath(reader);
      if (imagePath != null) {
        imagePaths.add(imagePath);
      }
    }

    if (imagePaths.isEmpty) return;

    // 批量移动图片到文件夹
    final notifier = ref.read(galleryFolderNotifierProvider.notifier);
    final movedCount =
        await notifier.moveImagesToFolder(imagePaths, widget.folderId);

    if (mounted) {
      if (movedCount > 0) {
        final folderName = widget.label;
        if (movedCount == 1) {
          AppToast.success(context, '已移动 1 张图片到「$folderName」');
        } else {
          AppToast.success(context, '已移动 $movedCount 张图片到「$folderName」');
        }
      } else {
        AppToast.error(context, '移动图片失败');
      }
    }
  }

  Future<String?> _getImagePath(DataReader reader) async {
    // 尝试获取文件 URI
    if (reader.canProvide(Formats.fileUri)) {
      final uri = await _getFileUri(reader);
      if (uri != null) {
        final filePath = uri.toFilePath();
        // 检查是否为图片文件
        if (_isImageFile(filePath)) {
          return filePath;
        }
      }
    }
    return null;
  }

  Future<Uri?> _getFileUri(DataReader reader) {
    final completer = Completer<Uri?>();
    reader.getValue(Formats.fileUri, (uri) => completer.complete(uri));
    return completer.future;
  }

  bool _isImageFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.gif') ||
        lowerPath.endsWith('.webp') ||
        lowerPath.endsWith('.bmp');
  }
}

/// 创建文件夹按钮
class _CreateFolderButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CreateFolderButton({required this.onPressed});

  @override
  State<_CreateFolderButton> createState() => _CreateFolderButtonState();
}

class _CreateFolderButtonState extends State<_CreateFolderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: '创建文件夹',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                color: _isHovered
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.create_new_folder_outlined,
              size: 20,
              color: _isHovered
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
