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
import '../../../widgets/prompt/fixed_tag_edit_dialog.dart';
import '../../../widgets/tag_library/tag_library_picker_dialog.dart';
import 'fixed_tags_category_rail.dart';
import 'sidebar_entry_tile.dart';
import 'sidebar_link_painter.dart';

const _enabledSectionId = 'enabled';
const _allNegativeSectionId = 'all-negative';
const _uncategorizedSectionId = '__uncategorized__';
const _linkDetachDistance = 36.0;

double _gridCardHeight(BuildContext context, {required double cardWidth}) {
  final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
  final usesActionMenu =
      context.interactionPolicy.shouldExposeTouchAlternatives ||
      scaledLabelSize >= 20;
  final needsTallBase = cardWidth < 320 || usesActionMenu;

  // Grid previews can contain up to five scaled text lines. Grow the fixed
  // extent with the text scaler so asynchronous translations cannot outgrow it.
  final scaledTextGrowth = (scaledLabelSize - 14).clamp(0.0, double.infinity);
  final baseHeight = usesActionMenu
      ? 210.0
      : needsTallBase
      ? 180.0
      : 150.0;
  return baseHeight + scaledTextGrowth * 6;
}

/// 桌面端固定词侧边栏。
class FixedTagsSidebar extends ConsumerStatefulWidget {
  const FixedTagsSidebar({super.key, this.isResizing = false});

  final bool isResizing;

  @override
  ConsumerState<FixedTagsSidebar> createState() => _FixedTagsSidebarState();
}

class _FixedTagsSidebarState extends ConsumerState<FixedTagsSidebar> {
  final _searchController = TextEditingController();
  final _positiveScrollController = ScrollController();
  final _negativeScrollController = ScrollController();
  final _linkLayerKey = GlobalKey();
  final _positiveAnchorKeys = <String, GlobalKey>{};
  final _negativeAnchorKeys = <String, GlobalKey>{};

  var _positiveAnchorCenters = <String, Offset>{};
  var _negativeAnchorCenters = <String, Offset>{};
  _LinkDragPreview? _linkDragPreview;
  String _searchQuery = '';
  String _activePositiveCategoryId = _enabledSectionId;
  String _activeNegativeCategoryId = _allNegativeSectionId;
  String? _highlightedLinkEntryId;
  bool _linkRepaintScheduled = false;

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
    final positiveSections = _tagSections(
      fixedState.positiveEntries,
      categories,
    );
    final negativeSections = _tagSections(
      fixedState.negativeEntries,
      categories,
    );
    final activePositiveCategoryId = _effectivePositiveCategoryId(
      positiveSections,
    );
    final activeNegativeCategoryId = _effectiveNegativeCategoryId(
      negativeSections,
    );
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
                activePositiveCategoryId,
                activeNegativeCategoryId,
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
          _buildEnabledStrip(theme, fixedState),
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

  Widget _buildEnabledStrip(ThemeData theme, FixedTagsState fixedState) {
    final mediaQuery = MediaQuery.of(context);
    final useCompactRow = mediaQuery.textScaler.scale(14) >= 22.4;
    final positiveSummary = _buildEnabledStripSection(
      theme,
      key: const ValueKey('fixed-tags-enabled-positive-strip'),
      label: context.l10n.fixedTags_enabledPositive,
      emptyText: context.l10n.fixedTags_emptyEnabledPositive,
      icon: Icons.bolt_rounded,
      color: theme.colorScheme.primary,
      entries: fixedState.enabledEntries,
      forceSingleLineScroll: useCompactRow,
    );
    final negativeSummary = _buildEnabledStripSection(
      theme,
      key: const ValueKey('fixed-tags-enabled-negative-strip'),
      label: context.l10n.fixedTags_enabledNegative,
      emptyText: context.l10n.fixedTags_emptyEnabledNegative,
      icon: Icons.block_rounded,
      color: theme.colorScheme.error,
      entries: fixedState.negativeEnabledEntries,
      forceSingleLineScroll: useCompactRow,
    );

    return Padding(
      key: const ValueKey('fixed-tags-enabled-strip'),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: useCompactRow
          ? Row(
              children: [
                Expanded(child: positiveSummary),
                const SizedBox(width: 4),
                Expanded(child: negativeSummary),
              ],
            )
          : Column(
              children: [
                positiveSummary,
                const SizedBox(height: 4),
                negativeSummary,
              ],
            ),
    );
  }

