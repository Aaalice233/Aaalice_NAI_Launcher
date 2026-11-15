import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/fixed_tags_viewport_memory_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/common/owned_scroll_controller.dart';
import 'fixed_tags_sidebar/fixed_tags_link_controller.dart';
import 'fixed_tags_sidebar/fixed_tags_link_widgets.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_actions.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_layout.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_models.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_pane.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_resize_divider.dart';
import 'fixed_tags_sidebar/fixed_tags_sidebar_top_card.dart';
import 'fixed_tags_sidebar/grouped_fixed_tag_collection.dart';
import 'sidebar_entry_tile.dart';
import 'sidebar_link_painter.dart';

/// 桌面端固定词侧边栏。
class FixedTagsSidebar extends ConsumerStatefulWidget {
  const FixedTagsSidebar({super.key});

  @override
  ConsumerState<FixedTagsSidebar> createState() => _FixedTagsSidebarState();
}

class _FixedTagsSidebarState extends ConsumerState<FixedTagsSidebar> {
  final _searchController = TextEditingController();
  late final FixedTagsViewportMemory _viewportMemory;
  late final OwnedScrollController _positiveScrollController;
  late final OwnedScrollController _negativeScrollController;
  // 筛选结果从顶部开始，也不覆盖完整列表的浏览位置。
  final _positiveFilteredScrollController = ScrollController();
  final _negativeFilteredScrollController = ScrollController();
  final _positiveGroupsKey = GlobalKey<GroupedFixedTagCollectionState>();
  final _negativeGroupsKey = GlobalKey<GroupedFixedTagCollectionState>();
  // 首次触屏按下就会让顶栏操作换到第二行，换父节点也要保住按钮的手势识别器。
  final _headerActionsKey = GlobalKey();
  late final FixedTagsLinkController _linkController;

  String _searchQuery = '';
  double? _draggedNegativePaneHeight;
  bool _isNegativeDividerHovered = false;
  bool _showOnlyEnabledPositive = false;
  bool _showOnlyEnabledNegative = false;

