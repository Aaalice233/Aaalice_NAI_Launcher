import 'package:flutter/material.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../common/themed_input.dart';
import '../tag_library/tag_library_entry_hover_preview.dart';
import 'fixed_tag_entry_tile.dart';
import 'fixed_tags_dialog_controller.dart';
import 'fixed_tags_dialog_models.dart';
import 'fixed_tags_link_layer.dart';

class FixedTagsColumns extends StatelessWidget {
  const FixedTagsColumns({
    super.key,
    required this.data,
    required this.commands,
    required this.controller,
    required this.isCompact,
    required this.isDark,
  });

  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final FixedTagsDialogController controller;
  final bool isCompact;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      controller.resetGeometryTracking();
      return _buildCompact(context);
    }
    if (!data.state.negativePanelExpanded) {
      controller.resetGeometryTracking();
      return ClipRect(
        child: _EntryList(
          config: _configFor(
            context,
            FixedTagPromptType.positive,
            entries: data.state.positiveEntries.sortedByOrder(),
            searchQuery: '',
          ),
          showLinkAnchors: false,
        ),
      );
    }
    final positives = data.entriesFor(
      FixedTagPromptType.positive,
      controller.positiveSearchQuery,
    );
    final negatives = data.entriesFor(
      FixedTagPromptType.negative,
      controller.negativeSearchQuery,
    );
    controller.scheduleGeometryRefresh(
      positives: positives,
      negatives: negatives,
    );
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: FixedTagsLinkLayer(
              positiveEntries: positives,
              negativeEntries: negatives,
              data: data,
              controller: controller,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FixedTagColumn(
                  config: _configFor(
                    context,
                    FixedTagPromptType.positive,
                    entries: positives,
                  ),
                ),
              ),
              const SizedBox(width: fixedTagColumnGap),
              Expanded(
                child: FixedTagColumn(
                  config: _configFor(
                    context,
                    FixedTagPromptType.negative,
                    entries: negatives,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final promptType = controller.mobilePromptType;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: Row(
            children: [
              for (final type in FixedTagPromptType.values) ...[
                if (type == FixedTagPromptType.negative)
                  const SizedBox(width: 8),
                Expanded(
                  child: _PromptTypeTab(
                    promptType: type,
                    selected: promptType == type,
                    count: type == FixedTagPromptType.positive
                        ? data.state.positiveEntries.length
                        : data.state.negativeEntries.length,
                    onTap: () => controller.selectMobilePromptType(type),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: FixedTagColumn(
            config: _configFor(context, promptType, compact: true),
          ),
        ),
      ],
    );
  }

  FixedTagColumnConfig _configFor(
    BuildContext context,
    FixedTagPromptType promptType, {
    List<FixedTagEntry>? entries,
    String? searchQuery,
    bool compact = false,
  }) {
    final title = promptType == FixedTagPromptType.positive
        ? context.l10n.fixedTags_positiveTitle
        : context.l10n.fixedTags_negativeTitle;
    return FixedTagColumnConfig(
      title: title,
      promptType: promptType,
      entries:
          entries ??
          data.entriesFor(promptType, controller.searchQueryFor(promptType)),
      allEntries: promptType == FixedTagPromptType.positive
          ? data.state.positiveEntries
          : data.state.negativeEntries,
      libraryEntries: data.libraryEntries,
      searchController: controller.searchControllerFor(promptType),
      searchQuery: searchQuery ?? controller.searchQueryFor(promptType),
      scrollController: controller.listControllerFor(promptType),
      controller: controller,
      commands: commands,
      data: data,
      isDark: isDark,
      compact: compact,
    );
  }
}

@immutable
class FixedTagColumnConfig {
  const FixedTagColumnConfig({
    required this.title,
    required this.promptType,
    required this.entries,
    required this.allEntries,
    required this.libraryEntries,
    required this.searchController,
    required this.searchQuery,
    required this.scrollController,
    required this.controller,
    required this.commands,
    required this.data,
    required this.isDark,
    required this.compact,
  });

  final String title;
  final FixedTagPromptType promptType;
  final List<FixedTagEntry> entries;
  final List<FixedTagEntry> allEntries;
  final List<TagLibraryEntry> libraryEntries;
  final TextEditingController searchController;
  final String searchQuery;
  final ScrollController scrollController;
  final FixedTagsDialogController controller;
  final FixedTagsDialogCommands commands;
  final FixedTagsDialogViewData data;
  final bool isDark;
  final bool compact;

  bool get hasSearch => searchQuery.trim().isNotEmpty;
  int get enabledCount => allEntries.where((entry) => entry.enabled).length;
}

class FixedTagColumn extends StatelessWidget {
  const FixedTagColumn({super.key, required this.config});
  final FixedTagColumnConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final controlExtent = interactionPolicy.minimumControlExtent;
    final iconButtonLayoutExtent = interactionPolicy.touchAvailable
        ? controlExtent
        : controlExtent + 8;
    final totalText = config.hasSearch
        ? context.l10n.fixedTags_columnFilteredCount(
            config.enabledCount,
            config.allEntries.length,
            config.entries.length,
          )
        : context.l10n.fixedTags_columnCount(
            config.enabledCount,
            config.allEntries.length,
          );
    final controls = <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(12, config.compact ? 6 : 10, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${config.title} · $totalText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (config.compact)
              IconButton(
                key: ValueKey(
                  'fixed-tags-toggle-all-${config.promptType.name}',
                ),
                tooltip: _enableAllLabel(context),
                visualDensity: interactionPolicy.touchAvailable
                    ? VisualDensity.standard
                    : VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: iconButtonLayoutExtent,
                  height: iconButtonLayoutExtent,
                ),
                onPressed: _toggleAll,
                icon: Icon(
                  _enableAll
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                ),
              )
            else ...[
              _ColumnActionButton(
                icon: Icons.add_rounded,
                label: context.l10n.fixedTags_new,
                tooltip: context.l10n.fixedTags_newTarget(config.title),
                onPressed: () =>
                    config.commands.editEntry(null, config.promptType),
              ),
              const SizedBox(width: 4),
              _ColumnActionButton(
                icon: Icons.playlist_add_rounded,
                label: context.l10n.fixedTags_library,
                tooltip: context.l10n.fixedTags_addFromLibraryToTarget(
                  config.title,
                ),
                onPressed: () =>
                    config.commands.pickFromLibrary(config.promptType),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: ValueKey(
                  'fixed-tags-toggle-all-${config.promptType.name}',
                ),
                onPressed: _toggleAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.standard,
                  minimumSize: Size(0, controlExtent),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_enableAllLabel(context)),
              ),
            ],
          ],
        ),
      ),
      if (config.compact) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      config.commands.editEntry(null, config.promptType),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(context.l10n.fixedTags_new),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      config.commands.pickFromLibrary(config.promptType),
                  icon: const Icon(Icons.playlist_add_rounded, size: 17),
                  label: Text(
                    context.l10n.fixedTags_addFromLibrary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ThemedInput(
          controller: config.searchController,
          decoration: InputDecoration(
            hintText: context.l10n.fixedTags_searchTarget(config.title),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: config.hasSearch
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () =>
                        config.controller.clearSearch(config.promptType),
                  )
                : null,
            isDense: true,
          ),
          onChanged: (value) =>
              config.controller.setSearchQuery(config.promptType, value),
        ),
      ),
      const SizedBox(height: 6),
      if (config.compact && config.entries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            config.hasSearch
                ? context.l10n.fixedTags_noMatching
                : context.l10n.fixedTags_emptyTarget(config.title),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
    ];

    if (config.compact) {
      return _EntryList(
        config: config,
        showLinkAnchors: true,
        header: Column(children: controls),
      );
    }

    return Column(
      children: [
        ...controls,
        Expanded(
          child: config.entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      config.hasSearch
                          ? context.l10n.fixedTags_noMatching
                          : context.l10n.fixedTags_emptyTarget(config.title),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                )
              : _EntryList(config: config, showLinkAnchors: true),
        ),
      ],
    );
  }

  bool get _enableAll => config.enabledCount != config.allEntries.length;

  String _enableAllLabel(BuildContext context) => _enableAll
      ? context.l10n.fixedTags_enableAll
      : context.l10n.fixedTags_disableAll;

  void _toggleAll() =>
      config.commands.setPromptTypeEnabled(config.promptType, _enableAll);
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.config,
    required this.showLinkAnchors,
    this.header,
  });
  final FixedTagColumnConfig config;
  final bool showLinkAnchors;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    Widget tile(FixedTagEntry entry, int index) {
      final tile = FixedTagEntryTile(
        entry: entry,
        index: index,
        isDark: config.isDark,
        compact: config.compact,
        linkAnchor: showLinkAnchors
            ? FixedTagLinkAnchor(
                entry: entry,
                data: config.data,
                commands: config.commands,
                controller: config.controller,
                mobile: config.compact,
              )
            : null,
        onToggleEnabled: () => config.commands.toggleEntry(entry),
        onEdit: () => config.commands.editEntry(entry, entry.promptType),
        onDelete: () => config.commands.deleteEntry(entry),
      );
      final libraryEntry = resolveFixedTagLibraryEntry(
        entry,
        config.libraryEntries,
      );
      final content =
          libraryEntry == null ||
              !context.interactionPolicy.precisePointerAvailable
          ? tile
          : TagLibraryEntryHoverPreview(entry: libraryEntry, child: tile);
      if (!context.interactionPolicy.precisePointerAvailable) {
        return KeyedSubtree(key: ValueKey(entry.id), child: content);
      }
      return AgentResourceDragSource(
        key: ValueKey(entry.id),
        reference: AgentChatResourceReference(
          kind: AgentChatResourceKind.fixedTag,
          source: 'fixed_tags',
          resourceId: entry.id,
          display: {'name': entry.name},
        ),
        child: content,
      );
    }

    if (config.hasSearch) {
      return ListView.builder(
        controller: config.scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        itemCount: config.entries.length + (header == null ? 0 : 1),
        itemBuilder: (_, index) {
          if (header != null && index == 0) return header!;
          final entryIndex = index - (header == null ? 0 : 1);
          return tile(config.entries[entryIndex], entryIndex);
        },
      );
    }
    return ReorderableListView.builder(
      scrollController: config.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      header: header,
      buildDefaultDragHandles: false,
      itemCount: config.entries.length,
      itemBuilder: (_, index) => tile(config.entries[index], index),
      onReorderItem: (oldIndex, newIndex) =>
          config.commands.reorder(config.promptType, oldIndex, newIndex),
    );
  }
}

class _PromptTypeTab extends StatelessWidget {
  const _PromptTypeTab({
    required this.promptType,
    required this.selected,
    required this.count,
    required this.onTap,
  });
  final FixedTagPromptType promptType;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = promptType == FixedTagPromptType.positive;
    final color = positive
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;
    return Material(
      key: ValueKey('fixed-tags-mobile-tab-${promptType.name}'),
      color: selected
          ? color.withValues(alpha: 0.14)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                positive ? Icons.auto_awesome_rounded : Icons.block_rounded,
                size: 16,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  positive
                      ? context.l10n.fixedTags_positiveTitle
                      : context.l10n.fixedTags_negativeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? color
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(count.toString(), style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnActionButton extends StatelessWidget {
  const _ColumnActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}