  Widget _buildEnabledStripSection(
    ThemeData theme, {
    required Key key,
    required String label,
    required String emptyText,
    required IconData icon,
    required Color color,
    required List<FixedTagEntry> entries,
    required bool forceSingleLineScroll,
  }) {
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final chips = [
      for (final entry in entries)
        InputChip(
          label: Text(entry.displayName),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onDeleted: () => ref
              .read(fixedTagsNotifierProvider.notifier)
              .toggleEnabled(entry.id),
        ),
    ];
    final usesSingleLineScroll =
        forceSingleLineScroll ||
        MediaQuery.textScalerOf(context).scale(14) >= 22.4;

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(theme.colorScheme).withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(6),
      ),
      child: usesSingleLineScroll
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  labelWidget,
                  if (entries.isEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      emptyText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else
                    for (final chip in chips) ...[
                      const SizedBox(width: 8),
                      chip,
                    ],
                ],
              ),
            )
          : entries.isEmpty
          ? Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    emptyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [labelWidget, ...chips],
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
    String activePositiveCategoryId,
    String activeNegativeCategoryId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const panePadding = EdgeInsets.fromLTRB(8, 0, 8, 8);
        final dividerHeight = context.interactionPolicy.prefersTouchPresentation
            ? context.interactionPolicy.minimumControlExtent
            : 12.0;
        final usableHeight =
            (constraints.maxHeight - panePadding.vertical - dividerHeight)
                .clamp(0.0, double.infinity)
                .toDouble();
        final hasPositiveEntries = fixedState.positiveEntries.isNotEmpty;
        final hasNegativeEntries = fixedState.negativeEntries.isNotEmpty;
        const populatedMinimumHeight = 138.0;
        const emptyMinimumHeight = 64.0;
        final desiredPositiveMinimum = !hasPositiveEntries
            ? emptyMinimumHeight
            : isListMode
            ? populatedMinimumHeight
            : 274.0;
        final desiredNegativeMinimum = !hasNegativeEntries
            ? emptyMinimumHeight
            : populatedMinimumHeight;
        const paneHeaderMinimumHeight = 64.0;
        const headerMinimumTotal = paneHeaderMinimumHeight * 2;
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
        final negativeHeight = layoutState.fixedTagsNegativeHeight
            .clamp(negativeMinimumHeight, maximumNegativeHeight)
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
                  fixedState,
                  positiveSections,
                  libraryEntries,
                  isListMode,
                  activePositiveCategoryId,
                ),
              ),
              _buildNegativeResizeDivider(theme, layoutState),
              Expanded(
                key: const ValueKey('fixed-tags-negative-pane'),
                child: _buildNegativeArea(
                  theme,
                  fixedState,
                  negativeSections,
                  libraryEntries,
                  isListMode,
                  activeNegativeCategoryId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<FixedTagEntry> _visiblePositiveEntries(
    FixedTagsState fixedState,
    List<_TagSection> sections,
    String activeCategoryId,
  ) {
    if (_searchQuery.trim().isNotEmpty) {
      return fixedState.positiveEntries.search(_searchQuery);
    }
    if (activeCategoryId == _enabledSectionId) {
      return fixedState.enabledEntries;
    }
    return sections
            .cast<_TagSection?>()
            .firstWhere(
              (section) => section?.id == activeCategoryId,
              orElse: () => null,
            )
            ?.entries ??
        const <FixedTagEntry>[];
  }

  List<FixedTagEntry> _visibleNegativeEntries(
    FixedTagsState fixedState,
    List<_TagSection> sections,
    String activeCategoryId,
  ) {
    if (_searchQuery.trim().isNotEmpty) {
      return fixedState.negativeEntries.search(_searchQuery);
    }
    if (activeCategoryId == _allNegativeSectionId) {
      return fixedState.negativeEntries;
    }
    return sections
            .cast<_TagSection?>()
            .firstWhere(
              (section) => section?.id == activeCategoryId,
              orElse: () => null,
            )
            ?.entries ??
        const <FixedTagEntry>[];
  }

  Widget _buildPositiveArea(
    ThemeData theme,
    FixedTagsState fixedState,
    List<_TagSection> sections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
    String activeCategoryId,
  ) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final selectedSection = sections.cast<_TagSection?>().firstWhere(
      (section) => section?.id == activeCategoryId,
      orElse: () => null,
    );
    final entries = _visiblePositiveEntries(
      fixedState,
      sections,
      activeCategoryId,
    );
    final color = activeCategoryId == _enabledSectionId
        ? theme.colorScheme.primary
        : selectedSection?.color ?? theme.colorScheme.outline;
    final label = isSearching
        ? context.l10n.fixedTags_searchNameOrContent
        : activeCategoryId == _enabledSectionId
        ? context.l10n.fixedTags_enabled
        : selectedSection?.name ?? context.l10n.fixedTags_uncategorized;
    final destinations = [
      FixedTagsRailDestination(
        id: _enabledSectionId,
        label: context.l10n.fixedTags_enabled,
        count: fixedState.enabledEntries.length,
        icon: Icons.check_circle_outline_rounded,
        color: theme.colorScheme.primary,
      ),
      for (final section in sections)
        FixedTagsRailDestination(
          id: section.id,
          label: section.name,
          count: section.entries.length,
          icon: Icons.folder_outlined,
          color: section.color,
        ),
    ];

    return _buildPaneCard(
      theme,
      key: const ValueKey('fixed-tags-positive-card'),
      accent: theme.colorScheme.primary,
      header: _buildPaneHeader(
        icon: Icons.add_circle_outline_rounded,
        label: context.l10n.fixedTags_positiveTitle,
        count: entries.length,
        color: theme.colorScheme.primary,
      ),
      body: Row(
        children: [
          FixedTagsCategoryRail(
            keyPrefix: 'fixed-tags-positive',
            destinations: destinations,
            selectedId: activeCategoryId,
            onSelected: _selectPositiveCategory,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEntryCollection(
              entries: entries,
              promptType: FixedTagPromptType.positive,
              categoryColor: color,
              categoryName: isSearching ? null : label,
              libraryEntries: libraryEntries,
              isListMode: isListMode,
              controller: _positiveScrollController,
              emptyText: _searchQuery.isEmpty
                  ? context.l10n.fixedTags_emptyEnabledPositive
                  : context.l10n.fixedTags_noMatchingEnabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaneCard(
    ThemeData theme, {
    required Key key,
    required Color accent,
    required Widget header,
    required Widget body,
  }) {
    final baseColor = sectionSurfaceColor(theme.colorScheme);
    final cardTint = theme.brightness == Brightness.dark ? 0.04 : 0.025;
    final headerTint = theme.brightness == Brightness.dark ? 0.09 : 0.065;
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
            child: header,
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
    Widget? trailing,
  }) {
    final usesLargeText = MediaQuery.textScalerOf(context).scale(14) >= 28;
    return Padding(
      padding: usesLargeText
          ? const EdgeInsets.fromLTRB(8, 2, 4, 2)
          : const EdgeInsets.fromLTRB(10, 8, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: _SectionTitle(
              icon: icon,
              label: label,
              count: count,
              color: color,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEntryCollection({
    required List<FixedTagEntry> entries,
    required FixedTagPromptType promptType,
    required Color categoryColor,
    required List<TagLibraryEntry> libraryEntries,
    required bool isListMode,
    required ScrollController controller,
    required String emptyText,
    String? categoryName,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (isListMode) {
      return ReorderableListView.builder(
        key: ValueKey('${promptType.name}-list-${categoryName ?? 'all'}'),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        itemCount: entries.length,
        scrollController: controller,
        prototypeItem: _buildListEntryPrototype(
          entry: entries.first,
          categoryColor: categoryColor,
        ),
        onReorderItem: (oldIndex, newIndex) => ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorderWithinVisibleIds(
              promptType: promptType,
              visibleIds: entries.map((entry) => entry.id).toList(),
              oldIndex: oldIndex,
              newIndex: newIndex,
            ),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            key: ValueKey('${promptType.name}-${entry.id}'),
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildEntryTile(
              entry: entry,
              categoryColor: categoryColor,
              libraryEntries: libraryEntries,
              isListMode: true,
              dragHandleBuilder: entries.length > 1
                  ? (child) =>
                        ReorderableDragStartListener(index: index, child: child)
                  : null,
            ),
          );
        },
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
        final cardWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        final cardHeight = _gridCardHeight(context, cardWidth: cardWidth);
        return GridView.builder(
          key: ValueKey('${promptType.name}-grid-${categoryName ?? 'all'}'),
          controller: controller,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _buildEntryTile(
            entry: entries[index],
            categoryColor: categoryColor,
            libraryEntries: libraryEntries,
            isListMode: false,
          ),
        );
      },
    );
  }

  Widget _buildNegativeResizeDivider(ThemeData theme, LayoutState layoutState) {
    final interactionPolicy = context.interactionPolicy;
    final hitHeight = interactionPolicy.prefersTouchPresentation
        ? interactionPolicy.minimumControlExtent
        : 12.0;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          final currentHeight = ref
              .read(layoutStateNotifierProvider)
              .fixedTagsNegativeHeight;
          ref
              .read(layoutStateNotifierProvider.notifier)
              .setFixedTagsNegativeHeight(currentHeight - details.delta.dy);
        },
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
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                width: widget.isResizing ? 48 : 40,
                height: widget.isResizing ? 3 : 2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: widget.isResizing ? 0.95 : 0.8,
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

  Widget _buildNegativeArea(
    ThemeData theme,
    FixedTagsState fixedState,
    List<_TagSection> sections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
    String activeCategoryId,
  ) {
    final selectedSection = sections.cast<_TagSection?>().firstWhere(
      (section) => section?.id == activeCategoryId,
      orElse: () => null,
    );
    final entries = _visibleNegativeEntries(
      fixedState,
      sections,
      activeCategoryId,
    );
    final color = selectedSection?.color ?? theme.colorScheme.error;
    final destinations = [
      FixedTagsRailDestination(
        id: _allNegativeSectionId,
        label: context.l10n.fixedTags_negativeTitle,
        count: fixedState.negativeEntries.length,
        icon: Icons.select_all_rounded,
        color: theme.colorScheme.error,
      ),
      for (final section in sections)
        FixedTagsRailDestination(
          id: section.id,
          label: section.name,
          count: section.entries.length,
          icon: Icons.folder_outlined,
          color: theme.colorScheme.error,
        ),
    ];
    return _buildPaneCard(
      theme,
      key: const ValueKey('fixed-tags-negative-card'),
      accent: theme.colorScheme.error,
      header: _buildPaneHeader(
        icon: Icons.block_rounded,
        label: context.l10n.fixedTags_negativeTitle,
        count: entries.length,
        color: theme.colorScheme.error,
        trailing: IconButton(
          tooltip: context.l10n.fixedTags_addNegative,
          icon: const Icon(Icons.add_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _addEntry(promptType: FixedTagPromptType.negative),
        ),
      ),
      body: Row(
        children: [
          FixedTagsCategoryRail(
            keyPrefix: 'fixed-tags-negative',
            destinations: destinations,
            selectedId: activeCategoryId,
            onSelected: _selectNegativeCategory,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEntryCollection(
              entries: entries,
              promptType: FixedTagPromptType.negative,
              categoryColor: color,
              categoryName: selectedSection?.name,
              libraryEntries: libraryEntries,
              isListMode: isListMode,
              controller: _negativeScrollController,
              emptyText: _searchQuery.isEmpty
                  ? context.l10n.fixedTags_emptyNegative
                  : context.l10n.fixedTags_noMatchingNegative,
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 7),
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

  String _effectivePositiveCategoryId(List<_TagSection> sections) {
    if (_activePositiveCategoryId == _enabledSectionId ||
        sections.any((section) => section.id == _activePositiveCategoryId)) {
      return _activePositiveCategoryId;
    }
    return _enabledSectionId;
  }

  String _effectiveNegativeCategoryId(List<_TagSection> sections) {
    if (_activeNegativeCategoryId == _allNegativeSectionId ||
        sections.any((section) => section.id == _activeNegativeCategoryId)) {
      return _activeNegativeCategoryId;
    }
    return _allNegativeSectionId;
  }

  void _selectPositiveCategory(String categoryId) {
    if (_activePositiveCategoryId == categoryId) return;
    setState(() {
      _activePositiveCategoryId = categoryId;
    });
    if (_positiveScrollController.hasClients) {
      _positiveScrollController.jumpTo(0);
    }
  }

  void _selectNegativeCategory(String categoryId) {
    if (_activeNegativeCategoryId == categoryId) return;
    setState(() {
      _activeNegativeCategoryId = categoryId;
    });
    if (_negativeScrollController.hasClients) {
      _negativeScrollController.jumpTo(0);
    }
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
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