  @override
  void initState() {
    super.initState();
    _linkController = FixedTagsLinkController(
      isMounted: () => mounted,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onRemoveLinkByPair:
          ({
            required String positiveEntryId,
            required String negativeEntryId,
          }) => ref
              .read(fixedTagsNotifierProvider.notifier)
              .removeLinkByPair(
                positiveEntryId: positiveEntryId,
                negativeEntryId: negativeEntryId,
              ),
    );
    _viewportMemory = ref.read(fixedTagsViewportMemoryProvider);
    _positiveScrollController = OwnedScrollController(
      viewport: _viewportMemory.browseViewport(
        FixedTagsSurface.sidebar,
        FixedTagPromptType.positive,
      ),
    );
    _negativeScrollController = OwnedScrollController(
      viewport: _viewportMemory.browseViewport(
        FixedTagsSurface.sidebar,
        FixedTagPromptType.negative,
      ),
    );
    for (final controller in _listControllers) {
      controller.addListener(_linkController.scheduleLinkRepaint);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(fixedTagsNotifierProvider.notifier).inferCategoriesFromLibrary();
      _linkController.scheduleLinkRepaint();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _listControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ScrollController> get _listControllers => [
    _positiveScrollController,
    _negativeScrollController,
    _positiveFilteredScrollController,
    _negativeFilteredScrollController,
  ];

  bool _isFiltered(FixedTagPromptType promptType) =>
      _searchQuery.trim().isNotEmpty ||
      switch (promptType) {
        FixedTagPromptType.positive => _showOnlyEnabledPositive,
        FixedTagPromptType.negative => _showOnlyEnabledNegative,
      };

  ScrollController _listControllerFor(FixedTagPromptType promptType) {
    final filtered = _isFiltered(promptType);
    return switch (promptType) {
      FixedTagPromptType.positive =>
        filtered
            ? _positiveFilteredScrollController
            : _positiveScrollController,
      FixedTagPromptType.negative =>
        filtered
            ? _negativeFilteredScrollController
            : _negativeScrollController,
    };
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
    final positiveSections = buildFixedTagSections(
      context,
      positiveEntries,
      categories,
    );
    final negativeSections = buildFixedTagSections(
      context,
      negativeEntries,
      categories,
    );
    _linkController.pruneAnchorKeys(fixedState);
    _linkController.scheduleLinkRepaint();

    return Stack(
      key: _linkController.linkLayerKey,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixedTagsSidebarTopCard(
              headerActionsKey: _headerActionsKey,
              searchController: _searchController,
              searchQuery: _searchQuery,
              enabledCount:
                  fixedState.enabledCount + fixedState.negativeEnabledCount,
              totalCount: fixedState.entries.length,
              isListMode: isListMode,
              onToggleViewMode: () {
                ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setFixedTagsSidebarViewMode(isListMode ? 'grid' : 'list');
              },
              onAddAction: _handleAddAction,
              onCollapseSidebar: () {
                ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setFixedTagsSidebarExpanded(false);
              },
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
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
                links: _linkController.visibleLinks(fixedState),
                isMismatched: fixedState.isMismatched,
                color: theme.colorScheme.secondary,
                positiveAnchors: _linkController.positiveAnchorCenters,
                negativeAnchors: _linkController.negativeAnchorCenters,
                previewStart: _linkController.linkDragPreview?.start,
                previewEnd: _linkController.linkDragPreview?.end,
                previewIsDetaching:
                    _linkController.linkDragPreview?.isDetaching ?? false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAddAction(FixedTagAddAction action) {
    switch (action) {
      case FixedTagAddAction.positive:
        showAddFixedTagEntryDialog(context, ref);
        break;
      case FixedTagAddAction.negative:
        showAddFixedTagEntryDialog(
          context,
          ref,
          promptType: FixedTagPromptType.negative,
        );
        break;
      case FixedTagAddAction.libraryPositive:
        showAddFixedTagFromLibraryDialog(
          context,
          ref,
          FixedTagPromptType.positive,
        );
        break;
      case FixedTagAddAction.libraryNegative:
        showAddFixedTagFromLibraryDialog(
          context,
          ref,
          FixedTagPromptType.negative,
        );
        break;
    }
  }

  Widget _buildTagPanes(
    ThemeData theme,
    LayoutState layoutState,
    FixedTagsState fixedState,
    List<FixedTagSection> positiveSections,
    List<FixedTagSection> negativeSections,
    List<TagLibraryEntry> libraryEntries,
    bool isListMode,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = computeFixedTagsPaneMetrics(
          context,
          maxHeight: constraints.maxHeight,
          hasPositiveEntries: fixedState.positiveEntries.isNotEmpty,
          hasNegativeEntries: fixedState.negativeEntries.isNotEmpty,
          isListMode: isListMode,
          requestedNegativeHeight:
              _draggedNegativePaneHeight ?? layoutState.fixedTagsNegativeHeight,
        );

        return Padding(
          padding: fixedTagsPanePadding,
          child: Column(
            children: [
              SizedBox(
                key: const ValueKey('fixed-tags-positive-pane'),
                height: metrics.positiveHeight,
                child: _buildPromptPane(
                  promptType: FixedTagPromptType.positive,
                  cardKey: const ValueKey('fixed-tags-positive-card'),
                  keyPrefix: 'fixed-tags-positive',
                  groupsKey: _positiveGroupsKey,
                  accent: theme.colorScheme.primary,
                  icon: Icons.add_circle_outline_rounded,
                  label: context.l10n.fixedTags_positiveTitle,
                  sections: positiveSections,
                  libraryEntries: libraryEntries,
                  isListMode: isListMode,
                  paneHeight: metrics.positiveHeight,
                  enabledOnly: _showOnlyEnabledPositive,
                  onToggleEnabledOnly: () => setState(
                    () => _showOnlyEnabledPositive = !_showOnlyEnabledPositive,
                  ),
                  emptyText: _searchQuery.isNotEmpty
                      ? context.l10n.fixedTags_noMatchingEnabled
                      : _showOnlyEnabledPositive
                      ? context.l10n.fixedTags_emptyEnabledPositive
                      : context.l10n.fixedTags_empty,
                ),
              ),
              FixedTagsNegativeResizeDivider(
                isActive:
                    _isNegativeDividerHovered ||
                    _draggedNegativePaneHeight != null,
                onHoverChanged: (hovered) =>
                    setState(() => _isNegativeDividerHovered = hovered),
                onVerticalDragStart: (_) {
                  setState(() {
                    _draggedNegativePaneHeight = metrics.negativeHeight;
                  });
                },
                onVerticalDragUpdate: (details) {
                  final currentHeight =
                      _draggedNegativePaneHeight ?? metrics.negativeHeight;
                  final nextHeight = (currentHeight - details.delta.dy)
                      .clamp(
                        metrics.minimumNegativeHeight,
                        metrics.maximumNegativeHeight,
                      )
                      .toDouble();
                  if (nextHeight == currentHeight) return;
                  setState(() => _draggedNegativePaneHeight = nextHeight);
                },
                onVerticalDragEnd: (_) => _finishNegativePaneResize(),
                onVerticalDragCancel: _finishNegativePaneResize,
              ),
              Expanded(
                key: const ValueKey('fixed-tags-negative-pane'),
                child: _buildPromptPane(
                  promptType: FixedTagPromptType.negative,
                  cardKey: const ValueKey('fixed-tags-negative-card'),
                  keyPrefix: 'fixed-tags-negative',
                  groupsKey: _negativeGroupsKey,
                  accent: theme.colorScheme.error,
                  icon: Icons.block_rounded,
                  label: context.l10n.fixedTags_negativeTitle,
                  sections: negativeSections,
                  libraryEntries: libraryEntries,
                  isListMode: isListMode,
                  paneHeight: metrics.negativeHeight,
                  enabledOnly: _showOnlyEnabledNegative,
                  onToggleEnabledOnly: () => setState(
                    () => _showOnlyEnabledNegative = !_showOnlyEnabledNegative,
                  ),
                  emptyText: _searchQuery.isNotEmpty
                      ? context.l10n.fixedTags_noMatchingNegative
                      : _showOnlyEnabledNegative
                      ? context.l10n.fixedTags_emptyEnabledNegative
                      : context.l10n.fixedTags_emptyNegative,
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildPromptPane({
    required FixedTagPromptType promptType,
    required Key cardKey,
    required String keyPrefix,
    required GlobalKey<GroupedFixedTagCollectionState> groupsKey,
    required Color accent,
    required IconData icon,
    required String label,
    required List<FixedTagSection> sections,
    required List<TagLibraryEntry> libraryEntries,
    required bool isListMode,
    required double paneHeight,
    required bool enabledOnly,
    required VoidCallback onToggleEnabledOnly,
    required String emptyText,
  }) {
    final entryCount = sections.fold<int>(
      0,
      (count, section) => count + section.entries.length,
    );

    return FixedTagsSidebarPaneCard(
      cardKey: cardKey,
      accent: accent,
      paneHeight: paneHeight,
      headerBuilder: (headerExtent) => FixedTagsSidebarPaneHeader(
        icon: icon,
        label: label,
        count: entryCount,
        color: accent,
        maxExtent: headerExtent,
        trailingBuilder: (iconOnly) => FixedTagsGroupHeaderActions(
          keyPrefix: keyPrefix,
          groupsKey: groupsKey,
          iconOnly: iconOnly,
          showBulkActions: _searchQuery.trim().isEmpty,
          enabledOnly: enabledOnly,
          accent: accent,
          onToggleEnabledOnly: onToggleEnabledOnly,
        ),
      ),
      body: GroupedFixedTagCollection(
        key: groupsKey,
        keyPrefix: keyPrefix,
        sections: sections,
        isListMode: isListMode,
        forceExpanded: _searchQuery.trim().isNotEmpty,
        filtered: _isFiltered(promptType),
        controller: _listControllerFor(promptType),
        initialCollapsedSectionIds: _viewportMemory.collapsedSidebarSections(
          promptType,
        ),
        onCollapsedSectionsChanged: (sectionIds) => _viewportMemory
            .rememberCollapsedSidebarSections(promptType, sectionIds),
        emptyText: emptyText,
        listPrototypeBuilder: (categoryColor) => _buildListEntryPrototype(
          entry: sections.first.entries.first,
          categoryColor: categoryColor,
        ),
        onVisibilityChanged: _linkController.scheduleLinkRepaint,
        onReorder: (entries, oldIndex, newIndex) => ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorderWithinVisibleIds(
              promptType: promptType,
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
      linkAnchor: FixedTagsLinkAnchor(
        entry: entry,
        anchorKey: _linkController.anchorKeyFor(entry),
        onHighlightChanged: _linkController.setHighlightedLinkEntry,
        onDragStart: _linkController.startLinkDragPreview,
        onDragUpdate: _linkController.updateLinkDragPreview,
        onDragClear: _linkController.clearLinkDragPreview,
        onDetachComplete: _linkController.completeLinkDetachDrag,
      ),
      onToggle: () =>
          ref.read(fixedTagsNotifierProvider.notifier).toggleEnabled(entry.id),
      onEdit: () => showEditFixedTagEntryDialog(context, ref, entry),
      onDelete: () => confirmDeleteFixedTagEntry(context, ref, entry),
    );
    if (entry.promptType == FixedTagPromptType.negative) {
      return FixedTagsNegativeLinkTarget(
        entry: entry,
        onLinkChanged: _linkController.scheduleLinkRepaint,
        child: tile,
      );
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
          dimension: SidebarEntryTile.linkAnchorExtentOf(context),
        ),
        onToggle: _noop,
        onEdit: _noop,
        onDelete: _noop,
      ),
    );
  }

  static void _noop() {}
}
