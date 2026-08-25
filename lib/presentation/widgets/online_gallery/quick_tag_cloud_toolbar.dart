import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../../data/services/online_gallery/quick_tag_cloud_access.dart';
import '../../../l10n/app_localizations.dart';
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

    final filterControls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!widget.favoritesMode)
          SegmentedButton<QuickTagCloudBrowseScope>(
            segments: [
              ButtonSegment(
                value: QuickTagCloudBrowseScope.catalog,
                icon: const Icon(Icons.auto_stories_outlined, size: 16),
                label: Text(l10n.onlineGallery_codexBrowse),
              ),
              ButtonSegment(
                value: QuickTagCloudBrowseScope.latest,
                icon: const Icon(Icons.new_releases_outlined, size: 16),
                label: Text(l10n.onlineGallery_codexLatest),
              ),
              ButtonSegment(
                value: QuickTagCloudBrowseScope.recent,
                icon: const Icon(Icons.history, size: 16),
                label: Text(l10n.onlineGallery_codexRecent),
              ),
            ],
            selected: {query.scope},
            showSelectedIcon: false,
            onSelectionChanged: (selection) async {
              ref
                  .read(quickTagCloudFilterProvider.notifier)
                  .selectScope(selection.single);
              await widget.onFiltersChanged();
            },
          ),
        _ToolbarButton(
          icon: Icons.menu_book_outlined,
          label: selectedMeta?.title ?? l10n.onlineGallery_codexAll,
          loading: catalogValue.isLoading,
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
          loading: codexValue?.isLoading ?? false,
          onPressed: codexValue?.valueOrNull == null
              ? null
              : () => _showCategoryPicker(
                  context,
                  codexValue!.value!,
                  query.categoryPath,
                ),
        ),
        _ToolbarButton(
          icon: Icons.tune,
          label: l10n.common_filter,
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
      ],
    );

    final contributorsButton = selectedMeta == null
        ? null
        : IconButton(
            key: const ValueKey('quick-tag-cloud-contributors'),
            tooltip: l10n.onlineGallery_codexContributors,
            visualDensity: VisualDensity.compact,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            filterControls,
            if (contributorsButton != null) contributorsButton,
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
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.onlineGallery_codexSelect),
        content: SizedBox(
          width: 620,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  selected: query.codexId == 'all',
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(l10n.onlineGallery_codexAll),
                  onTap: () => Navigator.pop(dialogContext, 'all'),
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
                          meta.nsfw
                              ? Icons.lock_outline
                              : Icons.menu_book_outlined,
                        ),
                        title: Text(displayed.title),
                        subtitle: Text(
                          '${displayed.author.isEmpty ? displayed.id : displayed.author}\n'
                          '${l10n.onlineGallery_codexEntryCount(displayed.entryCount, displayed.imagedCount)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(displayed.version),
                        onTap: meta.nsfw && !allowNsfw
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.onlineGallery_codexBookLocked,
                                    ),
                                  ),
                                );
                              }
                            : () => Navigator.pop(dialogContext, meta.id),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null || selected == query.codexId) return;
    ref.read(quickTagCloudFilterProvider.notifier).selectCodex(selected);
    await widget.onFiltersChanged();
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    QuickTagCloudCodex codex,
    List<String> selectedPath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.onlineGallery_codexCategory),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  selected: selectedPath.isEmpty,
                  leading: const Icon(Icons.apps),
                  title: Text(l10n.onlineGallery_codexAllCategories),
                  onTap: () => Navigator.pop(dialogContext, <String>[]),
                ),
                ..._categoryTiles(
                  dialogContext,
                  codex.tree,
                  const [],
                  selectedPath,
                ),
              ],
            ),
          ),
        ),
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
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.common_filter),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onlineGallery_codexMediaFilter,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<QuickTagCloudMediaFilter>(
                    segments: [
                      ButtonSegment(
                        value: QuickTagCloudMediaFilter.all,
                        label: Text(l10n.onlineGallery_codexAllEntries),
                      ),
                      ButtonSegment(
                        value: QuickTagCloudMediaFilter.withImages,
                        label: Text(l10n.onlineGallery_codexWithImages),
                      ),
                      ButtonSegment(
                        value: QuickTagCloudMediaFilter.withoutImages,
                        label: Text(l10n.onlineGallery_codexWithoutImages),
                      ),
                    ],
                    selected: {mediaFilter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      changed = true;
                      setDialogState(() => mediaFilter = selection.single);
                    },
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
                        setDialogState(() => updateFilterId = value ?? '');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.common_apply),
            ),
          ],
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

  Future<void> _showContributors(
    BuildContext context,
    QuickTagCloudCodexMeta meta,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(meta.title),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(meta.author),
                  subtitle: Text(
                    l10n.onlineGallery_codexEntryCount(
                      meta.entryCount,
                      meta.imagedCount,
                    ),
                  ),
                  trailing: Text(meta.version),
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.common_close),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
