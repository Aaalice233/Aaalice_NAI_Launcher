import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/gallery/gallery_folder.dart';
import '../../providers/gallery_folder_provider.dart';
import '../common/app_toast.dart';

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
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件夹名称',
            hintText: '输入文件夹名称',
            border: OutlineInputBorder(),
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
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
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
              Icon(Icons.delete_outline,
                  size: 18, color: Theme.of(context).colorScheme.error,),
              const SizedBox(width: 8),
              Text('删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),),
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
    final controller = TextEditingController(text: folder.name);

    // 等待菜单关闭
    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
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
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
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
    // 等待菜单关闭
    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text(
          folder.imageCount > 0
              ? '文件夹「${folder.name}」包含 ${folder.imageCount} 张图片，确定要删除吗？\n\n注意：此操作会删除文件夹及其中的所有图片，无法恢复。'
              : '确定要删除空文件夹「${folder.name}」吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
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
}

/// 文件夹标签
class _FolderTab extends StatefulWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  final void Function(TapDownDetails)? onContextMenu;

  const _FolderTab({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
    this.onContextMenu,
  });

  @override
  State<_FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<_FolderTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
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
            color: widget.isActive
                ? colorScheme.primaryContainer.withOpacity(isDark ? 0.4 : 0.3)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                    : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? colorScheme.primary
                  : _isHovered
                      ? colorScheme.outline.withOpacity(0.3)
                      : colorScheme.outline.withOpacity(0.15),
              width: widget.isActive ? 1.5 : 1,
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
