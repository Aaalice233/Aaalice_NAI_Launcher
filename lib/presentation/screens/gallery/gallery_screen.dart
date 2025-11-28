import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../data/models/gallery/generation_record.dart';
import '../../providers/gallery_provider.dart';
import '../../widgets/autocomplete/autocomplete.dart';

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
        title: Text('已选择 ${state.selectedCount} 项'),
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
            tooltip: '全选',
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('画廊'),
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
          tooltip: '搜索',
        ),
        if (state.records.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, context),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'select',
                child: ListTile(
                  leading: Icon(Icons.check_box_outlined),
                  title: Text('选择'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('清除所有'),
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
          hintText: '搜索提示词... (支持中英文标签)',
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
            label: const Text('收藏'),
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
              label: Text(_getSortOrderLabel(state.filter.sortOrder)),
              avatar: const Icon(Icons.sort, size: 18),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: GallerySortOrder.newestFirst,
                child: Row(
                  children: [
                    if (state.filter.sortOrder == GallerySortOrder.newestFirst)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    const Text('最新优先'),
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
                    const Text('最旧优先'),
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
                    const Text('收藏优先'),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 记录数量
          Text(
            '${state.records.length} 张',
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
            '画廊为空',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '生成的图像将显示在这里',
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
          Text('已选择 ${state.selectedCount} 张'),
          const Spacer(),
          TextButton.icon(
            onPressed: state.hasSelection
                ? () => _exportSelected(context, state)
                : null,
            icon: const Icon(Icons.download),
            label: const Text('导出'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed:
                state.hasSelection ? () => _deleteSelected(context) : null,
            icon: const Icon(Icons.delete),
            label: const Text('删除'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortOrderLabel(GallerySortOrder order) {
    switch (order) {
      case GallerySortOrder.newestFirst:
        return '最新';
      case GallerySortOrder.oldestFirst:
        return '最旧';
      case GallerySortOrder.favoritesFirst:
        return '收藏';
    }
  }

  void _handleMenuAction(String action, BuildContext context) {
    switch (action) {
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
      builder: (context) {
        return AlertDialog(
          title: const Text('清除画廊'),
          content: const Text('确定要清除所有图像吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(galleryNotifierProvider.notifier).clearAll();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('清除'),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('删除图像'),
          content: Text('确定要删除选中的 $count 张图像吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(galleryNotifierProvider.notifier).deleteSelected();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportSelected(BuildContext context, GalleryState state) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 $successCount 张图像到 $result')),
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
    final theme = Theme.of(context);

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
            tooltip: '收藏',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showMetadata(context),
            tooltip: '元数据',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveImage(context, ref),
            tooltip: '保存',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteImage(context, ref),
            tooltip: '删除',
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
                  const Text(
                    '生成参数',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMetadataRow('模型', record.params.model),
                  _buildMetadataRow('分辨率', record.resolution),
                  _buildMetadataRow('步数', record.params.steps.toString()),
                  _buildMetadataRow('采样器', record.params.sampler),
                  _buildMetadataRow(
                      'CFG Scale', record.params.scale.toString()),
                  _buildMetadataRow('Seed', record.params.seed.toString()),
                  _buildMetadataRow('SMEA', record.params.smea ? '开启' : '关闭'),
                  _buildMetadataRow('生成时间', record.createdAt.toString()),
                  _buildMetadataRow('文件大小', record.formattedFileSize),
                  const SizedBox(height: 16),
                  const Text(
                    '正向提示词',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(record.params.prompt),
                  if (record.params.negativePrompt.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '负向提示词',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
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
          content: Text(path != null ? '已保存到 $path' : '保存失败'),
        ),
      );
    }
  }

  void _deleteImage(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除图像'),
          content: const Text('确定要删除这张图像吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(galleryNotifierProvider.notifier)
                    .deleteRecord(record.id);
                Navigator.pop(context); // 关闭对话框
                Navigator.pop(context); // 返回画廊
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}
