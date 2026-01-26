import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/models/gallery/local_image_record.dart';

/// Date group for organizing images by time periods
enum ImageDateGroup {
  today,
  yesterday,
  thisWeek,
  earlier,
}

/// Data class representing a group of images with their date category
class ImageGroup {
  const ImageGroup({
    required this.category,
    required this.images,
    required this.title,
  });

  final ImageDateGroup category;
  final List<LocalImageRecord> images;
  final String title;
}

/// Grouped grid view widget with date-based sections
/// 按日期分组的网格视图组件
class GroupedGridView extends ConsumerStatefulWidget {
  const GroupedGridView({
    super.key,
    required this.images,
    required this.columns,
    required this.itemWidth,
    required this.selectionMode,
    required this.buildSelected,
    required this.buildCard,
    this.onScrollToGroup,
  });

  /// All images to display (will be grouped automatically)
  /// 所有要显示的图片（将自动分组）
  final List<LocalImageRecord> images;

  /// Number of columns in the grid
  /// 网格列数
  final int columns;

  /// Width of each grid item
  /// 每个网格项的宽度
  final double itemWidth;

  /// Whether selection mode is active
  /// 是否处于选择模式
  final bool selectionMode;

  /// Build whether an image is selected
  /// 构建图片是否被选中
  final bool Function(String imagePath) buildSelected;

  /// Build the card widget for each image
  /// 为每个图片构建卡片组件
  final Widget Function(LocalImageRecord record) buildCard;

  /// Callback when scrolling to a specific group
  /// 滚动到特定组时的回调
  final void Function(ImageDateGroup category)? onScrollToGroup;

  @override
  ConsumerState<GroupedGridView> createState() => GroupedGridViewState();
}

/// Public state class for accessing scrollToGroup method
/// 用于访问 scrollToGroup 方法的公共状态类
class GroupedGridViewState extends ConsumerState<GroupedGridView> {
  final ScrollController _scrollController = ScrollController();
  final Map<ImageDateGroup, GlobalKey> _groupKeys = {};

  @override
  void initState() {
    super.initState();
    // Initialize keys for each group
    // 为每个组初始化键
    for (final category in ImageDateGroup.values) {
      _groupKeys[category] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Group images by date category
  /// 按日期类别对图片进行分组
  List<ImageGroup> _groupImagesByDate(List<LocalImageRecord> images) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    final Map<ImageDateGroup, List<LocalImageRecord>> grouped = {
      ImageDateGroup.today: [],
      ImageDateGroup.yesterday: [],
      ImageDateGroup.thisWeek: [],
      ImageDateGroup.earlier: [],
    };

    final l10n = AppLocalizations.of(context)!;

    for (final image in images) {
      final imageDate = DateTime(
        image.modifiedAt.year,
        image.modifiedAt.month,
        image.modifiedAt.day,
      );

      if (imageDate == today) {
        grouped[ImageDateGroup.today]!.add(image);
      } else if (imageDate == yesterday) {
        grouped[ImageDateGroup.yesterday]!.add(image);
      } else if (imageDate.isAfter(thisWeekStart) &&
          imageDate.isBefore(today)) {
        grouped[ImageDateGroup.thisWeek]!.add(image);
      } else {
        grouped[ImageDateGroup.earlier]!.add(image);
      }
    }

    // Convert to list of ImageGroup, filtering out empty groups
    // 转换为 ImageGroup 列表，过滤掉空组
    final groups = <ImageGroup>[];

    if (grouped[ImageDateGroup.today]!.isNotEmpty) {
      groups.add(
        ImageGroup(
          category: ImageDateGroup.today,
          images: grouped[ImageDateGroup.today]!,
          title: l10n.localGallery_group_today,
        ),
      );
    }

    if (grouped[ImageDateGroup.yesterday]!.isNotEmpty) {
      groups.add(
        ImageGroup(
          category: ImageDateGroup.yesterday,
          images: grouped[ImageDateGroup.yesterday]!,
          title: l10n.localGallery_group_yesterday,
        ),
      );
    }

    if (grouped[ImageDateGroup.thisWeek]!.isNotEmpty) {
      groups.add(
        ImageGroup(
          category: ImageDateGroup.thisWeek,
          images: grouped[ImageDateGroup.thisWeek]!,
          title: l10n.localGallery_group_thisWeek,
        ),
      );
    }

    if (grouped[ImageDateGroup.earlier]!.isNotEmpty) {
      groups.add(
        ImageGroup(
          category: ImageDateGroup.earlier,
          images: grouped[ImageDateGroup.earlier]!,
          title: l10n.localGallery_group_earlier,
        ),
      );
    }

    return groups;
  }

  /// Scroll to a specific group
  /// 滚动到特定组
  void scrollToGroup(ImageDateGroup category) {
    final key = _groupKeys[category];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      widget.onScrollToGroup?.call(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupImagesByDate(widget.images);

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            // 组标题
            Container(
              key: _groupKeys[group.category],
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    group.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${group.images.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grid for this group
            // 该组的网格
            MasonryGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: widget.columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: group.images.length,
              itemBuilder: (context, index) {
                final record = group.images[index];
                return widget.buildCard(record);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
