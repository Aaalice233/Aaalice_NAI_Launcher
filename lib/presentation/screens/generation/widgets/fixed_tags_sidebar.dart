import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/fixed_tag/fixed_tag_link.dart';
import '../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/tile_action_button.dart';
import '../../../widgets/prompt/fixed_tag_edit_dialog.dart';
import '../../../widgets/tag_library/tag_library_picker_dialog.dart';
import 'sidebar_entry_tile.dart';
import 'sidebar_link_painter.dart';

const _uncategorizedSectionId = '__uncategorized__';
const _linkDetachDistance = 36.0;

bool _paneHeaderUsesLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 28;

EdgeInsets _paneHeaderPadding(BuildContext context) =>
    _paneHeaderUsesLargeText(context)
    ? const EdgeInsets.fromLTRB(8, 2, 4, 2)
    : const EdgeInsets.fromLTRB(10, 8, 6, 6);

double _scaledLineExtent(BuildContext context, TextStyle? style) {
  final fontSize = MediaQuery.textScalerOf(
    context,
  ).scale(style?.fontSize ?? 14);
  return fontSize * (style?.height ?? 1.45);
}

// 标题行取名称与计数徽标中较高者，徽标另算自身竖向内边距。
double _paneHeaderTitleExtent(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return math.max(
    _scaledLineExtent(context, textTheme.labelLarge),
    _scaledLineExtent(context, textTheme.labelSmall) + 4,
  );
}

// 文字缩放器可能非线性，就地按标题字号取斜率，压缩比才落在标题真实行高上。
double _paneHeaderTextScaleFactor(BuildContext context) {
  final fontSize = Theme.of(context).textTheme.labelLarge?.fontSize ?? 14;
  return MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
}

// 高度预算与 _buildPaneHeader 的实际布局必须同源：预算低估会让 _buildPaneCard 的 Column 溢出。
double _paneHeaderExtent(BuildContext context) =>
    math.max(
      _paneHeaderTitleExtent(context),
      context.interactionPolicy.minimumControlExtent,
    ) +
    _paneHeaderPadding(context).vertical;

double _gridCardHeight(BuildContext context) {
  final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
  // 底行取链接锚点与操作按钮中较高者：前者看有无精确指针，后者看有无触摸，两条规则会错配。
  final footerExtent = math.max(
    context.interactionPolicy.precisePointerAvailable ? 24.0 : 44.0,
    TileActionButton.extentOf(context),
  );
  // 带缩略图的卡片最紧：正文只有一行，但正文区仅分到卡片 5/8 高度，按它标定基准。
  const contentInsets = 20.0; // 上下内边距 15 + 正文与底行间距 5
  const singleLineText = 36.0; // 名称 20 + 单行正文 16
  final baseHeight =
      (contentInsets + singleLineText + footerExtent) * 8 / 5 + 12;
  final scaledTextGrowth = (scaledLabelSize - 14).clamp(0.0, double.infinity);
  return baseHeight + scaledTextGrowth * 6;
}

/// 桌面端固定词侧边栏。
class FixedTagsSidebar extends ConsumerStatefulWidget {
  const FixedTagsSidebar({super.key});

  @override
  ConsumerState<FixedTagsSidebar> createState() => _FixedTagsSidebarState();
}

class _FixedTagsSidebarState extends ConsumerState<FixedTagsSidebar> {
  final _searchController = TextEditingController();
  final _positiveScrollController = ScrollController();
  final _negativeScrollController = ScrollController();
  final _positiveGroupsKey = GlobalKey<_GroupedFixedTagCollectionState>();
  final _negativeGroupsKey = GlobalKey<_GroupedFixedTagCollectionState>();
  final _linkLayerKey = GlobalKey();
  final _positiveAnchorKeys = <String, GlobalKey>{};
  final _negativeAnchorKeys = <String, GlobalKey>{};

  var _positiveAnchorCenters = <String, Offset>{};
  var _negativeAnchorCenters = <String, Offset>{};
  _LinkDragPreview? _linkDragPreview;
  String _searchQuery = '';
  String? _highlightedLinkEntryId;
  bool _linkRepaintScheduled = false;
  double? _draggedNegativePaneHeight;
  bool _isNegativeDividerHovered = false;
  bool _showOnlyEnabledPositive = false;
  bool _showOnlyEnabledNegative = false;

