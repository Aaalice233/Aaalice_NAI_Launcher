import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../providers/vibe_library_selection_provider.dart';
import '../../widgets/gallery/gallery_state_views.dart';
import '../models/empty_state_info.dart';
import 'vibe_card_3d.dart';

/// Vibe库内容视图组件
/// 显示Vibe条目的3D卡片网格
class VibeLibraryContentView extends ConsumerStatefulWidget {
  /// 网格列数
  final int columns;

  /// 每个项目的宽度
  final double itemWidth;

  /// 点击Vibe条目回调
  final void Function(BuildContext context, VibeLibraryEntry entry) onShowDetail;

  /// 显示上下文菜单回调
  final void Function(
    BuildContext context,
    VibeLibraryEntry entry,
    Offset position,
  ) onShowContextMenu;

  /// 发送到生成页面回调
  final void Function(BuildContext context, VibeLibraryEntry entry)
      onSendToGeneration;

  /// 导出条目回调
  final void Function(BuildContext context, VibeLibraryEntry entry) onExport;

  /// 删除条目回调
  final void Function(BuildContext context, VibeLibraryEntry entry) onDelete;

  const VibeLibraryContentView({
    super.key,
    required this.columns,
    required this.itemWidth,
    required this.onShowDetail,
    required this.onShowContextMenu,
    required this.onSendToGeneration,
    required this.onExport,
    required this.onDelete,
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

    return _build3DCardView(state, selectionState);
  }

  /// 构建3D卡片视图
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

        return VibeCard3D(
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
              widget.onShowDetail(context, entry);
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
            widget.onShowContextMenu(context, entry, details.globalPosition);
          },
          onFavoriteToggle: () {
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .toggleFavorite(entry.id);
          },
          onSendToGeneration: () => widget.onSendToGeneration(context, entry),
          onExport: () => widget.onExport(context, entry),
          onEdit: () => widget.onShowDetail(context, entry),
          onDelete: () => widget.onDelete(context, entry),
        );
      },
    );
  }

  /// 获取空状态提示信息
  EmptyStateInfo _getEmptyStateInfo(VibeLibraryState state) {
    // 搜索无结果
    if (state.searchQuery.isNotEmpty) {
      return const EmptyStateInfo(
        title: '未找到匹配的 Vibe',
        subtitle: '尝试其他关键词',
        icon: Icons.search_off,
      );
    }

    // 收藏无结果
    if (state.favoritesOnly) {
      return const EmptyStateInfo(
        title: '暂无收藏的 Vibe',
        subtitle: '点击心形图标收藏 Vibe',
        icon: Icons.favorite_border,
      );
    }

    // 分类无结果
    if (state.selectedCategoryId != null) {
      return const EmptyStateInfo(
        title: '该分类下暂无 Vibe',
        subtitle: '尝试切换到"全部 Vibe"查看所有内容',
        icon: Icons.folder_outlined,
      );
    }

    // 默认无结果
    return const EmptyStateInfo(
      title: '无匹配结果',
      subtitle: null,
      icon: Icons.search_off,
    );
  }
}
