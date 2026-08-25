import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_link.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../router/app_router.dart';
import '../common/themed_confirm_dialog.dart';
import '../common/themed_switch.dart';
import '../tag_library/tag_library_entry_hover_preview.dart';
import 'fixed_tag_edit_dialog.dart';

import '../common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

const double _fixedTagDialogCollapsedWidth = 520;
const double _fixedTagDialogExpandedWidth = 980;
const double _fixedTagDialogHorizontalInset = 32;
const double _fixedTagColumnGap = 28;
const double _fixedTagLinkAnchorInset = 31;
const double _fixedTagLinkRowHeight = 64;
const double _fixedTagLinkTopOffset = 136;
const double _fixedTagLinkBottomPadding = 16;

/// 固定词管理对话框
class FixedTagsDialog extends ConsumerStatefulWidget {
  const FixedTagsDialog({super.key});

  @override
  ConsumerState<FixedTagsDialog> createState() => _FixedTagsDialogState();
}

class _FixedTagsDialogState extends ConsumerState<FixedTagsDialog> {
  final _positiveSearchController = TextEditingController();
  final _negativeSearchController = TextEditingController();
  final _positiveListController = ScrollController();
  final _negativeListController = ScrollController();
  final _linkLayerKey = GlobalKey();
  final _positiveAnchorKeys = <String, GlobalKey>{};
  final _negativeAnchorKeys = <String, GlobalKey>{};
  String _positiveSearchQuery = '';
  String _negativeSearchQuery = '';
  int? _scheduledLinkGeometryHash;
  bool _scrollLinkRepaintScheduled = false;

  @override
  void initState() {
    super.initState();
    _positiveListController.addListener(_repaintLinkLayer);
    _negativeListController.addListener(_repaintLinkLayer);
  }

  @override
  void dispose() {
    _positiveListController.removeListener(_repaintLinkLayer);
    _negativeListController.removeListener(_repaintLinkLayer);
    _positiveSearchController.dispose();
    _negativeSearchController.dispose();
    _positiveListController.dispose();
    _negativeListController.dispose();
    super.dispose();
  }

