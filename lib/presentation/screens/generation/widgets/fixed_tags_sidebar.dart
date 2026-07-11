import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/prompt/fixed_tag_edit_dialog.dart';
import '../../../widgets/tag_library/tag_library_picker_dialog.dart';
import 'sidebar_entry_tile.dart';
import 'sidebar_link_painter.dart';

const _enabledSectionId = 'enabled';
const _uncategorizedSectionId = '__uncategorized__';
const _linkDetachDistance = 36.0;
const _linkEndpointHitSize = 30.0;

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
  final _sectionKeys = <String, GlobalKey>{};

  var _positiveAnchorCenters = <String, Offset>{};
  var _negativeAnchorCenters = <String, Offset>{};
  _LinkDragPreview? _linkDragPreview;
  String _searchQuery = '';
  String _activeCategoryId = _enabledSectionId;
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
    _pruneAnchorKeys(fixedState);
    _scheduleLinkRepaint();

    return Stack(
      key: _linkLayerKey,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, fixedState, isListMode),
            _buildSearchBar(theme),
            _buildCategoryChips(theme, fixedState, categories),
            const Divider(height: 1),
            Expanded(
              child: _buildPositiveArea(
                theme,
                fixedState,
                categories,
                libraryEntries,
                isListMode,
              ),
            ),
            _buildNegativeResizeDivider(theme, layoutState),
            SizedBox(
              height: layoutState.fixedTagsNegativeHeight,
              child: _buildNegativeArea(
                theme,
                fixedState,
                libraryEntries,
                isListMode,
              ),
            ),
          ],
        ),
        _buildLinkEndpointOverlay(fixedState),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SidebarLinkPainter(
                links: fixedState.links,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
      ),
    );
  }

  Widget _buildCategoryChips(
    ThemeData theme,
    FixedTagsState fixedState,
    List<TagLibraryCategory> categories,
  ) {
    final sections = _positiveSections(fixedState, categories);
    final enabledCount = fixedState.enabledEntries.search(_searchQuery).length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 96),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CategoryChip(
              label: context.l10n.fixedTags_enabled,
              count: enabledCount,
              selected: _activeCategoryId == _enabledSectionId,
              color: theme.colorScheme.secondary,
              onTap: () => _scrollToCategory(_enabledSectionId),
            ),
            for (final section in sections)
              _CategoryChip(
                label: section.name,
                count: section.entries.length,
                selected: _activeCategoryId == section.id,
                color: section.color,
                onTap: () => _scrollToCategory(section.id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositiveArea(
    ThemeData theme,
    FixedTagsState fixedState,
    List<TagLibraryCategory> categories,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
  ) {
    final sections = _positiveSections(fixedState, categories);
    return CustomScrollView(
      controller: _positiveScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _buildEnabledSummary(theme, fixedState),
              ),
              for (final section in sections)
                _buildPositiveSection(
                  theme,
                  section,
                  libraryEntries,
                  isListMode,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnabledSummary(ThemeData theme, FixedTagsState fixedState) {
    final enabledEntries = fixedState.enabledEntries.search(_searchQuery);
    return Container(
      key: _sectionKeyFor(_enabledSectionId),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.bolt_rounded,
            label: context.l10n.fixedTags_enabledPositive,
            count: enabledEntries.length,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 8),
          if (enabledEntries.isEmpty)
            Text(
              _searchQuery.isEmpty
                  ? context.l10n.fixedTags_emptyEnabledPositive
                  : context.l10n.fixedTags_noMatchingEnabled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in enabledEntries)
                  InputChip(
                    label: Text(entry.displayName),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .toggleEnabled(entry.id),
                    onDeleted: () => ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .toggleEnabled(entry.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPositiveSection(
    ThemeData theme,
    _PositiveSection section,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
  ) {
    final entries = section.entries;
    return SliverMainAxisGroup(
      key: ValueKey('positive-section-${section.id}'),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            key: _sectionKeyFor(section.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(
                  icon: Icons.folder_rounded,
                  label: section.name,
                  count: entries.length,
                  color: section.color,
                ),
                const SizedBox(height: 7),
              ],
            ),
          ),
        ),
        if (isListMode)
          SliverReorderableList(
            key: ValueKey('positive-list-${section.id}'),
            itemCount: entries.length,
            prototypeItem: _buildListEntryPrototype(
              entry: entries.first,
              categoryColor: section.color,
            ),
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(fixedTagsNotifierProvider.notifier)
                  .reorderWithinVisibleIds(
                    promptType: FixedTagPromptType.positive,
                    visibleIds: entries.map((entry) => entry.id).toList(),
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
            },
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                key: ValueKey('positive-${entry.id}'),
                padding: const EdgeInsets.only(bottom: 7),
                child: _buildEntryTile(
                  entry: entry,
                  categoryName: section.name,
                  categoryColor: section.color,
                  libraryEntries: libraryEntries,
                  isListMode: isListMode,
                  dragHandleBuilder: entries.length > 1
                      ? (child) => ReorderableDragStartListener(
                          index: index,
                          child: child,
                        )
                      : null,
                ),
              );
            },
          )
        else
          SliverGrid.builder(
            key: ValueKey('positive-grid-${section.id}'),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              mainAxisExtent: 150,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return KeyedSubtree(
                key: ValueKey('grid-${entry.id}'),
                child: _buildEntryTile(
                  entry: entry,
                  categoryName: section.name,
                  categoryColor: section.color,
                  libraryEntries: libraryEntries,
                  isListMode: false,
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _buildNegativeResizeDivider(ThemeData theme, LayoutState layoutState) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final currentHeight = ref
            .read(layoutStateNotifierProvider)
            .fixedTagsNegativeHeight;
        ref
            .read(layoutStateNotifierProvider.notifier)
            .setFixedTagsNegativeHeight(currentHeight - details.delta.dy);
      },
      child: Container(
        height: 8,
        alignment: Alignment.center,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: widget.isResizing ? 0.8 : 0.35,
        ),
        child: Container(
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  Widget _buildNegativeArea(
    ThemeData theme,
    FixedTagsState fixedState,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
  ) {
    final entries = fixedState.negativeEntries.search(_searchQuery);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 5),
            child: Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    icon: Icons.block_rounded,
                    label: context.l10n.fixedTags_negativeTitle,
                    count: entries.length,
                    color: theme.colorScheme.error,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.fixedTags_addNegative,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () =>
                      _addEntry(promptType: FixedTagPromptType.negative),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? context.l10n.fixedTags_emptyNegative
                          : context.l10n.fixedTags_noMatchingNegative,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : isListMode
                ? ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: entries.length,
                    scrollController: _negativeScrollController,
                    prototypeItem: _buildListEntryPrototype(
                      entry: entries.first,
                      categoryColor: theme.colorScheme.error,
                    ),
                    onReorderItem: (oldIndex, newIndex) {
                      ref
                          .read(fixedTagsNotifierProvider.notifier)
                          .reorderWithinVisibleIds(
                            promptType: FixedTagPromptType.negative,
                            visibleIds: entries
                                .map((entry) => entry.id)
                                .toList(),
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Padding(
                        key: ValueKey('negative-${entry.id}'),
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _buildEntryTile(
                          entry: entry,
                          categoryColor: theme.colorScheme.error,
                          libraryEntries: libraryEntries,
                          isListMode: isListMode,
                          dragHandleBuilder: entries.length > 1
                              ? (child) => ReorderableDragStartListener(
                                  index: index,
                                  child: child,
                                )
                              : null,
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    controller: _negativeScrollController,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _buildEntryGrid(
                      entries: entries,
                      categoryColor: theme.colorScheme.error,
                      libraryEntries: libraryEntries,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryGrid({
    required List<FixedTagEntry> entries,
    required Color categoryColor,
    required List<TagLibraryEntry> libraryEntries,
    String? categoryName,
  }) {
    const spacing = 7.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final itemWidth = ((availableWidth - spacing * 2) / 3).clamp(
          0.0,
          availableWidth,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries)
              SizedBox(
                key: ValueKey('grid-${entry.id}'),
                width: itemWidth.toDouble(),
                height: 150,
                child: _buildEntryTile(
                  entry: entry,
                  categoryColor: categoryColor,
                  categoryName: categoryName,
                  libraryEntries: libraryEntries,
                  isListMode: false,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEntryTile({
    required FixedTagEntry entry,
    required Color categoryColor,
    required List<TagLibraryEntry> libraryEntries,
    required bool isListMode,
    String? categoryName,
    SidebarDragHandleBuilder? dragHandleBuilder,
  }) {
    final tile = SidebarEntryTile(
      entry: entry,
      categoryColor: categoryColor,
      isListMode: isListMode,
      categoryName: categoryName,
      libraryEntry: _libraryEntryForFixedTag(entry, libraryEntries),
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
        linkAnchor: const SizedBox(width: 22, height: 22),
        onToggle: _noop,
        onEdit: _noop,
        onDelete: _noop,
      ),
    );
  }

  static void _noop() {}

  Widget _buildLinkAnchor(FixedTagEntry entry) {
    final theme = Theme.of(context);
    final state = ref.watch(fixedTagsNotifierProvider);
    final linkCount = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id).length
        : state.linkedPositivesOf(entry.id).length;

    final visual = SizedBox(
      width: 22,
      height: 22,
      child: Icon(
        Icons.link_rounded,
        size: 16,
        color: linkCount > 0
            ? theme.colorScheme.secondary
            : theme.colorScheme.outline,
      ),
    );

    if (entry.promptType == FixedTagPromptType.positive) {
      return KeyedSubtree(
        key: _anchorKeyFor(entry),
        child: Draggable<_LinkDragPayload>(
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
      );
    }

    return KeyedSubtree(key: _anchorKeyFor(entry), child: visual);
  }

  Widget _buildLinkEndpointOverlay(FixedTagsState fixedState) {
    final ignoreDuringNewLinkDrag =
        _linkDragPreview != null && !_linkDragPreview!.isDetaching;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: ignoreDuringNewLinkDrag,
        child: Stack(
          children: [
            for (final link in fixedState.links)
              if (_positiveAnchorCenters.containsKey(link.positiveEntryId) &&
                  _negativeAnchorCenters.containsKey(link.negativeEntryId))
                Positioned(
                  left:
                      _negativeAnchorCenters[link.negativeEntryId]!.dx -
                      _linkEndpointHitSize / 2,
                  top:
                      _negativeAnchorCenters[link.negativeEntryId]!.dy -
                      _linkEndpointHitSize / 2,
                  width: _linkEndpointHitSize,
                  height: _linkEndpointHitSize,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Draggable<_LinkDetachPayload>(
                      data: _LinkDetachPayload(
                        positiveEntryId: link.positiveEntryId,
                        negativeEntryId: link.negativeEntryId,
                      ),
                      hitTestBehavior: HitTestBehavior.opaque,
                      feedback: const SizedBox(width: 1, height: 1),
                      childWhenDragging: const SizedBox.expand(),
                      onDragStarted: () => _startLinkDragPreview(
                        link.positiveEntryId,
                        negativeEntryId: link.negativeEntryId,
                        isDetaching: true,
                      ),
                      onDragUpdate: (details) => _updateLinkDragPreview(
                        positiveEntryId: link.positiveEntryId,
                        globalPosition: details.globalPosition,
                        isDetaching: true,
                      ),
                      onDragEnd: (_) => _completeLinkDetachDrag(
                        positiveEntryId: link.positiveEntryId,
                        negativeEntryId: link.negativeEntryId,
                      ),
                      onDraggableCanceled: (_, __) => _completeLinkDetachDrag(
                        positiveEntryId: link.positiveEntryId,
                        negativeEntryId: link.negativeEntryId,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
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
  }) {
    final dragEnd = _linkDragPreview?.end;
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

  TagLibraryEntry? _libraryEntryForFixedTag(
    FixedTagEntry entry,
    List<TagLibraryEntry> libraryEntries,
  ) {
    final sourceEntryId = entry.sourceEntryId;
    if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
      for (final libraryEntry in libraryEntries) {
        if (libraryEntry.id == sourceEntryId) return libraryEntry;
      }
    }
    final content = entry.content.trim();
    for (final libraryEntry in libraryEntries) {
      if (libraryEntry.content.trim() == content) return libraryEntry;
    }
    final name = entry.name.trim();
    if (name.isEmpty) return null;
    for (final libraryEntry in libraryEntries) {
      if (libraryEntry.name.trim() == name) return libraryEntry;
    }
    return null;
  }

  Future<void> _editEntry(FixedTagEntry entry) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (context) => FixedTagEditDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
  }

  Future<void> _addEntry({
    FixedTagPromptType promptType = FixedTagPromptType.positive,
  }) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (context) => FixedTagEditDialog(initialPromptType: promptType),
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
        );
  }

  Future<void> _addFromLibrary(FixedTagPromptType promptType) async {
    final entry = await showDialog<TagLibraryEntry>(
      context: context,
      builder: (context) => const TagLibraryPickerDialog(),
    );
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

  List<_PositiveSection> _positiveSections(
    FixedTagsState fixedState,
    List<TagLibraryCategory> categories,
  ) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final grouped = fixedState.positiveByCategory;
    final sections = <_PositiveSection>[];
    for (final category in categories.sortedByOrder()) {
      final entries = (grouped[category.id] ?? const <FixedTagEntry>[]).search(
        _searchQuery,
      );
      if (entries.isEmpty) continue;
      sections.add(
        _PositiveSection(
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
      final entries = (grouped[categoryId] ?? const <FixedTagEntry>[]).search(
        _searchQuery,
      );
      if (entries.isEmpty) continue;
      sections.add(
        _PositiveSection(
          id: categoryId!,
          name: context.l10n.fixedTags_unknownCategory,
          entries: entries,
          color: _categoryColor(categoryId),
        ),
      );
    }

    final uncategorized = (grouped[null] ?? const <FixedTagEntry>[]).search(
      _searchQuery,
    );
    if (uncategorized.isNotEmpty) {
      sections.add(
        _PositiveSection(
          id: _uncategorizedSectionId,
          name: context.l10n.fixedTags_uncategorized,
          entries: uncategorized,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return sections;
  }

  Color _categoryColor(String? categoryId) {
    if (categoryId == null) return Theme.of(context).colorScheme.outline;
    final hash = categoryId.codeUnits.fold<int>(
      0,
      (previous, codeUnit) => (previous * 31 + codeUnit) & 0x7fffffff,
    );
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.58, 0.55).toColor();
  }

  GlobalKey _sectionKeyFor(String id) {
    return _sectionKeys.putIfAbsent(id, () => GlobalKey());
  }

  GlobalKey _anchorKeyFor(FixedTagEntry entry) {
    final keys = entry.promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    return keys.putIfAbsent(entry.id, () => GlobalKey());
  }

  void _scrollToCategory(String categoryId) {
    setState(() => _activeCategoryId = categoryId);
    final context = _sectionKeys[categoryId]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
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

class _LinkDetachPayload {
  const _LinkDetachPayload({
    required this.positiveEntryId,
    required this.negativeEntryId,
  });

  final String positiveEntryId;
  final String negativeEntryId;
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

class _PositiveSection {
  const _PositiveSection({
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      label: Text('$label $count'),
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: selected ? theme.colorScheme.onSecondaryContainer : color,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      selectedColor: color.withValues(alpha: 0.18),
      onSelected: (_) => onTap(),
    );
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