  @override
  void initState() {
    super.initState();
    _positiveScrollController.addListener(_scheduleLinkRepaint);
    _negativeScrollController.addListener(_scheduleLinkRepaint);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(fixedTagsNotifierProvider.notifier).inferCategoriesFromLibrary();
      _scheduleLinkRepaint();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positiveScrollController.dispose();
    _negativeScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedState = ref.watch(fixedTagsNotifierProvider);
    final layoutState = ref.watch(layoutStateNotifierProvider);
    final categories = ref.watch(tagLibraryPageCategoriesProvider);
    final libraryEntries = ref.watch(
      tagLibraryPageNotifierProvider.select((state) => state.entries),
    );
    final isListMode = layoutState.fixedTagsSidebarViewMode == 'list';
    final query = _searchQuery.trim();
    final positiveSource = _showOnlyEnabledPositive
        ? fixedState.enabledEntries
        : fixedState.positiveEntries;
    final negativeSource = _showOnlyEnabledNegative
        ? fixedState.negativeEnabledEntries
        : fixedState.negativeEntries;
    final positiveEntries = query.isEmpty
        ? positiveSource
        : positiveSource.search(query);
    final negativeEntries = query.isEmpty
        ? negativeSource
        : negativeSource.search(query);
    final positiveSections = _tagSections(positiveEntries, categories);
    final negativeSections = _tagSections(negativeEntries, categories);
    _pruneAnchorKeys(fixedState);
    _scheduleLinkRepaint();

    return Stack(
      key: _linkLayerKey,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopCard(theme, fixedState, isListMode),
            Expanded(
              child: _buildTagPanes(
                theme,
                layoutState,
                fixedState,
                positiveSections,
                negativeSections,
                libraryEntries,
                isListMode,
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SidebarLinkPainter(
                links: _visibleLinks(fixedState),
                isMismatched: fixedState.isMismatched,
                color: theme.colorScheme.secondary,
                positiveAnchors: _positiveAnchorCenters,
                negativeAnchors: _negativeAnchorCenters,
                previewStart: _linkDragPreview?.start,
                previewEnd: _linkDragPreview?.end,
                previewIsDetaching: _linkDragPreview?.isDetaching ?? false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCard(
    ThemeData theme,
    FixedTagsState fixedState,
    bool isListMode,
  ) {
    return Container(
      key: const ValueKey('fixed-tags-top-card'),
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(theme.colorScheme),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme, fixedState, isListMode),
          _buildSearchBar(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    FixedTagsState fixedState,
    bool isListMode,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          Icon(
            Icons.push_pin_rounded,
            size: 18,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.fixedTags_sidebarTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.l10n.fixedTags_enabledCount(
                    fixedState.enabledCount + fixedState.negativeEnabledCount,
                    fixedState.entries.length,
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isListMode
                ? context.l10n.fixedTags_switchGridView
                : context.l10n.fixedTags_switchListView,
            icon: Icon(
              isListMode ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
              size: 18,
            ),
            onPressed: () {
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setFixedTagsSidebarViewMode(isListMode ? 'grid' : 'list');
            },
          ),
          PopupMenuButton<_AddAction>(
            tooltip: context.l10n.fixedTags_add,
            icon: const Icon(Icons.add_rounded, size: 20),
            onSelected: (action) {
              switch (action) {
                case _AddAction.positive:
                  _addEntry();
                  break;
                case _AddAction.negative:
                  _addEntry(promptType: FixedTagPromptType.negative);
                  break;
                case _AddAction.libraryPositive:
                  _addFromLibrary(FixedTagPromptType.positive);
                  break;
                case _AddAction.libraryNegative:
                  _addFromLibrary(FixedTagPromptType.negative);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AddAction.positive,
                child: Text(context.l10n.fixedTags_addPositive),
              ),
              PopupMenuItem(
                value: _AddAction.negative,
                child: Text(context.l10n.fixedTags_addNegative),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _AddAction.libraryPositive,
                child: Text(context.l10n.fixedTags_addPositiveFromLibrary),
              ),
              PopupMenuItem(
                value: _AddAction.libraryNegative,
                child: Text(context.l10n.fixedTags_addNegativeFromLibrary),
              ),
            ],
          ),
          IconButton(
            key: const ValueKey('fixed-tags-collapse-sidebar'),
            tooltip: context.l10n.nav_collapseSidebar,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () {
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setFixedTagsSidebarExpanded(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: context.l10n.fixedTags_searchNameOrContent,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.fixedTags_clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  Widget _buildTagPanes(
    ThemeData theme,
    LayoutState layoutState,
    FixedTagsState fixedState,
    List<_TagSection> positiveSections,
    List<_TagSection> negativeSections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const panePadding = EdgeInsets.fromLTRB(8, 0, 8, 8);
        final dividerHeight = context.interactionPolicy.prefersTouchPresentation
            ? context.interactionPolicy.minimumControlExtent
            : 16.0;
        final usableHeight =
            (constraints.maxHeight - panePadding.vertical - dividerHeight)
                .clamp(0.0, double.infinity)
                .toDouble();
        final hasPositiveEntries = fixedState.positiveEntries.isNotEmpty;
        final hasNegativeEntries = fixedState.negativeEntries.isNotEmpty;
        // 面板头跟随文字缩放，正文下限保持定值：跟着放大会在大字号下抢走用户拖出来的分栏高度。
        final paneHeaderMinimumHeight = _paneHeaderExtent(context);
        const populatedMinimumHeight = 138.0;
        final emptyMinimumHeight = paneHeaderMinimumHeight;
        final desiredPositiveMinimum = !hasPositiveEntries
            ? emptyMinimumHeight
            : isListMode
            ? populatedMinimumHeight
            : 274.0;
        final desiredNegativeMinimum = !hasNegativeEntries
            ? emptyMinimumHeight
            : populatedMinimumHeight;
        final headerMinimumTotal = paneHeaderMinimumHeight * 2;
        final bodyBudget = math.max(0.0, usableHeight - headerMinimumTotal);
        final desiredPositiveBody = math.max(
          0.0,
          desiredPositiveMinimum - paneHeaderMinimumHeight,
        );
        final desiredNegativeBody = math.max(
          0.0,
          desiredNegativeMinimum - paneHeaderMinimumHeight,
        );
        final desiredBodyTotal = desiredPositiveBody + desiredNegativeBody;
        final bodyScale = desiredBodyTotal == 0
            ? 0.0
            : math.min(1.0, bodyBudget / desiredBodyTotal);
        final headerScale = math.min(1.0, usableHeight / headerMinimumTotal);
        final positiveMinimumHeight =
            paneHeaderMinimumHeight * headerScale +
            desiredPositiveBody * bodyScale;
        final negativeMinimumHeight =
            paneHeaderMinimumHeight * headerScale +
            desiredNegativeBody * bodyScale;
        final maximumNegativeHeight = math.max(
          negativeMinimumHeight,
          usableHeight - positiveMinimumHeight,
        );
        final boundedMaximumNegativeHeight = math.min(
          maximumNegativeHeight,
          fixedTagsNegativePaneMaxHeight,
        );
        final boundedMinimumNegativeHeight = math.min(
          boundedMaximumNegativeHeight,
          math.max(negativeMinimumHeight, fixedTagsNegativePaneMinHeight),
        );
        final requestedNegativeHeight =
            _draggedNegativePaneHeight ?? layoutState.fixedTagsNegativeHeight;
        final negativeHeight = requestedNegativeHeight
            .clamp(boundedMinimumNegativeHeight, boundedMaximumNegativeHeight)
            .toDouble();
        final positiveHeight = usableHeight - negativeHeight;

        return Padding(
          padding: panePadding,
          child: Column(
            children: [
              SizedBox(
                key: const ValueKey('fixed-tags-positive-pane'),
                height: positiveHeight,
                child: _buildPositiveArea(
                  theme,
                  positiveSections,
                  libraryEntries,
                  isListMode,
                  positiveHeight,
                ),
              ),
              _buildNegativeResizeDivider(
                theme,
                renderedNegativeHeight: negativeHeight,
                minimumNegativeHeight: boundedMinimumNegativeHeight,
                maximumNegativeHeight: boundedMaximumNegativeHeight,
              ),
              Expanded(
                key: const ValueKey('fixed-tags-negative-pane'),
                child: _buildNegativeArea(
                  theme,
                  negativeSections,
                  libraryEntries,
                  isListMode,
                  negativeHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositiveArea(
    ThemeData theme,
    List<_TagSection> sections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
    double paneHeight,
  ) {
    final entryCount = sections.fold<int>(
      0,
      (count, section) => count + section.entries.length,
    );

    return _buildPaneCard(
      theme,
      key: const ValueKey('fixed-tags-positive-card'),
      accent: theme.colorScheme.primary,
      paneHeight: paneHeight,
      headerBuilder: (headerExtent) => _buildPaneHeader(
        icon: Icons.add_circle_outline_rounded,
        label: context.l10n.fixedTags_positiveTitle,
        count: entryCount,
        color: theme.colorScheme.primary,
        maxExtent: headerExtent,
        trailingBuilder: (iconOnly) => _buildGroupHeaderActions(
          keyPrefix: 'fixed-tags-positive',
          groupsKey: _positiveGroupsKey,
          iconOnly: iconOnly,
          showBulkActions: _searchQuery.trim().isEmpty,
          enabledOnly: _showOnlyEnabledPositive,
          accent: theme.colorScheme.primary,
          onToggleEnabledOnly: () => setState(
            () => _showOnlyEnabledPositive = !_showOnlyEnabledPositive,
          ),
        ),
      ),
      body: _GroupedFixedTagCollection(
        key: _positiveGroupsKey,
        keyPrefix: 'fixed-tags-positive',
        sections: sections,
        isListMode: isListMode,
        forceExpanded: _searchQuery.trim().isNotEmpty,
        controller: _positiveScrollController,
        emptyText: _searchQuery.isNotEmpty
            ? context.l10n.fixedTags_noMatchingEnabled
            : _showOnlyEnabledPositive
            ? context.l10n.fixedTags_emptyEnabledPositive
            : context.l10n.fixedTags_empty,
        listPrototypeBuilder: (categoryColor) => _buildListEntryPrototype(
          entry: sections.first.entries.first,
          categoryColor: categoryColor,
        ),
        onVisibilityChanged: _scheduleLinkRepaint,
        onReorder: (entries, oldIndex, newIndex) => ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorderWithinVisibleIds(
              promptType: FixedTagPromptType.positive,
              visibleIds: entries.map((entry) => entry.id).toList(),
              oldIndex: oldIndex,
              newIndex: newIndex,
            ),
        entryBuilder: (entry, categoryColor, dragHandleBuilder) =>
            _buildEntryTile(
              entry: entry,
              categoryColor: categoryColor,
              libraryEntries: libraryEntries,
              isListMode: isListMode,
              dragHandleBuilder: dragHandleBuilder,
            ),
      ),
    );
  }

  Widget _buildPaneCard(
    ThemeData theme, {
    required Key key,
    required Color accent,
    required double paneHeight,
    required Widget Function(double headerExtent) headerBuilder,
    required Widget body,
  }) {
    final baseColor = sectionSurfaceColor(theme.colorScheme);
    final cardTint = theme.brightness == Brightness.dark ? 0.04 : 0.025;
    final headerTint = theme.brightness == Brightness.dark ? 0.09 : 0.065;
    // 面板头不超过整格高度，否则下面的 Expanded 拿到 0 仍会把 Column 撑破；
    // 下界是操作按钮命中区，压过头等于缩小操作入口。
    final headerExtent = math.max(
      context.interactionPolicy.minimumControlExtent,
      math.min(_paneHeaderExtent(context), paneHeight),
    );
    return Material(
      key: key,
      color: Color.alphaBlend(accent.withValues(alpha: cardTint), baseColor),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: Color.alphaBlend(
              accent.withValues(alpha: headerTint),
              baseColor,
            ),
            child: SizedBox(
              height: headerExtent,
              child: headerBuilder(headerExtent),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildPaneHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required double maxExtent,
    Widget Function(bool iconOnly)? trailingBuilder,
  }) {
    final usesLargeText = _paneHeaderUsesLargeText(context);
    final padding = _paneHeaderPadding(context);
    final titleExtent = _paneHeaderTitleExtent(context);
    final actionExtent = context.interactionPolicy.minimumControlExtent;
    // 分到的高度不够时先收内边距再压标题字号，操作按钮命中区不参与压缩。
    final verticalPadding = (maxExtent - math.max(titleExtent, actionExtent))
        .clamp(0.0, padding.vertical)
        .toDouble();
    final paddingScale = padding.vertical == 0
        ? 1.0
        : verticalPadding / padding.vertical;
    final contentExtent = math.max(0.0, maxExtent - verticalPadding);
    final titleScaleFactor = _paneHeaderTextScaleFactor(context);
    final titleMaxScaleFactor = contentExtent >= titleExtent
        ? titleScaleFactor
        : titleScaleFactor * contentExtent / titleExtent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailing = trailingBuilder?.call(
          constraints.maxWidth < 360 || usesLargeText,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top * paddingScale,
            padding.right,
            padding.bottom * paddingScale,
          ),
          child: Row(
            children: [
              Expanded(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: titleMaxScaleFactor,
                  child: _SectionTitle(
                    icon: icon,
                    label: label,
                    count: count,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupHeaderActions({
    required String keyPrefix,
    required GlobalKey<_GroupedFixedTagCollectionState> groupsKey,
    required bool iconOnly,
    required bool showBulkActions,
    required bool enabledOnly,
    required Color accent,
    required VoidCallback onToggleEnabledOnly,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EnabledOnlyAction(
          key: ValueKey('$keyPrefix-enabled-only'),
          selected: enabledOnly,
          color: accent,
          iconOnly: iconOnly,
          label: context.l10n.fixedTags_enabledOnly,
          onPressed: onToggleEnabledOnly,
        ),
        if (showBulkActions) ...[
          const SizedBox(width: 2),
          _GroupBulkAction(
            key: ValueKey('$keyPrefix-expand-all'),
            icon: Icons.unfold_more_rounded,
            label: context.l10n.fixedTags_expandAll,
            iconOnly: true,
            onPressed: () => groupsKey.currentState?.setAllCollapsed(false),
          ),
          const SizedBox(width: 2),
          _GroupBulkAction(
            key: ValueKey('$keyPrefix-collapse-all'),
            icon: Icons.unfold_less_rounded,
            label: context.l10n.fixedTags_collapseAll,
            iconOnly: true,
            onPressed: () => groupsKey.currentState?.setAllCollapsed(true),
          ),
        ],
      ],
    );
  }

  Widget _buildNegativeResizeDivider(
    ThemeData theme, {
    required double renderedNegativeHeight,
    required double minimumNegativeHeight,
    required double maximumNegativeHeight,
  }) {
    final interactionPolicy = context.interactionPolicy;
    final hitHeight = interactionPolicy.prefersTouchPresentation
        ? interactionPolicy.minimumControlExtent
        : 16.0;
    final isActive =
        _isNegativeDividerHovered || _draggedNegativePaneHeight != null;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _isNegativeDividerHovered = true),
      onExit: (_) => setState(() => _isNegativeDividerHovered = false),
      child: GestureDetector(
        key: const ValueKey('fixed-tags-pane-resize-divider'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) {
          setState(() {
            _draggedNegativePaneHeight = renderedNegativeHeight;
          });
        },
        onVerticalDragUpdate: (details) {
          final currentHeight =
              _draggedNegativePaneHeight ?? renderedNegativeHeight;
          final nextHeight = (currentHeight - details.delta.dy)
              .clamp(minimumNegativeHeight, maximumNegativeHeight)
              .toDouble();
          if (nextHeight == currentHeight) return;
          setState(() => _draggedNegativePaneHeight = nextHeight);
        },
        onVerticalDragEnd: (_) => _finishNegativePaneResize(),
        onVerticalDragCancel: _finishNegativePaneResize,
        child: SizedBox(
          height: hitHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              AnimatedContainer(
                key: const ValueKey('fixed-tags-pane-resize-indicator'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                width: isActive ? 48 : 40,
                height: isActive ? 3 : 2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isActive ? 0.95 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishNegativePaneResize() async {
    final finalHeight = _draggedNegativePaneHeight;
    if (finalHeight == null) return;

    final persistence = ref
        .read(layoutStateNotifierProvider.notifier)
        .setFixedTagsNegativeHeight(finalHeight);
    if (mounted) {
      setState(() => _draggedNegativePaneHeight = null);
    }
    await persistence;
  }

  Widget _buildNegativeArea(
    ThemeData theme,
    List<_TagSection> sections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
    double paneHeight,
  ) {
    final entryCount = sections.fold<int>(
      0,
      (count, section) => count + section.entries.length,
    );
    return _buildPaneCard(
      theme,
      key: const ValueKey('fixed-tags-negative-card'),
      accent: theme.colorScheme.error,
      paneHeight: paneHeight,
      headerBuilder: (headerExtent) => _buildPaneHeader(
        icon: Icons.block_rounded,
        label: context.l10n.fixedTags_negativeTitle,
        count: entryCount,
        color: theme.colorScheme.error,
        maxExtent: headerExtent,
        trailingBuilder: (iconOnly) => _buildGroupHeaderActions(
          keyPrefix: 'fixed-tags-negative',
          groupsKey: _negativeGroupsKey,
          iconOnly: iconOnly,
          showBulkActions: _searchQuery.trim().isEmpty,
          enabledOnly: _showOnlyEnabledNegative,
          accent: theme.colorScheme.error,
          onToggleEnabledOnly: () => setState(
            () => _showOnlyEnabledNegative = !_showOnlyEnabledNegative,
          ),
        ),
      ),
      body: _GroupedFixedTagCollection(
        key: _negativeGroupsKey,
        keyPrefix: 'fixed-tags-negative',
        sections: sections,
        isListMode: isListMode,
        forceExpanded: _searchQuery.trim().isNotEmpty,
        controller: _negativeScrollController,
        emptyText: _searchQuery.isNotEmpty
            ? context.l10n.fixedTags_noMatchingNegative
            : _showOnlyEnabledNegative
            ? context.l10n.fixedTags_emptyEnabledNegative
            : context.l10n.fixedTags_emptyNegative,
        listPrototypeBuilder: (categoryColor) => _buildListEntryPrototype(
          entry: sections.first.entries.first,
          categoryColor: categoryColor,
        ),
        onVisibilityChanged: _scheduleLinkRepaint,
        onReorder: (entries, oldIndex, newIndex) => ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorderWithinVisibleIds(
              promptType: FixedTagPromptType.negative,
              visibleIds: entries.map((entry) => entry.id).toList(),
              oldIndex: oldIndex,
              newIndex: newIndex,
            ),
        entryBuilder: (entry, categoryColor, dragHandleBuilder) =>
            _buildEntryTile(
              entry: entry,
              categoryColor: categoryColor,
              libraryEntries: libraryEntries,
              isListMode: isListMode,
              dragHandleBuilder: dragHandleBuilder,
            ),
      ),
    );
  }

  Widget _buildEntryTile({
    required FixedTagEntry entry,
    required Color categoryColor,
    required List<TagLibraryEntry> libraryEntries,
    required bool isListMode,
    SidebarDragHandleBuilder? dragHandleBuilder,
  }) {
    final tile = SidebarEntryTile(
      entry: entry,
      categoryColor: categoryColor,
      isListMode: isListMode,
      libraryEntry: resolveFixedTagLibraryEntry(entry, libraryEntries),
      dragHandleBuilder: dragHandleBuilder,
      linkAnchor: _buildLinkAnchor(entry),
      onToggle: () =>
          ref.read(fixedTagsNotifierProvider.notifier).toggleEnabled(entry.id),
      onEdit: () => _editEntry(entry),
      onDelete: () => _deleteEntry(entry),
    );
    if (entry.promptType == FixedTagPromptType.negative) {
      return _buildNegativeLinkTarget(entry, tile);
    }
    return tile;
  }

  Widget _buildListEntryPrototype({
    required FixedTagEntry entry,
    required Color categoryColor,
  }) {
    final prototypeEntry = entry.copyWith(
      id: '__sidebar-list-prototype__',
      name: 'M',
      content: 'M',
      weight: 1,
      enabled: true,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SidebarEntryTile(
        entry: prototypeEntry,
        categoryColor: categoryColor,
        isListMode: true,
        linkAnchor: SizedBox.square(
          dimension: context.interactionPolicy.precisePointerAvailable
              ? 24
              : 44,
        ),
        onToggle: _noop,
        onEdit: _noop,
        onDelete: _noop,
      ),
    );
  }

  static void _noop() {}

  Widget _buildLinkAnchor(FixedTagEntry entry) {
    final theme = Theme.of(context);
    final anchorExtent = context.interactionPolicy.precisePointerAvailable
        ? 24.0
        : 44.0;
    final state = ref.watch(fixedTagsNotifierProvider);
    final linkedPositiveIds = entry.promptType == FixedTagPromptType.negative
        ? state.linkedPositivesOf(entry.id).map((linked) => linked.id).toList()
        : const <String>[];
    final linkCount = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id).length
        : linkedPositiveIds.length;

    final visual = Semantics(
      label: linkCount > 0 ? 'Linked $linkCount' : 'Not linked',
      child: SizedBox.square(
        dimension: anchorExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.link_rounded,
                size: 16,
                color: linkCount > 0
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outline,
              ),
            ),
            if (linkCount > 1)
              Positioned(
                right: -2,
                top: -2,
                child: Text(
                  '$linkCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget revealRelatedLinks(Widget child) {
      return MouseRegion(
        onEnter: (_) => _setHighlightedLinkEntry(entry.id, true),
        onExit: (_) => _setHighlightedLinkEntry(entry.id, false),
        child: Focus(
          onFocusChange: (focused) =>
              _setHighlightedLinkEntry(entry.id, focused),
          child: child,
        ),
      );
    }

    if (entry.promptType == FixedTagPromptType.positive) {
      return KeyedSubtree(
        key: _anchorKeyFor(entry),
        child: revealRelatedLinks(
          Draggable<_LinkDragPayload>(
            data: _LinkDragPayload(entry.id),
            onDragStarted: () => _startLinkDragPreview(entry.id),
            onDragUpdate: (details) => _updateLinkDragPreview(
              positiveEntryId: entry.id,
              globalPosition: details.globalPosition,
            ),
            onDragEnd: (_) => _clearLinkDragPreview(),
            onDragCompleted: _clearLinkDragPreview,
            onDraggableCanceled: (_, __) => _clearLinkDragPreview(),
            feedback: Material(
              color: Colors.transparent,
              child: Icon(
                Icons.link_rounded,
                color: theme.colorScheme.secondary,
                size: 22,
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: visual),
            child: visual,
          ),
        ),
      );
    }

    final negativeAnchor = linkedPositiveIds.isEmpty
        ? visual
        : Draggable<String>(
            data: entry.id,
            feedback: const SizedBox(width: 1, height: 1),
            childWhenDragging: Opacity(opacity: 0.35, child: visual),
            onDragStarted: () => _startLinkDragPreview(
              linkedPositiveIds.first,
              negativeEntryId: entry.id,
              isDetaching: true,
            ),
            onDragUpdate: (details) => _updateLinkDragPreview(
              positiveEntryId: linkedPositiveIds.first,
              globalPosition: details.globalPosition,
              isDetaching: true,
            ),
            onDragEnd: (details) => _completeLinkDetachDrag(
              positiveEntryId: linkedPositiveIds.first,
              negativeEntryId: entry.id,
              globalPosition: details.offset,
            ),
            onDraggableCanceled: (_, offset) => _completeLinkDetachDrag(
              positiveEntryId: linkedPositiveIds.first,
              negativeEntryId: entry.id,
              globalPosition: offset,
            ),
            child: visual,
          );
    return KeyedSubtree(
      key: _anchorKeyFor(entry),
      child: revealRelatedLinks(negativeAnchor),
    );
  }

  void _setHighlightedLinkEntry(String entryId, bool highlighted) {
    if (highlighted) {
      if (_highlightedLinkEntryId == entryId) return;
      setState(() => _highlightedLinkEntryId = entryId);
      return;
    }
    if (_highlightedLinkEntryId != entryId || _linkDragPreview != null) return;
    setState(() => _highlightedLinkEntryId = null);
  }

  Widget _buildNegativeLinkTarget(FixedTagEntry entry, Widget child) {
    final theme = Theme.of(context);
    final state = ref.watch(fixedTagsNotifierProvider);
    return DragTarget<_LinkDragPayload>(
      onWillAcceptWithDetails: (details) {
        return state.entries.any(
          (candidate) =>
              candidate.id == details.data.positiveEntryId &&
              candidate.promptType == FixedTagPromptType.positive,
        );
      },
      onAcceptWithDetails: (details) {
        final positiveEntryId = details.data.positiveEntryId;
        final currentState = ref.read(fixedTagsNotifierProvider);
        final notifier = ref.read(fixedTagsNotifierProvider.notifier);
        final linkExists = currentState.links.any(
          (link) =>
              link.positiveEntryId == positiveEntryId &&
              link.negativeEntryId == entry.id,
        );
        if (linkExists) {
          notifier.removeLinkByPair(
            positiveEntryId: positiveEntryId,
            negativeEntryId: entry.id,
          );
        } else {
          notifier.createLink(
            positiveEntryId: positiveEntryId,
            negativeEntryId: entry.id,
          );
        }
        _scheduleLinkRepaint();
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: theme.colorScheme.secondary, width: 1.5)
                : null,
          ),
          child: child,
        );
      },
    );
  }

  void _startLinkDragPreview(
    String positiveEntryId, {
    String? negativeEntryId,
    bool isDetaching = false,
  }) {
    final start = _positiveAnchorCenters[positiveEntryId];
    if (start == null) return;
    final end = negativeEntryId == null
        ? start
        : _negativeAnchorCenters[negativeEntryId] ?? start;
    setState(() {
      _linkDragPreview = _LinkDragPreview(
        start: start,
        end: end,
        isDetaching: isDetaching,
      );
    });
  }

  void _updateLinkDragPreview({
    required String positiveEntryId,
    required Offset globalPosition,
    bool isDetaching = false,
  }) {
    final start = _positiveAnchorCenters[positiveEntryId];
    final end = _globalToLinkLayer(globalPosition);
    if (start == null || end == null) return;
    setState(() {
      _linkDragPreview = _LinkDragPreview(
        start: start,
        end: end,
        isDetaching: isDetaching,
      );
    });
  }

  void _completeLinkDetachDrag({
    required String positiveEntryId,
    required String negativeEntryId,
    Offset? globalPosition,
  }) {
    final dragEnd = globalPosition == null
        ? _linkDragPreview?.end
        : _globalToLinkLayer(globalPosition);
    final endpoint = _negativeAnchorCenters[negativeEntryId];
    if (dragEnd != null &&
        endpoint != null &&
        (dragEnd - endpoint).distance >= _linkDetachDistance) {
      ref
          .read(fixedTagsNotifierProvider.notifier)
          .removeLinkByPair(
            positiveEntryId: positiveEntryId,
            negativeEntryId: negativeEntryId,
          );
      _scheduleLinkRepaint();
    }
    _clearLinkDragPreview();
  }

  void _clearLinkDragPreview() {
    if (_linkDragPreview == null) return;
    setState(() => _linkDragPreview = null);
  }

  Offset? _globalToLinkLayer(Offset globalPosition) {
    final renderObject = _linkLayerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.globalToLocal(globalPosition);
  }

  Future<void> _editEntry(FixedTagEntry entry) async {
    final result = await FixedTagEditDialog.show(
      context: context,
      entry: entry,
    );
    if (result == null || !mounted) return;
    await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
  }

  Future<void> _addEntry({
    FixedTagPromptType promptType = FixedTagPromptType.positive,
  }) async {
    final result = await FixedTagEditDialog.show(
      context: context,
      initialPromptType: promptType,
    );
    if (result == null || !mounted) return;
    await ref
        .read(fixedTagsNotifierProvider.notifier)
        .addEntry(
          name: result.name,
          content: result.content,
          weight: result.weight,
          position: result.position,
          enabled: result.enabled,
          promptType: result.promptType,
          categoryId: result.categoryId,
        );
  }

  Future<void> _addFromLibrary(FixedTagPromptType promptType) async {
    final entry = await TagLibraryPickerDialog.show(context);
    if (entry == null || !mounted) return;
    await ref
        .read(fixedTagsNotifierProvider.notifier)
        .addEntry(
          name: entry.name,
          content: entry.content,
          promptType: promptType,
          sourceEntryId: entry.id,
          categoryId: entry.categoryId,
        );
    if (!mounted) return;
    AppToast.success(context, context.l10n.fixedTags_addedToSidebar);
  }

  Future<void> _deleteEntry(FixedTagEntry entry) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_deleteTitle,
      content: context.l10n.fixedTags_deleteConfirm(entry.displayName),
      confirmText: context.l10n.common_delete,
      type: ThemedConfirmDialogType.danger,
    );
    if (!confirmed || !mounted) return;
    await ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(entry.id);
  }

  List<_TagSection> _tagSections(
    List<FixedTagEntry> sourceEntries,
    List<TagLibraryCategory> categories,
  ) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final grouped = <String?, List<FixedTagEntry>>{};
    for (final entry in sourceEntries) {
      grouped.putIfAbsent(entry.categoryId, () => []).add(entry);
    }
    final sections = <_TagSection>[];
    for (final category in categories.sortedByOrder()) {
      final entries = grouped[category.id] ?? const <FixedTagEntry>[];
      if (entries.isEmpty) continue;
      sections.add(
        _TagSection(
          id: category.id,
          name: category.displayName,
          entries: entries,
          color: _categoryColor(category.id),
        ),
      );
    }

    final unknownCategoryIds = grouped.keys.where(
      (id) => id != null && !categoriesById.containsKey(id),
    );
    for (final categoryId in unknownCategoryIds) {
      final entries = grouped[categoryId] ?? const <FixedTagEntry>[];
      if (entries.isEmpty) continue;
      sections.add(
        _TagSection(
          id: categoryId!,
          name: context.l10n.fixedTags_unknownCategory,
          entries: entries,
          color: _categoryColor(categoryId),
        ),
      );
    }

    final uncategorized = grouped[null] ?? const <FixedTagEntry>[];
    if (uncategorized.isNotEmpty) {
      sections.add(
        _TagSection(
          id: _uncategorizedSectionId,
          name: context.l10n.fixedTags_uncategorized,
          entries: uncategorized,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return sections;
  }

  List<FixedTagLink> _visibleLinks(FixedTagsState state) {
    final highlightedEntryId = _highlightedLinkEntryId;
    if (highlightedEntryId == null) return const [];
    return state.links
        .where(
          (link) =>
              link.positiveEntryId == highlightedEntryId ||
              link.negativeEntryId == highlightedEntryId,
        )
        .toList();
  }

  Color _categoryColor(String? categoryId) {
    if (categoryId == null) return Theme.of(context).colorScheme.outline;
    final hash = categoryId.codeUnits.fold<int>(
      0,
      (previous, codeUnit) => (previous * 31 + codeUnit) & 0x7fffffff,
    );
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.58, 0.55).toColor();
  }

  GlobalKey _anchorKeyFor(FixedTagEntry entry) {
    final keys = entry.promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    return keys.putIfAbsent(entry.id, () => GlobalKey());
  }

  void _pruneAnchorKeys(FixedTagsState state) {
    final positiveIds = state.positiveEntries.map((e) => e.id).toSet();
    final negativeIds = state.negativeEntries.map((e) => e.id).toSet();
    _positiveAnchorKeys.removeWhere((id, _) => !positiveIds.contains(id));
    _negativeAnchorKeys.removeWhere((id, _) => !negativeIds.contains(id));
  }

  void _scheduleLinkRepaint() {
    if (_linkRepaintScheduled) return;
    _linkRepaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkRepaintScheduled = false;
      if (!mounted) return;
      final positiveCenters = collectAnchorCenters(
        _positiveAnchorKeys,
        _linkLayerKey,
      );
      final negativeCenters = collectAnchorCenters(
        _negativeAnchorKeys,
        _linkLayerKey,
      );
      if (mapEquals(_positiveAnchorCenters, positiveCenters) &&
          mapEquals(_negativeAnchorCenters, negativeCenters)) {
        return;
      }
      setState(() {
        _positiveAnchorCenters = positiveCenters;
        _negativeAnchorCenters = negativeCenters;
      });
    });
  }
}

enum _AddAction { positive, negative, libraryPositive, libraryNegative }

class _LinkDragPayload {
  const _LinkDragPayload(this.positiveEntryId);

  final String positiveEntryId;
}

class _LinkDragPreview {
  const _LinkDragPreview({
    required this.start,
    required this.end,
    required this.isDetaching,
  });

  final Offset start;
  final Offset end;
  final bool isDetaching;
}

class _TagSection {
  const _TagSection({
    required this.id,
    required this.name,
    required this.entries,
    required this.color,
  });

  final String id;
  final String name;
  final List<FixedTagEntry> entries;
  final Color color;
}

typedef _FixedTagGroupEntryBuilder =
    Widget Function(
      FixedTagEntry entry,
      Color categoryColor,
      SidebarDragHandleBuilder? dragHandleBuilder,
    );

typedef _FixedTagGroupReorderCallback =
    void Function(List<FixedTagEntry> entries, int oldIndex, int newIndex);

typedef _FixedTagListPrototypeBuilder = Widget Function(Color categoryColor);

class _GroupedFixedTagCollection extends StatefulWidget {
  const _GroupedFixedTagCollection({
    super.key,
    required this.keyPrefix,
    required this.sections,
    required this.isListMode,
    required this.forceExpanded,
    required this.controller,
    required this.emptyText,
    required this.listPrototypeBuilder,
    required this.entryBuilder,
    required this.onReorder,
    required this.onVisibilityChanged,
  });

  final String keyPrefix;
  final List<_TagSection> sections;
  final bool isListMode;
  final bool forceExpanded;
  final ScrollController controller;
  final String emptyText;
  final _FixedTagListPrototypeBuilder listPrototypeBuilder;
  final _FixedTagGroupEntryBuilder entryBuilder;
  final _FixedTagGroupReorderCallback onReorder;
  final VoidCallback onVisibilityChanged;

  @override
  State<_GroupedFixedTagCollection> createState() =>
      _GroupedFixedTagCollectionState();
}

class _GroupedFixedTagCollectionState
    extends State<_GroupedFixedTagCollection> {
  final _collapsedSectionIds = <String>{};

  @override
  void didUpdateWidget(covariant _GroupedFixedTagCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableIds = widget.sections.map((section) => section.id).toSet();
    _collapsedSectionIds.removeWhere((id) => !availableIds.contains(id));
  }

  void _setSectionCollapsed(String sectionId, bool collapsed) {
    setState(() {
      if (collapsed) {
        _collapsedSectionIds.add(sectionId);
      } else {
        _collapsedSectionIds.remove(sectionId);
      }
    });
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
    widget.onVisibilityChanged();
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('${widget.keyPrefix}-group-list'),
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final section in widget.sections)
                  Builder(
                    builder: (context) {
                      final isCollapsed =
                          !widget.forceExpanded &&
                          _collapsedSectionIds.contains(section.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(
                              context,
                              section: section,
                              isCollapsed: isCollapsed,
                            ),
                            if (!isCollapsed)
                              _buildSectionEntries(context, section),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required _TagSection section,
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

  Widget _buildSectionEntries(BuildContext context, _TagSection section) {
    if (widget.isListMode) {
      return Padding(
        key: ValueKey('${widget.keyPrefix}-group-${section.id}-body'),
        padding: const EdgeInsets.only(top: 4),
        child: ReorderableListView.builder(
          key: ValueKey('${widget.keyPrefix}-group-${section.id}-entries'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: section.entries.length,
          prototypeItem: widget.listPrototypeBuilder(section.color),
          onReorderItem: (oldIndex, newIndex) =>
              widget.onReorder(section.entries, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final entry = section.entries[index];
            return Padding(
              key: ValueKey('${widget.keyPrefix}-entry-${entry.id}'),
              padding: const EdgeInsets.only(bottom: 4),
              child: widget.entryBuilder(
                entry,
                section.color,
                section.entries.length > 1
                    ? (child) => ReorderableDragStartListener(
                        index: index,
                        child: child,
                      )
                    : null,
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 7.0;
        final largeText = MediaQuery.textScalerOf(context).scale(14) >= 20;
        final minimumCardWidth = largeText ? 220.0 : 140.0;
        final columnCount =
            ((constraints.maxWidth + spacing) / (minimumCardWidth + spacing))
                .floor()
                .clamp(1, 3);
        final cardHeight = _gridCardHeight(context);
        return GridView.builder(
          key: ValueKey('${widget.keyPrefix}-group-${section.id}-body'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: section.entries.length,
          itemBuilder: (context, index) =>
              widget.entryBuilder(section.entries[index], section.color, null),
        );
      },
    );
  }
}

class _GroupBulkAction extends StatelessWidget {
  const _GroupBulkAction({
    super.key,
    required this.icon,
    required this.label,
    required this.iconOnly,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool iconOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

class _EnabledOnlyAction extends StatelessWidget {
  const _EnabledOnlyAction({
    super.key,
    required this.selected,
    required this.color,
    required this.iconOnly,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final Color color;
  final bool iconOnly;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? Icons.filter_alt_rounded
        : Icons.filter_alt_outlined;
    final foregroundColor = selected
        ? color
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final action = iconOnly
        ? IconButton(
            tooltip: label,
            onPressed: onPressed,
            isSelected: selected,
            selectedIcon: Icon(
              Icons.filter_alt_rounded,
              size: 18,
              color: color,
            ),
            icon: Icon(icon, size: 18, color: foregroundColor),
            visualDensity: VisualDensity.compact,
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: foregroundColor,
              backgroundColor: selected
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
    return Semantics(selected: selected, child: action);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
