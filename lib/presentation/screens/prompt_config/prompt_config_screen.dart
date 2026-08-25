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
    final presetState = ref.watch(randomPresetNotifierProvider);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final colors = Theme.of(context).colorScheme;

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
            backgroundColor: colors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _StudioHeader(
                    onGeneratePreview: () =>
                        setState(() => _showPreview = true),
                    onImportExport: _showImportExportActions,
                  ),
                  Expanded(
                    child: _buildBody(
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

  Widget _buildBody({
    required RandomPresetState presetState,
    required TagLibraryState libraryState,
  }) {
    if (presetState.isLoading || libraryState.isLoading) {
      return const _LibraryLoadingState();
    }
    final error = presetState.error ?? libraryState.error;
    if (error != null) {
      return _LibraryErrorState(
        message: error,
        onRetry: () =>
            ref.read(tagLibraryNotifierProvider.notifier).loadLibrary(),
      );
    }
    if (presetState.selectedPreset == null || libraryState.library == null) {
      return _EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: context.l10n.randomManager_selectPresetRequired,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1050) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RecipeWorkspace(
                  libraryState: libraryState,
                  query: _query,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onQueryChanged: _updateQuery,
                ),
              ),
              _InspectorPanel(
                width: constraints.maxWidth >= 1500 ? 420 : 370,
                showPreview: _showPreview,
                onGlobalSettings: _showGlobalSettings,
                onClosePreview: () => setState(() => _showPreview = false),
              ),
            ],
          );
        }

        return _CompactWorkspace(
          libraryState: libraryState,
          query: _query,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          onQueryChanged: _updateQuery,
          showPreview: _showPreview,
          onGlobalSettings: _showGlobalSettings,
          onClosePreview: () => setState(() => _showPreview = false),
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

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({
    required this.onGeneratePreview,
    required this.onImportExport,
  });

  final VoidCallback onGeneratePreview;
  final VoidCallback onImportExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      color: colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840;
          final title = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.randomManager_workspaceTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!compact)
                Text(
                  context.l10n.randomManager_workspaceSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 10),
                PresetSelectorBar(
                  onGeneratePreview: onGeneratePreview,
                  onImportExport: onImportExport,
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 220, child: title),
              const SizedBox(width: 24),
              Expanded(
                child: PresetSelectorBar(
                  onGeneratePreview: onGeneratePreview,
                  onImportExport: onImportExport,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecipeWorkspace extends StatelessWidget {
  const _RecipeWorkspace({
    required this.libraryState,
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
  });

  final TagLibraryState libraryState;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipeHeading(libraryState: libraryState),
          const SizedBox(height: 16),
          _LibrarySearchField(
            query: query,
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 18),
          Expanded(child: CategoryCardList(query: query)),
        ],
      ),
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.libraryState,
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    required this.showPreview,
    required this.onGlobalSettings,
    required this.onClosePreview,
  });

  final TagLibraryState libraryState;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final bool showPreview;
  final VoidCallback onGlobalSettings;
  final VoidCallback onClosePreview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _RecipeHeading(libraryState: libraryState),
        const SizedBox(height: 14),
        _LibrarySearchField(
          query: query,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 16),
        const AlgorithmConfigCard(),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onGlobalSettings,
            icon: const Icon(Icons.people_outline_rounded),
            label: Text(context.l10n.randomManager_globalPeopleSettings),
          ),
        ),
        if (showPreview) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 360,
            child: _PreviewSection(onClose: onClosePreview),
          ),
        ],
        const SizedBox(height: 22),
        CategoryCardList(query: query, shrinkWrap: true),
      ],
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.width,
    required this.showPreview,
    required this.onGlobalSettings,
    required this.onClosePreview,
  });

  final double width;
  final bool showPreview;
  final VoidCallback onGlobalSettings;
  final VoidCallback onClosePreview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      color: colors.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        children: [
          Text(
            context.l10n.randomManager_inspectorTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.randomManager_inspectorSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          const AlgorithmConfigCard(),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onGlobalSettings,
            icon: const Icon(Icons.people_outline_rounded),
            label: Text(context.l10n.randomManager_globalPeopleSettings),
          ),
          if (showPreview) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 390,
              child: _PreviewSection(onClose: onClosePreview),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeHeading extends StatelessWidget {
  const _RecipeHeading({required this.libraryState});

  final TagLibraryState libraryState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.randomManager_recipeTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.randomManager_recipeSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (libraryState.library case final library?)
          _LibraryStatusButton(library: library),
      ],
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      textField: true,
      label: context.l10n.randomManager_searchCategories,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: context.l10n.randomManager_searchCategories,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.common_clear,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: colors.surfaceContainerLow,
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
            borderSide: BorderSide(color: colors.primary, width: 1),
          ),
        ),
      ),
    );
  }
}

class _LibraryStatusButton extends StatelessWidget {
  const _LibraryStatusButton({required this.library});

  final TagLibrary library;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.randomManager_sourceDetails,
      child: InkWell(
        onTap: () => _showSourceDetails(context, library),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 17, color: colors.primary),
              const SizedBox(width: 7),
              Text(
                context.l10n.randomManager_verifiedOfflineLibrary,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 5),
              Text(
                library.totalTagCount.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                    library.sourceVersionDate?.toUtc().toIso8601String() ?? '—',
              ),
              _SourceDetailRow(
                label: context.l10n.randomManager_sourceLicense,
                value: library.sourceLicense ?? '—',
              ),
              _SourceDetailRow(
                label: context.l10n.randomManager_verifiedOfflineLibrary,
                value: context.l10n.randomManager_catalogCounts(
                  library.sourceCatalogTagCount ?? 0,
                  library.sourceCatalogAliasCount ?? 0,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    ),
  );
}

class _SourceDetailRow extends StatelessWidget {
  const _SourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: PreviewGeneratorPanel()),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton(
            tooltip: context.l10n.common_close,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}

class _LibraryLoadingState extends StatelessWidget {
  const _LibraryLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.common_loading,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LibraryErrorState extends StatelessWidget {
  const _LibraryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.error_outline_rounded,
      title: context.l10n.randomManager_libraryUnavailable,
      message: message,
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.l10n.common_retry),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
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
