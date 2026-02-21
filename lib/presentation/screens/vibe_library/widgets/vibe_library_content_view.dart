import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/selection_mode_provider.dart';
import '../../../providers/vibe_library_category_provider.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../providers/vibe_library_selection_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/pro_context_menu.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/gallery/gallery_state_views.dart';
import 'vibe_card.dart';
import 'vibe_detail_viewer.dart';
import 'vibe_export_dialog.dart';

/// Vibe 库内容视图
///
/// 显示 Vibe 条目的网格视图，支持选择模式、右键菜单和操作
class VibeLibraryContentView extends ConsumerStatefulWidget {
  final int columns;
  final double itemWidth;

  const VibeLibraryContentView({
    super.key,
    required this.columns,
    required this.itemWidth,
  });

  @override
  ConsumerState<VibeLibraryContentView> createState() =>
      _VibeLibraryContentViewState();
}

class _VibeLibraryContentViewState
    extends ConsumerState<VibeLibraryContentView> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);

    // 使用 3D 卡片视图模式
    return _build3DCardView(state, selectionState);
  }

  /// 构建 3D 卡片视图
  Widget _build3DCardView(
    VibeLibraryState state,
    SelectionModeState selectionState,
  ) {
    final entries = state.currentEntries;

    // 空状态处理
    if (entries.isEmpty) {
      final emptyInfo = _getEmptyStateInfo(state);
      return GalleryErrorView(
        error: emptyInfo.subtitle ?? emptyInfo.title,
        onRetry: () {
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        },
      );
    }

    // 加载中状态
    if (state.isLoading) {
      return const GalleryLoadingView();
    }

    return GridView.builder(
      key: const PageStorageKey<String>('vibe_library_3d_grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = selectionState.selectedIds.contains(entry.id);

        return VibeCard(
          entry: entry,
          width: widget.itemWidth,
          height: widget.itemWidth,
          isSelected: isSelected,
          showFavoriteIndicator: true,
          onTap: () {
            if (selectionState.isActive) {
              ref
                  .read(vibeLibrarySelectionNotifierProvider.notifier)
                  .toggle(entry.id);
            } else {
              _showVibeDetail(context, entry);
            }
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(vibeLibrarySelectionNotifierProvider.notifier)
                  .enterAndSelect(entry.id);
            }
          },
          onSecondaryTapDown: (details) {
            _showContextMenu(context, entry, details.globalPosition);
          },
          onFavoriteToggle: () {
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
          onSendToGeneration: () async => _sendEntryToGeneration(context, entry),
          onExport: () => _exportSingleEntry(context, entry),
          onEdit: () => _showVibeDetail(context, entry),
          onDelete: () => _deleteSingleEntry(context, entry),
        );
      },
    );
  }

  /// 显示 Vibe 详情
  void _showVibeDetail(BuildContext context, VibeLibraryEntry entry) {
    VibeDetailViewer.show(
      context,
      entry: entry,
      heroTag: 'vibe_${entry.id}',
      callbacks: VibeDetailCallbacks(
        onSendToGeneration:
            (entry, strength, infoExtracted, isShiftPressed) async {
          await _sendEntryToGenerationWithParams(
            context,
            entry,
            strength,
            infoExtracted,
            isShiftPressed,
          );
        },
        onExport: (entry) {
          _exportSingleEntry(context, entry);
        },
        onDelete: (entry) {
          _deleteSingleEntry(context, entry);
        },
        onRename: (entry, newName) {
          return _renameSingleEntry(context, entry, newName);
        },
        onParamsChanged: (entry, strength, infoExtracted) {
          _updateEntryParams(context, entry, strength, infoExtracted);
        },
      ),
    );
  }

  /// 显示上下文菜单
  void _showContextMenu(
    BuildContext context,
    VibeLibraryEntry entry,
    Offset position,
  ) {
    final items = <ProMenuItem>[
      ProMenuItem(
        id: 'send_to_generation',
        label: '发送到生成',
        icon: Icons.send,
        onTap: () async => _sendEntryToGeneration(context, entry),
      ),
      ProMenuItem(
        id: 'export',
        label: '导出',
        icon: Icons.download,
        onTap: () => _exportSingleEntry(context, entry),
      ),
      ProMenuItem(
        id: 'edit',
        label: '编辑',
        icon: Icons.edit,
        onTap: () => _showVibeDetail(context, entry),
      ),
      const ProMenuItem.divider(),
      ProMenuItem(
        id: 'toggle_favorite',
        label: entry.isFavorite ? '取消收藏' : '收藏',
        icon: entry.isFavorite ? Icons.favorite : Icons.favorite_border,
        onTap: () {
          ref
              .read(vibeLibraryNotifierProvider.notifier)
              .toggleFavorite(entry.id);
        },
      ),
      ProMenuItem(
        id: 'delete',
        label: '删除',
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () => _deleteSingleEntry(context, entry),
      ),
    ];

    Navigator.of(context).push(
      _ContextMenuRoute(
        position: position,
        items: items,
        onSelect: (item) {
          // Item onTap is already called
        },
      ),
    );
  }

  /// 发送单个条目到生成页面
  Future<void> _sendEntryToGeneration(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检测是否按住 Shift 键
    final physicalKeys = HardwareKeyboard.instance.physicalKeysPressed;
    final isShiftPressed =
        physicalKeys.contains(PhysicalKeyboardKey.shiftLeft) ||
            physicalKeys.contains(PhysicalKeyboardKey.shiftRight);

    // 检查是否超过16个限制（仅在追加模式下检查）
    if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, '已达到最大数量 (16张)');
      return;
    }

    // 处理 Bundle 条目：从文件读取所有 vibes
    if (entry.isBundle &&
        entry.filePath != null &&
        entry.filePath!.isNotEmpty) {
      final file = File(entry.filePath!);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          final fileName = p.basename(entry.filePath!);
          final vibes = await VibeFileParser.fromBundle(fileName, bytes);

          // 应用条目的 strength 和 infoExtracted 到所有 vibes
          final adjustedVibes = vibes
              .map(
                (vibe) => vibe.copyWith(
                  strength: entry.strength,
                  infoExtracted: entry.infoExtracted,
                ),
              )
              .toList();

          if (isShiftPressed) {
            // Shift+点击：替换现有 vibes
            paramsNotifier.setVibeReferences(adjustedVibes);
          } else {
            // 普通点击：追加 vibes
            paramsNotifier.addVibeReferences(adjustedVibes);
          }

          ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
          if (context.mounted) {
            final message = isShiftPressed
                ? '已替换为 ${adjustedVibes.length} 个 Vibe: ${entry.displayName}'
                : '已发送 ${adjustedVibes.length} 个 Vibe 到生成页面: ${entry.displayName}';
            AppToast.success(context, message);
            context.go(AppRoutes.home);
          }
          return;
        } catch (e, stackTrace) {
          AppLogger.e(
            '读取 Bundle 文件失败: ${entry.filePath}',
            e,
            stackTrace,
            'VibeLibrary',
          );
          // 回退到单个 vibe 处理
        }
      }
    }

    // 普通条目或 Bundle 文件不存在时，使用单个 vibe
    final vibeReference = entry.toVibeReference();
    if (isShiftPressed) {
      // Shift+点击：替换现有 vibes
      paramsNotifier.setVibeReferences([vibeReference]);
    } else {
      // 普通点击：追加 vibes
      paramsNotifier.addVibeReferences([vibeReference]);
    }

    ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
    if (context.mounted) {
      final message = isShiftPressed
          ? '已替换为: ${entry.displayName}'
          : '已发送到生成页面: ${entry.displayName}';
      AppToast.success(context, message);
      context.go(AppRoutes.home);
    }
  }

  /// 发送单个条目到生成页面（带参数）
  Future<void> _sendEntryToGenerationWithParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
    bool isShiftPressed,
  ) async {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查是否超过16个限制（仅在追加模式下检查）
    if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, '已达到最大数量 (16张)');
      return;
    }

    // 处理 Bundle 条目：从文件读取所有 vibes
    if (entry.isBundle &&
        entry.filePath != null &&
        entry.filePath!.isNotEmpty) {
      final file = File(entry.filePath!);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          final fileName = p.basename(entry.filePath!);
          final vibes = await VibeFileParser.fromBundle(fileName, bytes);

          // 应用传入的参数到所有 vibes
          final adjustedVibes = vibes
              .map(
                (vibe) => vibe.copyWith(
                  strength: strength,
                  infoExtracted: infoExtracted,
                ),
              )
              .toList();

          if (isShiftPressed) {
            paramsNotifier.setVibeReferences(adjustedVibes);
          } else {
            paramsNotifier.addVibeReferences(adjustedVibes);
          }
          ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
          if (context.mounted) {
            final message = isShiftPressed
                ? '已替换为 ${adjustedVibes.length} 个 Vibe: ${entry.displayName}'
                : '已发送 ${adjustedVibes.length} 个 Vibe 到生成页面: ${entry.displayName}';
            AppToast.success(context, message);
            context.go(AppRoutes.home);
          }
          return;
        } catch (e, stackTrace) {
          AppLogger.e(
            '读取 Bundle 文件失败: ${entry.filePath}',
            e,
            stackTrace,
            'VibeLibrary',
          );
          // 回退到单个 vibe 处理
        }
      }
    }

    // 普通条目或 Bundle 文件不存在时，使用单个 vibe
    final vibeRef = entry.toVibeReference().copyWith(
          strength: strength,
          infoExtracted: infoExtracted,
        );

    if (isShiftPressed) {
      paramsNotifier.setVibeReferences([vibeRef]);
    } else {
      paramsNotifier.addVibeReferences([vibeRef]);
    }
    ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
    if (context.mounted) {
      final message = isShiftPressed
          ? '已替换为: ${entry.displayName}'
          : '已发送到生成页面: ${entry.displayName}';
      AppToast.success(context, message);
      context.go(AppRoutes.home);
    }
  }

  /// 导出单个条目
  void _exportSingleEntry(BuildContext context, VibeLibraryEntry entry) {
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;

    showDialog<void>(
      context: context,
      builder: (context) => VibeExportDialog(
        entries: [entry],
        categories: categories,
      ),
    );
  }

  /// 删除单个条目
  Future<void> _deleteSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除 "${entry.displayName}" 吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .deleteEntries([entry.id]);
      if (context.mounted) {
        AppToast.success(context, '已删除: ${entry.displayName}');
      }
    }
  }

  /// 重命名单个条目
  Future<String?> _renameSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    String newName,
  ) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      return '名称不能为空';
    }

    final result = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .renameEntry(entry.id, trimmedName);
    if (result.isSuccess) {
      return null;
    }

    switch (result.error) {
      case VibeEntryRenameError.invalidName:
        return '名称不能为空';
      case VibeEntryRenameError.nameConflict:
        return '名称已存在，请使用其他名称';
      case VibeEntryRenameError.entryNotFound:
        return '条目不存在，可能已被删除';
      case VibeEntryRenameError.filePathMissing:
        return '该条目缺少文件路径，无法重命名';
      case VibeEntryRenameError.fileRenameFailed:
        return '重命名文件失败，请稍后重试';
      case null:
        return '重命名失败，请稍后重试';
    }
  }

  /// 更新条目参数
  void _updateEntryParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  ) {
    final updatedEntry =
        entry.updateStrength(strength).updateInfoExtracted(infoExtracted);

    ref.read(vibeLibraryNotifierProvider.notifier).saveEntry(updatedEntry);
  }

  /// 获取空状态提示信息
  _EmptyStateInfo _getEmptyStateInfo(VibeLibraryState state) {
    // 搜索无结果
    if (state.searchQuery.isNotEmpty) {
      return const _EmptyStateInfo(
        title: '未找到匹配的 Vibe',
        subtitle: '尝试其他关键词',
        icon: Icons.search_off,
      );
    }

    // 收藏无结果
    if (state.favoritesOnly) {
      return const _EmptyStateInfo(
        title: '暂无收藏的 Vibe',
        subtitle: '点击心形图标收藏 Vibe',
        icon: Icons.favorite_border,
      );
    }

    // 分类无结果
    if (state.selectedCategoryId != null) {
      return const _EmptyStateInfo(
        title: '该分类下暂无 Vibe',
        subtitle: '尝试切换到"全部 Vibe"查看所有内容',
        icon: Icons.folder_outlined,
      );
    }

    // 默认无结果
    return const _EmptyStateInfo(
      title: '无匹配结果',
      subtitle: null,
      icon: Icons.search_off,
    );
  }
}

/// 空状态信息
class _EmptyStateInfo {
  final String title;
  final String? subtitle;
  final IconData icon;

  const _EmptyStateInfo({
    required this.title,
    this.subtitle,
    required this.icon,
  });
}

/// 自定义上下文菜单路由
class _ContextMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ContextMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // 计算调整后的位置以保持菜单在屏幕边界内
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight = items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // 调整水平位置，如果菜单超出屏幕
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // 调整垂直位置，如果菜单超出屏幕
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => Duration.zero;
}
