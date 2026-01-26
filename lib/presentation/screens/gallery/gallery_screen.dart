import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/generation_record.dart';
import '../../providers/gallery_provider.dart';
import '../../widgets/autocomplete/autocomplete.dart';
import '../../widgets/gallery/gallery_statistics_dialog.dart';

/// 画廊页面
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(context, state, theme),
      body: Column(
        children: [
          // 搜索栏
          if (_showSearchBar) _buildSearchBar(context, state, theme),
          // 筛选工具栏
          _buildFilterBar(context, state, theme),
          // 画廊内容
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.records.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildGalleryGrid(context, state),
          ),
          // 选择模式工具栏
          if (state.isSelectionMode) _buildSelectionBar(context, state, theme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    GalleryState state,
    ThemeData theme,
  ) {
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(galleryNotifierProvider.notifier).exitSelectionMode();
          },
        ),
        title:
            Text(context.l10n.gallery_selected(state.selectedCount.toString())),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () {
              if (state.selectedCount == state.records.length) {
                ref.read(galleryNotifierProvider.notifier).clearSelection();
              } else {
                ref.read(galleryNotifierProvider.notifier).selectAll();
              }
            },
            tooltip: context.l10n.common_select,
          ),
        ],
      );
    }

    return AppBar(
      title: Text(context.l10n.gallery_title),
      actions: [
        IconButton(
          icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (!_showSearchBar) {
                _searchController.clear();
                ref.read(galleryNotifierProvider.notifier).setSearchQuery(null);
              }
            });
          },
          tooltip: context.l10n.common_search,
        ),
        if (state.records.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, context),
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: 'statistics',
                child: ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: Text(context.l10n.statistics_title),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'select',
                child: ListTile(
                  leading: const Icon(Icons.check_box_outlined),
                  title: Text(context.l10n.common_select),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: Text(context.l10n.gallery_clearAll),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    GalleryState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AutocompleteTextField(
        controller: _searchController,
        config: const AutocompleteConfig(
          maxSuggestions: 15,
          showTranslation: true,
          showCategory: true,
          showCount: true,
          autoInsertComma: false, // 搜索不需要自动逗号
          minQueryLength: 2,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.gallery_searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(galleryNotifierProvider.notifier)
                        .setSearchQuery(null);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          ref.read(galleryNotifierProvider.notifier).setSearchQuery(
                value.isEmpty ? null : value,
              );
        },
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    GalleryState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 收藏筛选
          FilterChip(
            label: Text(context.l10n.gallery_favorite),
            selected: state.filter.favoritesOnly,
            onSelected: (selected) {
              ref.read(galleryNotifierProvider.notifier).toggleFavoritesOnly();
            },
            avatar: Icon(
              state.filter.favoritesOnly
                  ? Icons.favorite
                  : Icons.favorite_border,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          // 排序选择
          PopupMenuButton<GallerySortOrder>(
            onSelected: (order) {
              ref.read(galleryNotifierProvider.notifier).setSortOrder(order);
            },
            child: Chip(
              label: Text(_getSortOrderLabel(state.filter.sortOrder, context)),
              avatar: const Icon(Icons.sort, size: 18),
            ),
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: GallerySortOrder.newestFirst,
                child: Row(
                  children: [
                    if (state.filter.sortOrder == GallerySortOrder.newestFirst)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.gallery_sortNewest),
                  ],
                ),
              ),
              PopupMenuItem(
                value: GallerySortOrder.oldestFirst,
                child: Row(
                  children: [
                    if (state.filter.sortOrder == GallerySortOrder.oldestFirst)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.gallery_sortOldest),
                  ],
                ),
              ),
              PopupMenuItem(
                value: GallerySortOrder.favoritesFirst,
                child: Row(
                  children: [
                    if (state.filter.sortOrder ==
                        GallerySortOrder.favoritesFirst)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.gallery_sortFavorite),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 统计按钮
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => GalleryStatisticsDialog.show(context),
            tooltip: context.l10n.statistics_title,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // 记录数量
          Text(
            context.l10n.gallery_imageCount(state.records.length.toString()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.gallery_empty,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.gallery_emptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(BuildContext context, GalleryState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据宽度计算列数
        final crossAxisCount = constraints.maxWidth > 1200
            ? 6
            : constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 600
                    ? 3
                    : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: state.records.length,
          itemBuilder: (context, index) {
            final record = state.records[index];
            final isSelected = state.selectedIds.contains(record.id);

            return _GalleryTile(
              record: record,
              isSelected: isSelected,
              isSelectionMode: state.isSelectionMode,
              onTap: () {
                if (state.isSelectionMode) {
                  ref
                      .read(galleryNotifierProvider.notifier)
                      .toggleSelection(record.id);
                } else {
                  _showFullscreen(context, record);
                }
              },
              onLongPress: () {
                if (!state.isSelectionMode) {
                  ref
                      .read(galleryNotifierProvider.notifier)
                      .enterSelectionMode();
                  ref
                      .read(galleryNotifierProvider.notifier)
                      .toggleSelection(record.id);
                }
              },
              onFavoriteToggle: () {
                ref
                    .read(galleryNotifierProvider.notifier)
                    .toggleFavorite(record.id);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionBar(
    BuildContext context,
    GalleryState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            context.l10n.gallery_selectedCount(state.selectedCount.toString()),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: state.hasSelection
                ? () => _exportSelected(context, state)
                : null,
            icon: const Icon(Icons.download),
            label: Text(context.l10n.common_export),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed:
                state.hasSelection ? () => _deleteSelected(context) : null,
            icon: const Icon(Icons.delete),
            label: Text(context.l10n.common_delete),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortOrderLabel(GallerySortOrder order, BuildContext context) {
    switch (order) {
      case GallerySortOrder.newestFirst:
        return context.l10n.gallery_sortNewest;
      case GallerySortOrder.oldestFirst:
        return context.l10n.gallery_sortOldest;
      case GallerySortOrder.favoritesFirst:
        return context.l10n.gallery_sortFavorite;
    }
  }

  void _handleMenuAction(String action, BuildContext context) {
    switch (action) {
      case 'statistics':
        GalleryStatisticsDialog.show(context);
        break;
      case 'select':
        ref.read(galleryNotifierProvider.notifier).enterSelectionMode();
        break;
      case 'clear':
        _showClearDialog(context);
        break;
    }
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.gallery_clearGallery),
          content: Text(context.l10n.generation_clearHistoryConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(galleryNotifierProvider.notifier).clearAll();
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(context.l10n.common_clear),
            ),
          ],
        );
      },
    );
  }

  void _deleteSelected(BuildContext context) {
    final count = ref.read(galleryNotifierProvider).selectedCount;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.common_delete),
          content: Text(context.l10n.gallery_selectedCount(count.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(galleryNotifierProvider.notifier).deleteSelected();
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(context.l10n.common_delete),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportSelected(BuildContext context, GalleryState state) async {
    // 在任何异步操作前保存引用，避免跨异步间隙使用 context
    final l10n = context.l10n;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 选择导出目录
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final notifier = ref.read(galleryNotifierProvider.notifier);
    int successCount = 0;

    for (final record in state.selectedRecords) {
      final path = await notifier.exportImage(record, result);
      if (path != null) successCount++;
    }

    if (mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.gallery_exportSuccess(successCount.toString(), result),
          ),
        ),
      );
      notifier.exitSelectionMode();
    }
  }

  void _showFullscreen(BuildContext context, GenerationRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenViewer(record: record),
      ),
    );
  }
}

/// 画廊瓷砖组件
class _GalleryTile extends StatelessWidget {
  final GenerationRecord record;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;

  const _GalleryTile({
    required this.record,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 3,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isSelected ? 9 : 12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 图像
                _buildImage(),
                // 悬停显示元数据
                Positioned.fill(
                  child: _buildHoverOverlay(theme),
                ),
                // 选择指示器
                if (isSelectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                // 收藏按钮
                if (!isSelectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          record.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: record.isFavorite ? Colors.red : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                // 底部信息
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          record.promptPreview,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              record.resolution,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              record.formattedCreatedAt,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (record.imageData != null) {
      return Image.memory(
        record.imageData!,
        fit: BoxFit.cover,
      );
    } else if (record.filePath != null) {
      return Image.file(
        File(record.filePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 48),
          );
        },
      );
    } else {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 48),
      );
    }
  }

  Widget _buildHoverOverlay(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// 全屏查看器
class _FullscreenViewer extends ConsumerWidget {
  final GenerationRecord record;

  const _FullscreenViewer({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              record.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: record.isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: () {
              ref
                  .read(galleryNotifierProvider.notifier)
                  .toggleFavorite(record.id);
            },
            tooltip: context.l10n.gallery_favorite,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showMetadata(context),
            tooltip: context.l10n.common_more,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveImage(context, ref),
            tooltip: context.l10n.common_save,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteImage(context, ref),
            tooltip: context.l10n.common_delete,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: _buildFullImage(),
        ),
      ),
    );
  }

  Widget _buildFullImage() {
    if (record.imageData != null) {
      return Image.memory(
        record.imageData!,
        fit: BoxFit.contain,
      );
    } else if (record.filePath != null) {
      return Image.file(
        File(record.filePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 64, color: Colors.white),
          );
        },
      );
    } else {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 64, color: Colors.white),
      );
    }
  }

  void _showMetadata(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                    context.l10n.gallery_generationParams,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaModel,
                    record.params.model,
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaResolution,
                    record.resolution,
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaSteps,
                    record.params.steps.toString(),
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaSampler,
                    record.params.sampler,
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaCfgScale,
                    record.params.scale.toString(),
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaSeed,
                    record.params.seed.toString(),
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaSmea,
                    record.params.smea
                        ? context.l10n.gallery_metaSmeaOn
                        : context.l10n.gallery_metaSmeaOff,
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaGenerationTime,
                    record.createdAt.toString(),
                  ),
                  _buildMetadataRow(
                    context,
                    context.l10n.gallery_metaFileSize,
                    record.formattedFileSize,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.gallery_positivePrompt,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(record.params.prompt),
                  if (record.params.negativePrompt.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.gallery_negativePrompt,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(record.params.negativePrompt),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _saveImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final path = await ref.read(galleryNotifierProvider.notifier).exportImage(
          record,
          result,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null
                ? context.l10n.gallery_savedTo(path)
                : context.l10n.gallery_saveFailed,
          ),
        ),
      );
    }
  }

  void _deleteImage(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.gallery_deleteImage),
          content: Text(context.l10n.gallery_deleteImageConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(galleryNotifierProvider.notifier)
                    .deleteRecord(record.id);
                Navigator.pop(dialogContext); // 关闭对话框
                Navigator.pop(context); // 返回画廊
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(context.l10n.common_delete),
            ),
          ],
        );
      },
    );
  }
}
