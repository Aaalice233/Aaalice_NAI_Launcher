import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/models/gallery/local_image_record.dart';
import '../utils/image_date_grouping.dart';

/// 按日期分组的网格视图组件
class GroupedGridView extends ConsumerStatefulWidget {
  const GroupedGridView({
    super.key,
    required this.images,
    required this.columns,
    required this.itemWidth,
    required this.buildCard,
    this.onScrollToGroup,
    @visibleForTesting this.clock = DateTime.now,
  });

  final List<LocalImageRecord> images;
  final int columns;
  final double itemWidth;
  final Widget Function(LocalImageRecord record) buildCard;
  final void Function(ImageDateGroup category)? onScrollToGroup;
  final DateTime Function() clock;

  @override
  ConsumerState<GroupedGridView> createState() => GroupedGridViewState();
}

class GroupedGridViewState extends ConsumerState<GroupedGridView> {
  final ScrollController _scrollController = ScrollController();
  final Map<ImageDateGroup, GlobalKey> _groupKeys = {};
  List<LocalImageRecord>? _groupedSource;
  (int, int, int)? _groupedDay;
  List<ImageGroup> _groups = const [];

  @visibleForTesting
  List<ImageGroup> get debugGroups => _groups;

  @override
  void initState() {
    super.initState();
    for (final category in ImageDateGroup.values) {
      _groupKeys[category] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<ImageGroup> _currentGroups() {
    final now = widget.clock();
    final day = (now.year, now.month, now.day);
    final source = widget.images;
    if (day != _groupedDay || !_hasSameRecords(_groupedSource, source)) {
      _groups = groupImagesByDate(source, now);
      _groupedSource = source;
      _groupedDay = day;
    }
    return _groups;
  }

  // freezed 的列表 getter 每次返回新视图，只能逐项比较记录实例
  static bool _hasSameRecords(
    List<LocalImageRecord>? previous,
    List<LocalImageRecord> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous == null || previous.length != next.length) return false;
    for (var index = 0; index < next.length; index++) {
      if (!identical(previous[index], next[index])) return false;
    }
    return true;
  }

  String _titleOf(AppLocalizations l10n, ImageDateGroup category) =>
      switch (category) {
        ImageDateGroup.today => l10n.localGallery_group_today,
        ImageDateGroup.yesterday => l10n.localGallery_group_yesterday,
        ImageDateGroup.thisWeek => l10n.localGallery_group_thisWeek,
        ImageDateGroup.earlier => l10n.localGallery_group_earlier,
      };

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
    final groups = _currentGroups();

    if (groups.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    final lastIndex = groups.length - 1;

    // 分组必须是同一 viewport 下的 sliver：shrinkWrap 网格拿到无界主轴约束，
    // 会为了算高度把整组图片一次性布局出来。
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        for (final (index, group) in groups.indexed) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, index == 0 ? 12 : 0, 12, 8),
            sliver: SliverToBoxAdapter(
              child: _GroupHeader(
                key: _groupKeys[group.category],
                title: _titleOf(l10n, group.category),
                count: group.images.length,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              index == lastIndex ? 28 : 16,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: widget.columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childCount: group.images.length,
              itemBuilder: (context, itemIndex) =>
                  widget.buildCard(group.images[itemIndex]),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
