import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../../data/services/online_gallery/quick_tag_cloud_access.dart';
import '../../../l10n/app_localizations.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/quick_tag_cloud_gallery_provider.dart';

class QuickTagCloudToolbar extends ConsumerStatefulWidget {
  const QuickTagCloudToolbar({
    super.key,
    required this.onFiltersChanged,
    required this.selectedRatings,
    this.favoritesMode = false,
    this.wrapControls = false,
  });

  final Future<void> Function() onFiltersChanged;
  final Set<String> selectedRatings;
  final bool favoritesMode;
  final bool wrapControls;

  @override
  ConsumerState<QuickTagCloudToolbar> createState() =>
      _QuickTagCloudToolbarState();
}

class _QuickTagCloudToolbarState extends ConsumerState<QuickTagCloudToolbar> {
  bool _normalizingCodex = false;
  bool _normalizingFilters = false;
  bool _openingCategoryPicker = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(quickTagCloudFilterProvider.notifier);
      var changed = await notifier.initializeContentAccess();
      if (!mounted) return;
      final query = ref.read(quickTagCloudFilterProvider);
      final allowNsfw = QuickTagCloudAccess.allowsNsfw(widget.selectedRatings);
      final allowR18g = QuickTagCloudAccess.allowsR18g(widget.selectedRatings);
      if (query.allowNsfw != allowNsfw || query.allowR18g != allowR18g) {
        await notifier.setContentAccess(
          allowNsfw: allowNsfw,
          allowR18g: allowR18g,
        );
        changed = true;
      }
      if (mounted && changed) await widget.onFiltersChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(quickTagCloudFilterProvider);
    final catalogValue = ref.watch(quickTagCloudCatalogProvider);
    final catalog = catalogValue.valueOrNull;
    final selectedMeta = catalog?.findCodex(query.codexId);
    if (catalog != null &&
        query.codexId != 'all' &&
        selectedMeta == null &&
        !_normalizingCodex) {
      final fallback =
          catalog.findCodex('suozhang') ??
          (catalog.codexes.isEmpty ? null : catalog.codexes.first);
      if (fallback != null) {
        _normalizingCodex = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            ref
                .read(quickTagCloudFilterProvider.notifier)
                .selectCodex(fallback.id);
            await widget.onFiltersChanged();
          } finally {
            if (mounted) _normalizingCodex = false;
          }
        });
      }
    }
    final allowNsfw = QuickTagCloudAccess.allowsNsfw(widget.selectedRatings);
    final selectedCodexLocked = selectedMeta?.nsfw == true && !allowNsfw;
    final codexValue = query.codexId == 'all' || selectedCodexLocked
        ? null
        : ref.watch(quickTagCloudCodexProvider(query.codexId));
    final codex = codexValue?.valueOrNull;
    final invalidCategory =
        codex != null &&
        query.categoryPath.isNotEmpty &&
        !_containsCategoryPath(codex.tree, query.categoryPath);
    final availableUpdateFilters =
        (codex?.asMediaMeta() ?? selectedMeta)?.updateFilters
            .map((filter) => filter.id)
            .toSet() ??
        const <String>{};
    final invalidUpdateFilter =
        codex != null &&
        query.updateFilterId.isNotEmpty &&
        !availableUpdateFilters.contains(query.updateFilterId);
    if ((invalidCategory || invalidUpdateFilter) && !_normalizingFilters) {
      _normalizingFilters = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final notifier = ref.read(quickTagCloudFilterProvider.notifier);
          if (invalidCategory) notifier.selectCategory(const []);
          if (invalidUpdateFilter) notifier.selectUpdateFilter('');
          await widget.onFiltersChanged();
        } finally {
          if (mounted) _normalizingFilters = false;
        }
      });
    }

    Future<void> selectScope(QuickTagCloudBrowseScope scope) async {
      ref.read(quickTagCloudFilterProvider.notifier).selectScope(scope);
      await widget.onFiltersChanged();
    }

    final scopeControl = widget.favoritesMode
        ? null
        : _ScopeControl(
            selected: query.scope,
            stacked: widget.wrapControls,
            onSelected: selectScope,
          );
    final sourceControls = <Widget>[
      _ToolbarButton(
        icon: Icons.menu_book_outlined,
        label: selectedMeta?.title ?? l10n.onlineGallery_codexAll,
        loading: catalogValue.isLoading,
        expanded: widget.wrapControls,
        onPressed: catalog == null
            ? null
            : () => _showCodexPicker(
                context,
                catalog,
                query,
                codexValue?.valueOrNull,
                allowNsfw: allowNsfw,
              ),
      ),
      _ToolbarButton(
        icon: Icons.account_tree_outlined,
        label: query.categoryPath.isEmpty
            ? l10n.onlineGallery_codexAllCategories
            : query.categoryPath.join(' / '),
        loading: (codexValue?.isLoading ?? false) || _openingCategoryPicker,
        expanded: widget.wrapControls,
        onPressed: query.codexId == 'all' || selectedCodexLocked
            ? null
            : () => _openCategoryPicker(query.codexId, query.categoryPath),
      ),
      _ToolbarButton(
        icon: Icons.tune,
        label: l10n.common_filter,
        expanded: widget.wrapControls,
        onPressed: catalog == null
            ? null
            : () => _showFilterDialog(context, selectedMeta, query),
      ),
      if (catalog?.isOffline == true)
        Tooltip(
          message: catalog!.refreshError?.toString() ?? '',
          child: Chip(
            avatar: const Icon(Icons.cloud_off_outlined, size: 16),
            label: Text(l10n.onlineGallery_codexOffline),
            visualDensity: VisualDensity.compact,
          ),
        ),
      if (codexValue?.valueOrNull?.loadSource ==
              QuickTagCloudCodexLoadSource.fallback ||
          codexValue?.valueOrNull?.loadSource ==
              QuickTagCloudCodexLoadSource.previousRelease)
        Tooltip(
          message:
              codexValue?.valueOrNull?.loadSource ==
                  QuickTagCloudCodexLoadSource.previousRelease
              ? l10n.onlineGallery_codexPreviousRelease
              : l10n.onlineGallery_codexExternalFallback,
          child: Semantics(
            label:
                codexValue?.valueOrNull?.loadSource ==
                    QuickTagCloudCodexLoadSource.previousRelease
                ? l10n.onlineGallery_codexPreviousRelease
                : l10n.onlineGallery_codexExternalFallback,
            child: Icon(
              Icons.cached_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
      if (catalogValue.hasError)
        Tooltip(
          message: catalogValue.error.toString(),
          child: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
    ];
    final filterControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [if (scopeControl != null) scopeControl, ...sourceControls],
    );

    final contributorsButton = selectedMeta == null
        ? null
        : widget.wrapControls
        ? TextButton.icon(
            key: const ValueKey('quick-tag-cloud-contributors'),
            onPressed: () => _showContributors(
              context,
              codexValue?.valueOrNull?.asMediaMeta() ?? selectedMeta,
            ),
            icon: const Icon(Icons.group_outlined, size: 20),
            label: Text(l10n.onlineGallery_codexContributors),
          )
        : IconButton(
            key: const ValueKey('quick-tag-cloud-contributors'),
            tooltip: l10n.onlineGallery_codexContributors,
            constraints: BoxConstraints.tightFor(
              width: context.interactionPolicy.minimumControlExtent,
              height: context.interactionPolicy.minimumControlExtent,
            ),
            visualDensity: context.interactionPolicy.prefersTouchPresentation
                ? VisualDensity.standard
                : VisualDensity.compact,
            onPressed: () => _showContributors(
              context,
              codexValue?.valueOrNull?.asMediaMeta() ?? selectedMeta,
            ),
            icon: const Icon(Icons.group_outlined, size: 20),
          );
    if (widget.wrapControls) {
      return SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scopeControl != null) scopeControl,
            if (scopeControl != null) const SizedBox(height: 8),
            for (var index = 0; index < sourceControls.length; index++) ...[
              sourceControls[index],
              if (index != sourceControls.length - 1) const SizedBox(height: 8),
            ],
            if (contributorsButton != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: contributorsButton),
            ],
          ],
        ),
      );
    }
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        filterControls,
        if (contributorsButton != null) ...[
          const SizedBox(width: 8),
          contributorsButton,
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        );
      },
    );
  }

  Future<void> _showCodexPicker(
    BuildContext context,
    QuickTagCloudCatalog catalog,
    QuickTagCloudGalleryQuery query,
    QuickTagCloudCodex? selectedCodex, {
    required bool allowNsfw,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await AdaptivePresenter.showPanel<String>(
      context: context,
      title: l10n.onlineGallery_codexSelect,
      initialChildSize: 0.82,
      dialogWidth: 680,
      builder: (panelContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            selected: query.codexId == 'all',
            leading: const Icon(Icons.library_books_outlined),
            title: Text(l10n.onlineGallery_codexAll),
            onTap: () => Navigator.pop(panelContext, 'all'),
          ),
          const Divider(),
          for (final meta in catalog.codexes)
            Builder(
              builder: (context) {
                final displayed = selectedCodex?.id == meta.id
                    ? selectedCodex!.asMediaMeta()
                    : meta;
                return ListTile(
                  selected: query.codexId == meta.id,
                  leading: Icon(
                    meta.nsfw ? Icons.lock_outline : Icons.menu_book_outlined,
                  ),
                  title: Text(displayed.title),
                  subtitle: Text(
                    '${displayed.author.isEmpty ? displayed.id : displayed.author}\n'
                    '${l10n.onlineGallery_codexEntryCount(displayed.entryCount, displayed.imagedCount)}\n'
                    '${displayed.version}',
                  ),
                  isThreeLine: true,
                  onTap: meta.nsfw && !allowNsfw
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.onlineGallery_codexBookLocked),
                            ),
                          );
                        }
                      : () => Navigator.pop(panelContext, meta.id),
                );
              },
            ),
        ],
      ),
    );
    if (!mounted || selected == null || selected == query.codexId) return;
    ref.read(quickTagCloudFilterProvider.notifier).selectCodex(selected);
    await widget.onFiltersChanged();
  }

  Future<void> _openCategoryPicker(
    String codexId,
    List<String> selectedPath,
  ) async {
    if (_openingCategoryPicker) return;
    setState(() => _openingCategoryPicker = true);
    try {
      final codex = await ref.read(quickTagCloudCodexProvider(codexId).future);
      if (!mounted) return;
      setState(() => _openingCategoryPicker = false);
      await _showCategoryPicker(context, codex, selectedPath);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load QuickTagCloud categories for $codexId',
        error,
        stackTrace,
        'QuickTagCloudToolbar',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.onlineGallery_loadFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted && _openingCategoryPicker) {
        setState(() => _openingCategoryPicker = false);
      }
    }
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    QuickTagCloudCodex codex,
    List<String> selectedPath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await AdaptivePresenter.showPanel<List<String>>(
      context: context,
      title: l10n.onlineGallery_codexCategory,
      initialChildSize: 0.82,
      dialogWidth: 580,
      builder: (panelContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            selected: selectedPath.isEmpty,
            leading: const Icon(Icons.apps),
            title: Text(l10n.onlineGallery_codexAllCategories),
            onTap: () => Navigator.pop(panelContext, <String>[]),
          ),
          ..._categoryTiles(panelContext, codex.tree, const [], selectedPath),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    ref.read(quickTagCloudFilterProvider.notifier).selectCategory(selected);
    await widget.onFiltersChanged();
  }

  List<Widget> _categoryTiles(
    BuildContext context,
    List<dynamic> nodes,
    List<String> parent,
    List<String> selected,
  ) {
    return [
      for (final rawNode in nodes.whereType<Map>())
        _categoryTile(
          context,
          Map<String, dynamic>.from(rawNode),
          parent,
          selected,
        ),
    ];
  }

  Widget _categoryTile(
    BuildContext context,
    Map<String, dynamic> node,
    List<String> parent,
    List<String> selected,
  ) {
    final name = node['name']?.toString() ?? '';
    final path = [...parent, name];
    final children = node['children'] is List
        ? List<dynamic>.from(node['children'] as List)
        : const <dynamic>[];
    final title = Row(
      children: [
        Expanded(child: Text(name)),
        if (node['count'] != null)
          SizedBox(
            width: 56,
            child: Text(
              node['count'].toString(),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
    if (children.isEmpty) {
      return ListTile(
        selected: _samePath(path, selected),
        contentPadding: EdgeInsets.only(
          left: 16.0 + parent.length * 14,
          right: 16,
        ),
        title: title,
        trailing: const SizedBox.square(dimension: 24),
        onTap: () => Navigator.pop(context, path),
      );
    }
    return ExpansionTile(
      initiallyExpanded:
          selected.length >= path.length &&
          _samePath(path, selected.take(path.length).toList()),
      tilePadding: EdgeInsets.only(left: 16.0 + parent.length * 14, right: 16),
      title: InkWell(
        onTap: () => Navigator.pop(context, path),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: title,
        ),
      ),
      children: _categoryTiles(context, children, path, selected),
    );
  }

  bool _containsCategoryPath(List<dynamic> nodes, List<String> path) {
    var level = nodes;
    for (final part in path) {
      Map<String, dynamic>? match;
      for (final raw in level.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(raw);
        if (candidate['name']?.toString() == part) {
          match = candidate;
          break;
        }
      }
      if (match == null) return false;
      level = match['children'] is List
          ? List<dynamic>.from(match['children'] as List)
          : const [];
    }
    return true;
  }

  bool _samePath(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> _showFilterDialog(
    BuildContext context,
    QuickTagCloudCodexMeta? meta,
    QuickTagCloudGalleryQuery query,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var mediaFilter = query.mediaFilter;
    var updateFilterId = query.updateFilterId;
    final allowNsfw = QuickTagCloudAccess.allowsNsfw(widget.selectedRatings);
    final allowR18g = QuickTagCloudAccess.allowsR18g(widget.selectedRatings);
    var changed = false;
    final apply = await AdaptivePresenter.showPanel<bool>(
      context: context,
      title: l10n.common_filter,
      initialChildSize: 0.72,
      dialogWidth: 560,
      builder: (panelContext, scrollController) => StatefulBuilder(
        builder: (panelContext, setPanelState) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onlineGallery_codexMediaFilter,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              RadioGroup<QuickTagCloudMediaFilter>(
                groupValue: mediaFilter,
                onChanged: (value) {
                  if (value == null) return;
                  changed = true;
                  setPanelState(() => mediaFilter = value);
                },
                child: Column(
                  children: [
                    for (final entry in [
                      (
                        QuickTagCloudMediaFilter.all,
                        l10n.onlineGallery_codexAllEntries,
                      ),
                      (
                        QuickTagCloudMediaFilter.withImages,
                        l10n.onlineGallery_codexWithImages,
                      ),
                      (
                        QuickTagCloudMediaFilter.withoutImages,
                        l10n.onlineGallery_codexWithoutImages,
                      ),
                    ])
                      RadioListTile<QuickTagCloudMediaFilter>(
                        value: entry.$1,
                        title: Text(entry.$2),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (meta != null && meta.updateFilters.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.onlineGallery_codexUpdateBatch,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: updateFilterId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(l10n.onlineGallery_codexAllEntries),
                    ),
                    for (final filter in meta.updateFilters)
                      DropdownMenuItem(
                        value: filter.id,
                        child: Text(filter.label),
                      ),
                  ],
                  onChanged: (value) {
                    changed = true;
                    setPanelState(() => updateFilterId = value ?? '');
                  },
                ),
              ],
              const SizedBox(height: 24),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 12,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(panelContext, false),
                    child: Text(l10n.common_cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(panelContext, true),
                    child: Text(l10n.common_apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || apply != true || !changed) return;
    final lockedSelection = !allowNsfw && meta?.nsfw == true;
    await ref
        .read(quickTagCloudFilterProvider.notifier)
        .applyFilters(
          codexId: lockedSelection ? 'all' : query.codexId,
          updateFilterId: lockedSelection ? '' : updateFilterId,
          scope: query.scope,
          mediaFilter: mediaFilter,
          allowNsfw: allowNsfw,
          allowR18g: allowR18g,
        );
    if (mounted) await widget.onFiltersChanged();
  }

  Future<void> _openCodexOrigin(
    BuildContext context,
    QuickTagCloudCodexMeta meta,
  ) async {
    final uri = Uri.https('novelai.quicktagcloud.com', '/', {'codex': meta.id});
    try {
      if (await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to open QuickTagCloud codex origin: $uri',
        error,
        stackTrace,
        'QuickTagCloudToolbar',
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cannotOpenUrl)),
      );
    }
  }

  Future<void> _showContributors(
    BuildContext context,
    QuickTagCloudCodexMeta meta,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await AdaptivePresenter.showPanel<void>(
      context: context,
      title: meta.title,
      initialChildSize: 0.78,
      dialogWidth: 580,
      builder: (panelContext, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(meta.author),
            subtitle: Text(
              '${l10n.onlineGallery_codexEntryCount(meta.entryCount, meta.imagedCount)}\n${meta.version}',
            ),
          ),
          if (meta.source.trim().isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dataset_outlined),
              title: Text(l10n.onlineGallery_codexDeclaredSource),
              subtitle: SelectableText(meta.source.trim()),
            ),
          const Divider(),
          for (final contributor in meta.contributors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(contributor.name),
              subtitle: contributor.role.isEmpty
                  ? null
                  : Text(contributor.role),
            ),
          for (final link in meta.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: Text(link.label.isEmpty ? link.url : link.label),
              subtitle: Text(link.url),
              onTap: () => launchUrl(Uri.parse(link.url)),
            ),
          const SizedBox(height: 16),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 12,
            overflowSpacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('quick-tag-cloud-open-origin'),
                onPressed: () => _openCodexOrigin(panelContext, meta),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(l10n.onlineGallery_codexOpenOrigin),
              ),
              TextButton(
                onPressed: () => Navigator.pop(panelContext),
                child: Text(l10n.common_close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScopeControl extends StatelessWidget {
  const _ScopeControl({
    required this.selected,
    required this.stacked,
    required this.onSelected,
  });

  final QuickTagCloudBrowseScope selected;
  final bool stacked;
  final Future<void> Function(QuickTagCloudBrowseScope scope) onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = [
      (
        QuickTagCloudBrowseScope.catalog,
        Icons.auto_stories_outlined,
        l10n.onlineGallery_codexBrowse,
      ),
      (
        QuickTagCloudBrowseScope.latest,
        Icons.new_releases_outlined,
        l10n.onlineGallery_codexLatest,
      ),
      (
        QuickTagCloudBrowseScope.recent,
        Icons.history,
        l10n.onlineGallery_codexRecent,
      ),
    ];
    if (!stacked) {
      return SegmentedButton<QuickTagCloudBrowseScope>(
        segments: [
          for (final entry in entries)
            ButtonSegment(
              value: entry.$1,
              icon: Icon(entry.$2, size: 16),
              label: Text(entry.$3),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelected(selection.single),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          TextButton.icon(
            onPressed: () => onSelected(entries[index].$1),
            icon: Icon(entries[index].$2, size: 18),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(entries[index].$3),
            ),
            style: TextButton.styleFrom(
              minimumSize: Size(
                double.infinity,
                context.interactionPolicy.minimumControlExtent,
              ),
              foregroundColor: selected == entries[index].$1
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: selected == entries[index].$1
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
            ),
          ),
          if (index != entries.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: Align(
        widthFactor: expanded ? null : 1,
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: expanded ? double.infinity : 220,
          ),
          child: Text(
            label,
            maxLines: expanded ? null : 1,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurfaceVariant,
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        minimumSize: Size(
          expanded ? double.infinity : 0,
          context.interactionPolicy.minimumControlExtent,
        ),
        visualDensity: context.interactionPolicy.prefersTouchPresentation
            ? VisualDensity.standard
            : VisualDensity.compact,
      ),
    );
  }
}