  void _repaintLinkLayer() {
    if (!mounted) {
      return;
    }

    setState(() {});
    if (_scrollLinkRepaintScheduled) {
      return;
    }
    _scrollLinkRepaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollLinkRepaintScheduled = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  GlobalKey _anchorKeyFor(FixedTagEntry entry) {
    final keys = entry.promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    return keys.putIfAbsent(entry.id, GlobalKey.new);
  }

  void _scheduleLinkGeometryRefresh({
    required List<FixedTagEntry> positives,
    required List<FixedTagEntry> negatives,
  }) {
    final geometryHash = Object.hashAll([
      for (final entry in positives) entry.id,
      '|',
      for (final entry in negatives) entry.id,
    ]);
    if (_scheduledLinkGeometryHash == geometryHash) {
      return;
    }
    _scheduledLinkGeometryHash = geometryHash;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scheduledLinkGeometryHash == geometryHash) {
        setState(() {});
      }
    });
  }

  Map<String, Offset> _collectAnchorCenters(Map<String, GlobalKey> keys) {
    final layerRenderObject = _linkLayerKey.currentContext?.findRenderObject();
    if (layerRenderObject is! RenderBox || !layerRenderObject.hasSize) {
      return const {};
    }

    final centers = <String, Offset>{};
    for (final entry in keys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }
      final globalCenter = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      centers[entry.key] = layerRenderObject.globalToLocal(globalCenter);
    }
    return centers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final entries = fixedTagsState.entries;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = math.max(
      320.0,
      screenWidth - _fixedTagDialogHorizontalInset,
    );
    final targetWidth = fixedTagsState.negativePanelExpanded
        ? _fixedTagDialogExpandedWidth
        : _fixedTagDialogCollapsedWidth;
    final dialogWidth = math.min(targetWidth, availableWidth);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: dialogWidth,
            constraints: BoxConstraints(
              minWidth: dialogWidth,
              maxWidth: dialogWidth,
              maxHeight: 620,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.85)
                  : theme.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                if (isDark)
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                _buildHeader(theme, isDark),

                // 列表区域
                Flexible(
                  child:
                      entries.isEmpty && !fixedTagsState.negativePanelExpanded
                      ? _buildEmptyState(theme, isDark)
                      : _buildListBody(theme, fixedTagsState, isDark),
                ),

                // 底部操作栏
                _buildFooter(theme, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final enabledCount = fixedTagsState.entries
        .where((entry) => entry.enabled)
        .length;
    final totalCount = fixedTagsState.entries.length;
    final linkCount = fixedTagsState.links.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: isDark ? 0.08 : 0.05),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // 图标容器增加渐变背景
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.push_pin_rounded,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.fixedTags_manage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                if (totalCount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: enabledCount > 0
                              ? theme.colorScheme.secondary.withValues(
                                  alpha: 0.15,
                                )
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${context.l10n.fixedTags_enabledCount(enabledCount.toString(), totalCount.toString())} · ${context.l10n.fixedTags_linkCount(linkCount)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: enabledCount > 0
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ref
                  .read(fixedTagsNotifierProvider.notifier)
                  .setNegativePanelExpanded(
                    !fixedTagsState.negativePanelExpanded,
                  );
            },
            icon: Icon(
              fixedTagsState.negativePanelExpanded
                  ? Icons.keyboard_tab_rounded
                  : Icons.view_sidebar_rounded,
              size: 18,
            ),
            label: Text(
              fixedTagsState.negativePanelExpanded
                  ? context.l10n.fixedTags_collapseNegative
                  : context.l10n.fixedTags_expandNegative,
            ),
          ),
          IconButton(
            tooltip: context.l10n.fixedTags_undoTooltip,
            onPressed: fixedTagsState.canUndo
                ? () => ref.read(fixedTagsNotifierProvider.notifier).undo()
                : null,
            icon: const Icon(Icons.undo_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.l10n.fixedTags_redoTooltip,
            onPressed: fixedTagsState.canRedo
                ? () => ref.read(fixedTagsNotifierProvider.notifier).redo()
                : null,
            icon: const Icon(Icons.redo_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // 全开/全关切换按钮
          if (totalCount > 0) ...[
            ThemedSwitch(
              value: enabledCount == totalCount,
              onChanged: (value) {
                ref
                    .read(fixedTagsNotifierProvider.notifier)
                    .setAllEnabled(value);
              },
              scale: 0.85,
            ),
            const SizedBox(width: 8),
          ],
          // 关闭按钮美化
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody(ThemeData theme, FixedTagsState state, bool isDark) {
    if (!state.negativePanelExpanded) {
      _scheduledLinkGeometryHash = null;
    }
    return ClipRect(
      child: state.negativePanelExpanded
          ? _buildDualColumnLayout(theme, state, isDark)
          : _buildEntryList(
              theme,
              state.positiveEntries.sortedByOrder(),
              isDark,
              FixedTagPromptType.positive,
              scrollController: _positiveListController,
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.fixedTags_empty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.fixedTags_emptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(
    ThemeData theme,
    List<FixedTagEntry> entries,
    bool isDark,
    FixedTagPromptType promptType, {
    ScrollController? scrollController,
    bool allowReorder = true,
    bool showLinkAnchors = false,
  }) {
    final libraryEntries = ref.watch(
      tagLibraryPageNotifierProvider.select((state) => state.entries),
    );

    Widget buildTile(FixedTagEntry entry, int index) {
      final tile = _FixedTagEntryTile(
        entry: entry,
        index: index,
        isDark: isDark,
        linkAnchor: showLinkAnchors ? _buildLinkAnchor(theme, entry) : null,
        onToggleEnabled: () {
          ref.read(fixedTagsNotifierProvider.notifier).toggleEnabled(entry.id);
        },
        onEdit: () => _showEditDialog(entry),
        onDelete: () => _showDeleteConfirmation(entry),
      );
      final libraryEntry = resolveFixedTagLibraryEntry(entry, libraryEntries);
      if (libraryEntry == null) {
        return KeyedSubtree(key: ValueKey(entry.id), child: tile);
      }
      return TagLibraryEntryHoverPreview(
        key: ValueKey(entry.id),
        entry: libraryEntry,
        child: tile,
      );
    }

    if (!allowReorder) {
      return ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        itemCount: entries.length,
        itemBuilder: (context, index) => buildTile(entries[index], index),
      );
    }

    return ReorderableListView.builder(
      scrollController: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return buildTile(entry, index);
      },
      onReorderItem: (oldIndex, newIndex) {
        ref
            .read(fixedTagsNotifierProvider.notifier)
            .reorderWithinPromptType(promptType, oldIndex, newIndex);
      },
    );
  }

  Widget _buildDualColumnLayout(
    ThemeData theme,
    FixedTagsState state,
    bool isDark,
  ) {
    final positives = _filterEntries(
      state.positiveEntries.sortedByOrder(),
      _positiveSearchQuery,
    );
    final negatives = _filterEntries(
      state.negativeEntries.sortedByOrder(),
      _negativeSearchQuery,
    );
    _scheduleLinkGeometryRefresh(positives: positives, negatives: negatives);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _fixedTagColumnGap) / 2;
        final positiveAnchorX = columnWidth - _fixedTagLinkAnchorInset;
        final negativeAnchorX =
            columnWidth + _fixedTagColumnGap + _fixedTagLinkAnchorInset;
        final positiveAnchors = _collectAnchorCenters(_positiveAnchorKeys);
        final negativeAnchors = _collectAnchorCenters(_negativeAnchorKeys);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: _linkLayerKey,
                    painter: _FixedTagLinkPainter(
                      positiveEntries: positives,
                      negativeEntries: negatives,
                      links: state.links,
                      isMismatched: state.isMismatched,
                      color: theme.colorScheme.secondary,
                      positiveAnchors: positiveAnchors,
                      negativeAnchors: negativeAnchors,
                      positiveAnchorX: positiveAnchorX,
                      negativeAnchorX: negativeAnchorX,
                      positiveScrollOffset: _positiveListController.hasClients
                          ? _positiveListController.offset
                          : 0,
                      negativeScrollOffset: _negativeListController.hasClients
                          ? _negativeListController.offset
                          : 0,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildFixedTagColumn(
                    theme: theme,
                    title: context.l10n.fixedTags_positiveTitle,
                    promptType: FixedTagPromptType.positive,
                    entries: positives,
                    searchController: _positiveSearchController,
                    searchQuery: _positiveSearchQuery,
                    isDark: isDark,
                    scrollController: _positiveListController,
                    onSearchChanged: (value) {
                      setState(() => _positiveSearchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: _fixedTagColumnGap),
                Expanded(
                  child: _buildFixedTagColumn(
                    theme: theme,
                    title: context.l10n.fixedTags_negativeTitle,
                    promptType: FixedTagPromptType.negative,
                    entries: negatives,
                    searchController: _negativeSearchController,
                    searchQuery: _negativeSearchQuery,
                    isDark: isDark,
                    scrollController: _negativeListController,
                    onSearchChanged: (value) {
                      setState(() => _negativeSearchQuery = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<FixedTagEntry> _filterEntries(
    List<FixedTagEntry> entries,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return entries;
    }
    return entries.where((entry) {
      return entry.name.toLowerCase().contains(normalized) ||
          entry.content.toLowerCase().contains(normalized);
    }).toList();
  }

  Widget _buildFixedTagColumn({
    required ThemeData theme,
    required String title,
    required FixedTagPromptType promptType,
    required List<FixedTagEntry> entries,
    required TextEditingController searchController,
    required String searchQuery,
    required bool isDark,
    required ScrollController scrollController,
    required ValueChanged<String> onSearchChanged,
  }) {
    final state = ref.watch(fixedTagsNotifierProvider);
    final allEntries = promptType == FixedTagPromptType.positive
        ? state.positiveEntries
        : state.negativeEntries;
    final enabledCount = allEntries.where((entry) => entry.enabled).length;
    final hasSearch = searchQuery.trim().isNotEmpty;
    final totalText = hasSearch
        ? context.l10n.fixedTags_columnFilteredCount(
            enabledCount,
            allEntries.length,
            entries.length,
          )
        : context.l10n.fixedTags_columnCount(enabledCount, allEntries.length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$title · $totalText',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildColumnActionButton(
                theme: theme,
                icon: Icons.add_rounded,
                label: context.l10n.fixedTags_new,
                tooltip: context.l10n.fixedTags_newTarget(title),
                onPressed: () =>
                    _showEditDialog(null, initialPromptType: promptType),
              ),
              const SizedBox(width: 4),
              _buildColumnActionButton(
                theme: theme,
                icon: Icons.playlist_add_rounded,
                label: context.l10n.fixedTags_library,
                tooltip: context.l10n.fixedTags_addFromLibraryToTarget(title),
                onPressed: () => _showLibraryPicker(theme, promptType),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  if (promptType == FixedTagPromptType.positive) {
                    ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .setAllPositiveEnabled(
                          enabledCount != allEntries.length,
                        );
                  } else {
                    ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .setAllNegativeEnabled(
                          enabledCount != allEntries.length,
                        );
                  }
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  enabledCount == allEntries.length
                      ? context.l10n.fixedTags_disableAll
                      : context.l10n.fixedTags_enableAll,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ThemedInput(
            controller: searchController,
            decoration: InputDecoration(
              hintText: context.l10n.fixedTags_searchTarget(title),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: hasSearch
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    hasSearch
                        ? context.l10n.fixedTags_noMatching
                        : context.l10n.fixedTags_emptyTarget(title),
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : _buildEntryList(
                  theme,
                  entries,
                  isDark,
                  promptType,
                  scrollController: scrollController,
                  allowReorder: !hasSearch,
                  showLinkAnchors: true,
                ),
        ),
      ],
    );
  }

  Widget _buildColumnActionButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLinkAnchor(ThemeData theme, FixedTagEntry entry) {
    final state = ref.watch(fixedTagsNotifierProvider);
    final linkCount = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id).length
        : state.linkedPositivesOf(entry.id).length;
    final linkedNames = entry.promptType == FixedTagPromptType.positive
        ? state
              .linkedNegativesOf(entry.id)
              .map((entry) => entry.displayName)
              .join(', ')
        : state
              .linkedPositivesOf(entry.id)
              .map((entry) => entry.displayName)
              .join(', ');
    final tooltip = linkCount == 0
        ? context.l10n.fixedTags_dragToLink
        : context.l10n.fixedTags_linkedToNames(linkedNames);

    final anchorVisual = SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: GestureDetector(
          onTap: () => _showLinkMenu(entry),
          child: Tooltip(
            message: tooltip,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 17,
                  color: linkCount > 0
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline,
                ),
                if (linkCount > 0)
                  Positioned(
                    right: -6,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        linkCount.toString(),
                        style: TextStyle(
                          fontSize: 8,
                          color: theme.colorScheme.onSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (entry.promptType == FixedTagPromptType.positive) {
      return KeyedSubtree(
        key: _anchorKeyFor(entry),
        child: Draggable<String>(
          data: entry.id,
          feedback: Material(
            color: Colors.transparent,
            child: Icon(
              Icons.link_rounded,
              color: theme.colorScheme.secondary,
              size: 22,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: anchorVisual),
          child: anchorVisual,
        ),
      );
    }

    return KeyedSubtree(
      key: _anchorKeyFor(entry),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final positive = state.entries.cast<FixedTagEntry?>().firstWhere(
            (entry) => entry?.id == details.data,
            orElse: () => null,
          );
          return positive?.promptType == FixedTagPromptType.positive;
        },
        onAcceptWithDetails: (details) {
          ref
              .read(fixedTagsNotifierProvider.notifier)
              .createLink(
                positiveEntryId: details.data,
                negativeEntryId: entry.id,
              );
        },
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return AnimatedScale(
            scale: isActive ? 1.25 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: anchorVisual,
          );
        },
      ),
    );
  }

  void _showLinkMenu(FixedTagEntry entry) {
    final state = ref.read(fixedTagsNotifierProvider);
    final linkedEntries = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id)
        : state.linkedPositivesOf(entry.id);
    if (linkedEntries.isEmpty) {
      AppToast.info(context, context.l10n.fixedTags_linkInstruction);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(context.l10n.fixedTags_manageLinks),
          children: [
            for (final linkedEntry in linkedEntries)
              SimpleDialogOption(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (entry.promptType == FixedTagPromptType.positive) {
                    await ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .removeLinkByPair(
                          positiveEntryId: entry.id,
                          negativeEntryId: linkedEntry.id,
                        );
                  } else {
                    await ref
                        .read(fixedTagsNotifierProvider.notifier)
                        .removeLinkByPair(
                          positiveEntryId: linkedEntry.id,
                          negativeEntryId: entry.id,
                        );
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.link_off_rounded, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.fixedTags_removeLink(
                          linkedEntry.displayName,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFooter(ThemeData theme, bool isDark) {
    final hasEntries = ref.watch(fixedTagsNotifierProvider).entries.isNotEmpty;
    final negativeExpanded = ref
        .watch(fixedTagsNotifierProvider)
        .negativePanelExpanded;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // 打开词库按钮 - 轮廓样式
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.tagLibraryPage);
            },
            icon: const Icon(Icons.library_books_outlined, size: 17),
            label: Text(context.l10n.fixedTags_openLibrary),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          // 清空按钮 - 危险操作
          if (hasEntries)
            OutlinedButton.icon(
              onPressed: _showClearAllConfirmation,
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 17,
                color: theme.colorScheme.error,
              ),
              label: Text(
                context.l10n.fixedTags_clearAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
            ),
          const Spacer(),
          if (negativeExpanded)
            Text(
              context.l10n.fixedTags_footerExpandedHint,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else ...[
            // 收起负向列时保留正向固定词入口，标签明确目标。
            FilledButton.tonalIcon(
              onPressed: () => _showEditDialog(
                null,
                initialPromptType: FixedTagPromptType.positive,
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(context.l10n.fixedTags_newPositive),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () =>
                  _showLibraryPicker(theme, FixedTagPromptType.positive),
              icon: const Icon(Icons.playlist_add_rounded, size: 17),
              label: Text(context.l10n.fixedTags_addPositiveFromLibraryShort),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 显示词库选择器
  void _showLibraryPicker(ThemeData theme, FixedTagPromptType promptType) {
    final libraryState = ref.read(tagLibraryPageNotifierProvider);
    if (libraryState.entries.isEmpty) {
      AppToast.info(context, context.l10n.fixedTags_libraryEmpty);
      return;
    }

    final entries = filterUnlinkedLibraryEntries(
      libraryEntries: libraryState.entries,
      fixedEntries: ref.read(fixedTagsNotifierProvider).entries,
    );

    showDialog(
      context: context,
      builder: (ctx) => FixedTagLibraryPickerDialog(
        entries: entries,
        onSelect: (entry) => _addFromLibrary(entry, promptType),
      ),
    );
  }

  /// 从词库添加条目
  Future<void> _addFromLibrary(
    TagLibraryEntry entry,
    FixedTagPromptType promptType,
  ) async {
    await ref
        .read(fixedTagsNotifierProvider.notifier)
        .addEntry(
          name: entry.name,
          content: entry.content,
          weight: 1.0,
          position: FixedTagPosition.prefix,
          enabled: true,
          promptType: promptType,
          sourceEntryId: entry.id, // 【修复】传递词库条目ID，启用双向同步
          categoryId: entry.categoryId,
        );
  }

  void _showEditDialog(
    FixedTagEntry? entry, {
    FixedTagPromptType initialPromptType = FixedTagPromptType.positive,
  }) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (context) => FixedTagEditDialog(
        entry: entry,
        initialPromptType: initialPromptType,
      ),
    );

    if (result != null) {
      if (entry == null) {
        // 新建
        await ref
            .read(fixedTagsNotifierProvider.notifier)
            .addEntry(
              name: result.name,
              content: result.content,
              weight: result.weight,
              position: result.position,
              promptType: result.promptType,
              enabled: result.enabled,
            );
      } else {
        // 更新
        await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
      }
    }
  }

  void _showDeleteConfirmation(FixedTagEntry entry) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_deleteTitle,
      content: context.l10n.fixedTags_deleteConfirm(entry.displayName),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(entry.id);
    }
  }

  /// 显示清空所有固定词确认对话框
  void _showClearAllConfirmation() async {
    final entriesCount = ref.read(fixedTagsNotifierProvider).entries.length;

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_clearAllTitle,
      content: context.l10n.fixedTags_clearAllConfirm(entriesCount),
      confirmText: context.l10n.fixedTags_clearAll,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed && mounted) {
      ref.read(fixedTagsNotifierProvider.notifier).clearAll();
      AppToast.success(context, context.l10n.fixedTags_clearedSuccess);
    }
  }
}

/// 词库选择对话框
class FixedTagLibraryPickerDialog extends StatefulWidget {
  const FixedTagLibraryPickerDialog({
    super.key,
    required this.entries,
    required this.onSelect,
  });

  final List<TagLibraryEntry> entries;
  final ValueChanged<TagLibraryEntry> onSelect;

  @override
  State<FixedTagLibraryPickerDialog> createState() =>
      _FixedTagLibraryPickerDialogState();
}

class _FixedTagLibraryPickerDialogState
    extends State<FixedTagLibraryPickerDialog> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<TagLibraryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;
    final query = _searchQuery.toLowerCase();
    return widget.entries.where((e) {
      return e.name.toLowerCase().contains(query) ||
          e.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.fixedTags_addFromLibrary,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ThemedInput(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.fixedTags_searchLibraryEntries,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(height: 4),
            // 列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.fixedTags_noMatchingResults,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final tile = _LibraryEntryTile(
                          key: ValueKey('fixed-tag-library-entry-${entry.id}'),
                          entry: entry,
                          onTap: () {
                            widget.onSelect(entry);
                            Navigator.of(context).pop();
                          },
                        );
                        if (!entry.hasThumbnail) return tile;
                        return TagLibraryEntryHoverPreview(
                          entry: entry,
                          child: tile,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 词库条目选项
class _LibraryEntryTile extends StatelessWidget {
  const _LibraryEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TagLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.isNotEmpty ? entry.name : entry.content,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.name.isNotEmpty && entry.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.content.replaceAll('\n', ' '),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 固定词条目卡片 - 紧凑版
class _FixedTagEntryTile extends StatefulWidget {
  final FixedTagEntry entry;
  final int index;
  final bool isDark;
  final Widget? linkAnchor;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FixedTagEntryTile({
    required this.entry,
    required this.index,
    required this.isDark,
    this.linkAnchor,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_FixedTagEntryTile> createState() => _FixedTagEntryTileState();
}

class _FixedTagEntryTileState extends State<_FixedTagEntryTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final isDark = widget.isDark;

    // 位置颜色
    final posColor = entry.isPrefix
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;

    // 禁用状态透明度
    final disabledOpacity = entry.enabled ? 1.0 : 0.5;
    final hasPositiveAnchor =
        entry.promptType == FixedTagPromptType.positive &&
        widget.linkAnchor != null;
    final hasNegativeAnchor =
        entry.promptType == FixedTagPromptType.negative &&
        widget.linkAnchor != null;

    return ReorderableDragStartListener(
      index: widget.index,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // 色差背景：启用时用主题色深背景，禁用时发灰
            color: entry.enabled
                ? (isDark
                      ? theme.colorScheme.surfaceContainerHigh
                      : theme.colorScheme.surfaceContainerHighest)
                : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            // 无边框 + 阴影
            boxShadow: entry.enabled
                ? [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(
                        alpha: isDark ? 0.3 : 0.1,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: -2,
                    ),
                    if (_isHovering)
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ]
                : [
                    // 禁用状态也有轻微阴影
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: disabledOpacity,
            child: Row(
              children: [
                if (hasNegativeAnchor) ...[
                  widget.linkAnchor!,
                  const SizedBox(width: 10),
                ],

                // 启用开关
                ThemedSwitch(
                  value: entry.enabled,
                  onChanged: (_) => widget.onToggleEnabled(),
                  scale: 0.7,
                ),

                // 名称、内容和标签区域都可切换启用状态；开关、操作按钮和
                // 连线锚点仍保留各自独立交互。
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onToggleEnabled,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: entry.enabled
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                      decoration: entry.enabled
                                          ? null
                                          : TextDecoration.lineThrough,
                                      decorationColor: theme.colorScheme.outline
                                          .withValues(alpha: 0.6),
                                      decorationThickness: 2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (entry.content.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        entry.content.replaceAll('\n', ' '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: entry.enabled
                                              ? theme.colorScheme.outline
                                                    .withValues(alpha: 0.8)
                                              : theme.colorScheme.outline
                                                    .withValues(alpha: 0.5),
                                          height: 1.2,
                                          decoration: entry.enabled
                                              ? null
                                              : TextDecoration.lineThrough,
                                          decorationColor: theme
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.4),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: entry.enabled
                                        ? posColor.withValues(alpha: 0.15)
                                        : theme.colorScheme.outline.withValues(
                                            alpha: 0.1,
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        entry.isPrefix
                                            ? Icons.arrow_forward_rounded
                                            : Icons.arrow_back_rounded,
                                        size: 10,
                                        color: entry.enabled
                                            ? posColor
                                            : theme.colorScheme.outline,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        entry.isPrefix
                                            ? context.l10n.fixedTags_prefix
                                            : context.l10n.fixedTags_suffix,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: entry.enabled
                                              ? posColor
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (entry.weight != 1.0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.enabled
                                          ? theme.colorScheme.secondary
                                                .withValues(alpha: 0.15)
                                          : theme.colorScheme.outline
                                                .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${entry.weight.toStringAsFixed(1)}x',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: entry.enabled
                                            ? theme.colorScheme.secondary
                                            : theme.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 操作按钮 - 紧凑
                AnimatedOpacity(
                  opacity: _isHovering ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CompactIconButton(
                        icon: Icons.edit_outlined,
                        onPressed: widget.onEdit,
                        tooltip: context.l10n.common_edit,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        hoverColor: theme.colorScheme.primary,
                      ),
                      _CompactIconButton(
                        icon: Icons.close_rounded,
                        onPressed: widget.onDelete,
                        tooltip: context.l10n.common_delete,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        hoverColor: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),
                if (hasPositiveAnchor) ...[
                  const SizedBox(width: 6),
                  widget.linkAnchor!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 紧凑图标按钮
class _CompactIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;
  final Color hoverColor;

  const _CompactIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    required this.hoverColor,
  });

  @override
  State<_CompactIconButton> createState() => _CompactIconButtonState();
}

class _CompactIconButtonState extends State<_CompactIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              widget.icon,
              size: 15,
              color: _isHovering ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedTagLinkPainter extends CustomPainter {
  _FixedTagLinkPainter({
    required this.positiveEntries,
    required this.negativeEntries,
    required this.links,
    required this.isMismatched,
    required this.color,
    required this.positiveAnchors,
    required this.negativeAnchors,
    required this.positiveAnchorX,
    required this.negativeAnchorX,
    required this.positiveScrollOffset,
    required this.negativeScrollOffset,
  });

  final List<FixedTagEntry> positiveEntries;
  final List<FixedTagEntry> negativeEntries;
  final List<FixedTagLink> links;
  final bool Function(FixedTagLink link) isMismatched;
  final Color color;
  final Map<String, Offset> positiveAnchors;
  final Map<String, Offset> negativeAnchors;
  final double positiveAnchorX;
  final double negativeAnchorX;
  final double positiveScrollOffset;
  final double negativeScrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (positiveEntries.isEmpty || negativeEntries.isEmpty || links.isEmpty) {
      return;
    }
    const clipTop = _fixedTagLinkTopOffset - _fixedTagLinkRowHeight / 2;
    final clipBottom = size.height - _fixedTagLinkBottomPadding;
    if (clipBottom <= clipTop) {
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, clipTop, size.width, clipBottom));

    final positiveIndex = {
      for (var i = 0; i < positiveEntries.length; i++) positiveEntries[i].id: i,
    };
    final negativeIndex = {
      for (var i = 0; i < negativeEntries.length; i++) negativeEntries[i].id: i,
    };

    for (final link in links) {
      final startIndex = positiveIndex[link.positiveEntryId];
      final endIndex = negativeIndex[link.negativeEntryId];
      if (startIndex == null || endIndex == null) {
        continue;
      }

      final start =
          positiveAnchors[link.positiveEntryId] ??
          Offset(
            positiveAnchorX,
            _fixedTagLinkTopOffset +
                startIndex * _fixedTagLinkRowHeight -
                positiveScrollOffset,
          );
      final end =
          negativeAnchors[link.negativeEntryId] ??
          Offset(
            negativeAnchorX,
            _fixedTagLinkTopOffset +
                endIndex * _fixedTagLinkRowHeight -
                negativeScrollOffset,
          );
      if (!_isVisible(start.dy, size.height) &&
          !_isVisible(end.dy, size.height)) {
        continue;
      }
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + 28, start.dy, end.dx - 28, end.dy, end.dx, end.dy);
      final paint = Paint()
        ..color = color.withValues(alpha: isMismatched(link) ? 0.35 : 0.65)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;

      if (isMismatched(link)) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  bool _isVisible(double y, double height) {
    return y >= _fixedTagLinkTopOffset - _fixedTagLinkRowHeight / 2 &&
        y <= height - _fixedTagLinkBottomPadding;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(
            distance,
            next.clamp(0.0, metric.length).toDouble(),
          ),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FixedTagLinkPainter oldDelegate) {
    return oldDelegate.positiveEntries != positiveEntries ||
        oldDelegate.negativeEntries != negativeEntries ||
        oldDelegate.links != links ||
        oldDelegate.color != color ||
        oldDelegate.positiveAnchors != positiveAnchors ||
        oldDelegate.negativeAnchors != negativeAnchors ||
        oldDelegate.positiveAnchorX != positiveAnchorX ||
        oldDelegate.negativeAnchorX != negativeAnchorX ||
        oldDelegate.positiveScrollOffset != positiveScrollOffset ||
        oldDelegate.negativeScrollOffset != negativeScrollOffset;
  }
}
