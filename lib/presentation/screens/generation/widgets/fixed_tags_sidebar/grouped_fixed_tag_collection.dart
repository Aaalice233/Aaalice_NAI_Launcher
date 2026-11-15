import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../sidebar_entry_tile.dart';
import 'fixed_tags_sidebar_layout.dart';
import 'fixed_tags_sidebar_models.dart';

typedef FixedTagGroupEntryBuilder =
    Widget Function(
      FixedTagEntry entry,
      Color categoryColor,
      SidebarDragHandleBuilder? dragHandleBuilder,
    );

typedef FixedTagGroupReorderCallback =
    void Function(List<FixedTagEntry> entries, int oldIndex, int newIndex);

typedef FixedTagListPrototypeBuilder = Widget Function(Color categoryColor);

class GroupedFixedTagCollection extends StatefulWidget {
  const GroupedFixedTagCollection({
    super.key,
    required this.keyPrefix,
    required this.sections,
    required this.isListMode,
    required this.forceExpanded,
    required this.filtered,
    required this.controller,
    required this.initialCollapsedSectionIds,
    required this.onCollapsedSectionsChanged,
    required this.emptyText,
    required this.listPrototypeBuilder,
    required this.entryBuilder,
    required this.onReorder,
    required this.onVisibilityChanged,
  });

  final String keyPrefix;
  final List<FixedTagSection> sections;
  final bool isListMode;
  final bool forceExpanded;
  final bool filtered;
  final ScrollController controller;
  final Set<String> initialCollapsedSectionIds;
  final ValueChanged<Set<String>> onCollapsedSectionsChanged;
  final String emptyText;
  final FixedTagListPrototypeBuilder listPrototypeBuilder;
  final FixedTagGroupEntryBuilder entryBuilder;
  final FixedTagGroupReorderCallback onReorder;
  final VoidCallback onVisibilityChanged;

  @override
  State<GroupedFixedTagCollection> createState() =>
      GroupedFixedTagCollectionState();
}

class GroupedFixedTagCollectionState extends State<GroupedFixedTagCollection> {
  late final Set<String> _collapsedSectionIds;
  // 条目在重排后会换 index，索引无关的 key 才能让 tile 的 hover 与动画状态跟着条目走。
  final _entryItemKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _collapsedSectionIds = {...widget.initialCollapsedSectionIds};
  }

  @override
  void didUpdateWidget(covariant GroupedFixedTagCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 筛选只是暂时藏起分组，此时清理会丢掉完整列表的折叠状态。
    if (!widget.filtered) {
      final availableIds = widget.sections.map((section) => section.id).toSet();
      final collapsedCount = _collapsedSectionIds.length;
      _collapsedSectionIds.removeWhere((id) => !availableIds.contains(id));
      if (_collapsedSectionIds.length != collapsedCount) {
        _rememberCollapsedSections();
      }
    }
    final entryIds = <String>{
      for (final section in widget.sections)
        for (final entry in section.entries) entry.id,
    };
    _entryItemKeys.removeWhere((id, _) => !entryIds.contains(id));
  }

  void _setSectionCollapsed(String sectionId, bool collapsed) {
    setState(() {
      if (collapsed) {
        _collapsedSectionIds.add(sectionId);
      } else {
        _collapsedSectionIds.remove(sectionId);
      }
    });
    _rememberCollapsedSections();
    widget.onVisibilityChanged();
  }

  void setAllCollapsed(bool collapsed) {
    setState(() {
      if (collapsed) {
        _collapsedSectionIds.addAll(
          widget.sections.map((section) => section.id),
        );
      } else {
        _collapsedSectionIds.clear();
      }
    });
    _rememberCollapsedSections();
    widget.onVisibilityChanged();
  }

  void _rememberCollapsedSections() =>
      widget.onCollapsedSectionsChanged(_collapsedSectionIds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.emptyText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 同一 Scrollable 换 controller 会带走旧像素，筛选视图必须另起一个。
    return CustomScrollView(
      key: ValueKey(
        widget.filtered
            ? '${widget.keyPrefix}-filtered-group-list'
            : '${widget.keyPrefix}-group-list',
      ),
      controller: widget.controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
          sliver: SliverMainAxisGroup(
            slivers: [
              for (final section in widget.sections)
                _buildSectionSliver(context, section),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSliver(BuildContext context, FixedTagSection section) {
    final isCollapsed =
        !widget.forceExpanded && _collapsedSectionIds.contains(section.id);
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 6),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              context,
              section: section,
              isCollapsed: isCollapsed,
            ),
          ),
          if (!isCollapsed) _buildSectionBodySliver(section),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required FixedTagSection section,
    required bool isCollapsed,
  }) {
    final theme = Theme.of(context);
    final canCollapse = !widget.forceExpanded;
    return Material(
      key: ValueKey('${widget.keyPrefix}-group-${section.id}'),
      color: Color.alphaBlend(
        section.color.withValues(alpha: 0.07),
        theme.colorScheme.surfaceContainerLow,
      ),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canCollapse
            ? () => _setSectionCollapsed(section.id, !isCollapsed)
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, size: 17, color: section.color),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    section.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: section.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    section.entries.length.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: section.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBodySliver(FixedTagSection section) {
    return SliverPadding(
      key: ValueKey('${widget.keyPrefix}-group-${section.id}-body'),
      padding: const EdgeInsets.only(top: 4),
      sliver: widget.isListMode
          ? _buildEntryListSliver(section)
          : _buildEntryGridSliver(section),
    );
  }

  Widget _buildEntryListSliver(FixedTagSection section) {
    return SliverReorderableList(
      key: ValueKey('${widget.keyPrefix}-group-${section.id}-entries'),
      itemCount: section.entries.length,
      prototypeItem: widget.listPrototypeBuilder(section.color),
      proxyDecorator: _buildDragProxy,
      onReorderItem: (oldIndex, newIndex) =>
          widget.onReorder(section.entries, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final entry = section.entries[index];
        return KeyedSubtree(
          key: _entryItemKeys.putIfAbsent(entry.id, GlobalKey.new),
          child: Padding(
            key: ValueKey('${widget.keyPrefix}-entry-${entry.id}'),
            padding: const EdgeInsets.only(bottom: 4),
            child: widget.entryBuilder(
              entry,
              section.color,
              section.entries.length > 1
                  ? (child) =>
                        ReorderableDragStartListener(index: index, child: child)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEntryGridSliver(FixedTagSection section) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const spacing = 7.0;
        final largeText = MediaQuery.textScalerOf(context).scale(14) >= 20;
        // 触屏下底行操作变宽，列宽按底行需求兜底，只有单列仍放不下时才收进更多菜单。
        final minimumCardWidth = math.max(
          largeText ? 220.0 : 140.0,
          SidebarEntryTile.minimumCardWidthOf(context),
        );
        final columnCount =
            ((constraints.crossAxisExtent + spacing) /
                    (minimumCardWidth + spacing))
                .floor()
                .clamp(1, 3);
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: gridCardHeight(context),
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, index) =>
              widget.entryBuilder(section.entries[index], section.color, null),
        );
      },
    );
  }

  // SliverReorderableList 不带默认拖拽装饰，抬升要自己补回来。
  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    const draggingElevation = 6.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Material(elevation: draggingElevation, child: child);
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, proxyChild) => Material(
        elevation:
            draggingElevation * Curves.easeInOut.transform(animation.value),
        child: proxyChild,
      ),
      child: child,
    );
  }
}
