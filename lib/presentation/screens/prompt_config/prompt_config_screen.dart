import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/tag_library.dart';
import '../../providers/random_preset_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/prompt/diy/dialogs/preset_import_dialog.dart';
import '../../widgets/prompt/global_settings_dialog.dart';
import '../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../widgets/prompt/random_manager/category_card.dart';
import '../../widgets/prompt/random_manager/preset_selector_bar.dart';
import '../../widgets/prompt/random_manager/preview_generator_panel.dart';

class PromptConfigScreen extends ConsumerStatefulWidget {
  const PromptConfigScreen({super.key});

  @override
  ConsumerState<PromptConfigScreen> createState() => _PromptConfigScreenState();
}

class _PromptConfigScreenState extends ConsumerState<PromptConfigScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showPreview = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final libraryState = ref.watch(tagLibraryNotifierProvider);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _PreviewIntent(),
        SingleActivator(LogicalKeyboardKey.enter, meta: true): _PreviewIntent(),
      },
      child: Actions(
        actions: {
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) => _searchFocusNode.requestFocus(),
          ),
          _PreviewIntent: CallbackAction<_PreviewIntent>(
            onInvoke: (_) => setState(() => _showPreview = true),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colorScheme.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _Toolbar(
                    onGeneratePreview: () {
                      setState(() => _showPreview = true);
                    },
                    onImportExport: _showImportExportActions,
                  ),
                  Expanded(
                    child: _buildContent(
                      presetState: presetState,
                      libraryState: libraryState,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required RandomPresetState presetState,
    required TagLibraryState libraryState,
  }) {
    if (presetState.isLoading || libraryState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = presetState.error ?? libraryState.error;
    if (error != null) {
      return _LibraryErrorState(
        message: error,
        onRetry: () async {
          await ref.read(tagLibraryNotifierProvider.notifier).loadLibrary();
        },
      );
    }
    if (presetState.selectedPreset == null) {
      return _EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: context.l10n.randomManager_selectPresetRequired,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final horizontalPadding = constraints.maxWidth >= 1500 ? 28.0 : 16.0;
        if (wide) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 1500 ? 400 : 360,
                  child: _SettingsPanel(
                    showPreview: _showPreview,
                    onGlobalSettings: _showGlobalSettings,
                    onClosePreview: () {
                      setState(() => _showPreview = false);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _LibraryPanel(
                    libraryState: libraryState,
                    query: _query,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onQueryChanged: _updateQuery,
                    expandList: true,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            20,
          ),
          children: [
            _LibrarySummary(libraryState: libraryState),
            const SizedBox(height: 12),
            _SettingsPanel(
              showPreview: _showPreview,
              onGlobalSettings: _showGlobalSettings,
              onClosePreview: () {
                setState(() => _showPreview = false);
              },
              embedded: true,
            ),
            const SizedBox(height: 16),
            _LibraryPanel(
              libraryState: libraryState,
              query: _query,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onQueryChanged: _updateQuery,
              expandList: false,
              showSummary: false,
            ),
          ],
        );
      },
    );
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  Future<void> _showImportExportActions() async {
    final selectedPreset = ref
        .read(randomPresetNotifierProvider)
        .selectedPreset;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(context.l10n.randomManager_importPreset),
              subtitle: Text(context.l10n.randomManager_importPresetSubtitle),
              onTap: () => Navigator.pop(context, 'import'),
            ),
            ListTile(
              enabled: selectedPreset != null,
              leading: const Icon(Icons.upload_rounded),
              title: Text(context.l10n.randomManager_exportCurrentPreset),
              subtitle: Text(
                selectedPreset?.name ??
                    context.l10n.randomManager_noPresetSelected,
              ),
              onTap: selectedPreset == null
                  ? null
                  : () => Navigator.pop(context, 'export'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'import') {
      final imported = await PresetImportDialog.showImport(context);
      if (!mounted || imported == null) return;
      final notifier = ref.read(randomPresetNotifierProvider.notifier);
      await notifier.addPreset(imported);
      await notifier.selectPreset(imported.id);
      if (mounted) {
        AppToast.success(
          context,
          context.l10n.randomManager_presetImported(imported.name),
        );
      }
      return;
    }

    if (selectedPreset == null) {
      AppToast.warning(context, context.l10n.randomManager_selectPresetFirst);
      return;
    }
    await PresetImportDialog.showExport(context, selectedPreset);
  }

  Future<void> _showGlobalSettings() async {
    final selectedPreset = ref
        .read(randomPresetNotifierProvider)
        .selectedPreset;
    if (selectedPreset == null) {
      AppToast.warning(context, context.l10n.randomManager_selectPresetFirst);
      return;
    }
    if (selectedPreset.isDefault) {
      AppToast.warning(
        context,
        context.l10n.randomManager_defaultPresetReadonly,
      );
      return;
    }
    await GlobalSettingsDialog.show(context);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onGeneratePreview,
    required this.onImportExport,
  });

  final VoidCallback onGeneratePreview;
  final VoidCallback onImportExport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: PresetSelectorBar(
          onGeneratePreview: onGeneratePreview,
          onImportExport: onImportExport,
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.showPreview,
    required this.onGlobalSettings,
    required this.onClosePreview,
    this.embedded = false,
  });

  final bool showPreview;
  final VoidCallback onGlobalSettings;
  final VoidCallback onClosePreview;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AlgorithmConfigCard(),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onGlobalSettings,
            icon: const Icon(Icons.tune_rounded),
            label: Text(context.l10n.randomManager_globalPeopleSettings),
          ),
        ),
        if (showPreview) ...[
          const SizedBox(height: 12),
          _PreviewSection(onClose: onClosePreview),
        ],
      ],
    );
    return embedded ? content : SingleChildScrollView(child: content);
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({
    required this.libraryState,
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    required this.expandList,
    this.showSummary = true,
  });

  final TagLibraryState libraryState;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final bool expandList;
  final bool showSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expandList ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (showSummary) ...[
              _LibrarySummary(libraryState: libraryState),
              const SizedBox(height: 12),
            ],
            Semantics(
              textField: true,
              label: context.l10n.randomManager_searchCategories,
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.randomManager_searchCategories,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.common_clear,
                          onPressed: () {
                            searchController.clear();
                            onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (expandList)
              Expanded(child: CategoryCardList(query: query))
            else
              CategoryCardList(query: query, shrinkWrap: true),
          ],
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary({required this.libraryState});

  final TagLibraryState libraryState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = libraryState.library!;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.offline_bolt_rounded,
            size: 19,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.randomManager_verifiedOfflineLibrary,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.randomManager_libraryVersion(
                  library.dataVersion ?? library.version.toString(),
                  library.totalTagCount.toString(),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showSourceDetails(context, library),
          tooltip: context.l10n.randomManager_sourceDetails,
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    );
  }

  Future<void> _showSourceDetails(BuildContext context, TagLibrary library) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.randomManager_sourceDetails),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SourceDetailRow(
                  label: context.l10n.randomManager_sourceUrl,
                  value: library.sourceUrl ?? '—',
                ),
                _SourceDetailRow(
                  label: context.l10n.randomManager_sourceCommit,
                  value: library.sourceCommit ?? '—',
                ),
                _SourceDetailRow(
                  label: context.l10n.randomManager_sourceDate,
                  value:
                      library.sourceVersionDate?.toUtc().toIso8601String() ??
                      '—',
                ),
                _SourceDetailRow(
                  label: context.l10n.randomManager_sourceLicense,
                  value: library.sourceLicense ?? '—',
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.randomManager_catalogCounts(
                    (library.sourceCatalogTagCount ?? 0).toString(),
                    (library.sourceCatalogAliasCount ?? 0).toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }
}

class _SourceDetailRow extends StatelessWidget {
  const _SourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label\n$value'),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.randomManager_preview,
      child: SizedBox(
        height: 380,
        child: Stack(
          children: [
            const Positioned.fill(child: PreviewGeneratorPanel()),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: context.l10n.randomManager_closePreview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryErrorState extends StatelessWidget {
  const _LibraryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.randomManager_libraryUnavailable,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.common_retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title),
        ],
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _PreviewIntent extends Intent {
  const _PreviewIntent();
}
