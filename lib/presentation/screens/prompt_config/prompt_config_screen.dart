import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/official_wordlist.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../../data/models/prompt/tag_library.dart';
import '../../../data/services/wordlist_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/random_preset_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../themes/core/input_surface_style.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/prompt/diy/dialogs/preset_import_dialog.dart';
import '../../widgets/prompt/global_settings_dialog.dart';
import '../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../widgets/prompt/random_manager/category_card_list.dart';
import '../../widgets/prompt/random_manager/preset_selector_bar.dart';
import '../../widgets/prompt/random_manager/preview_generator_panel.dart';
import 'prompt_source_details_dialog.dart';

export 'prompt_source_details_dialog.dart' show PromptSourceDetailsDialog;

class PromptConfigScreen extends ConsumerStatefulWidget {
  const PromptConfigScreen({super.key});

  @override
  ConsumerState<PromptConfigScreen> createState() => _PromptConfigScreenState();
}

class _PromptConfigScreenState extends ConsumerState<PromptConfigScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _previewController = PreviewGeneratorController();
  String _query = '';
  int _compactSection = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _previewController.dispose();
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
            onInvoke: (_) => _previewController.generate(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: colors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _StudioHeader(onImportExport: _showImportExportActions),
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
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (useExpandedPromptConfigLayout(constraints.maxWidth, textScale)) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                const SizedBox(width: 16),
                _InspectorPanel(
                  width: constraints.maxWidth >= 1500 ? 420 : 370,
                  onGlobalSettings: _showGlobalSettings,
                  previewController: _previewController,
                ),
              ],
            ),
          );
        }

        return _CompactWorkspace(
          libraryState: libraryState,
          query: _query,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          onQueryChanged: _updateQuery,
          onGlobalSettings: _showGlobalSettings,
          previewController: _previewController,
          selectedSection: _compactSection,
          onSectionSelected: (value) => setState(() => _compactSection = value),
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
    final action = await AdaptivePresenter.showPanel<String>(
      context: context,
      title: context.l10n.randomManager_importExport,
      initialChildSize: 0.34,
      minChildSize: 0.28,
      maxChildSize: 0.62,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _ImportExportActionCard(
            icon: Icons.download_rounded,
            title: Text(context.l10n.randomManager_importPreset),
            subtitle: Text(context.l10n.randomManager_importPresetSubtitle),
            onTap: () => Navigator.pop(context, 'import'),
          ),
          const SizedBox(height: 10),
          _ImportExportActionCard(
            enabled: selectedPreset != null,
            icon: Icons.upload_rounded,
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

class _ImportExportActionCard extends StatelessWidget {
  const _ImportExportActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: sectionSurfaceColor(colors),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: controlSurfaceColor(colors),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.titleSmall,
                        child: title,
                      ),
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        child: subtitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.onImportExport});

  final VoidCallback onImportExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      color: sectionSurfaceColor(colors),
      padding: EdgeInsets.symmetric(
        horizontal: textScale > 1.5 ? 12 : 20,
        vertical: 12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840 || textScale > 1.5;
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
            return PresetSelectorBar(
              onImportExport: onImportExport,
              showWorkspaceHeading: true,
            );
          }
          return Row(
            children: [
              SizedBox(width: 220, child: title),
              const SizedBox(width: 24),
              Expanded(
                child: PresetSelectorBar(onImportExport: onImportExport),
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
    return CategoryCardList(
      query: query,
      overviewHeader: _RecipeOverviewHeader(
        libraryState: libraryState,
        query: query,
        searchController: searchController,
        searchFocusNode: searchFocusNode,
        onQueryChanged: onQueryChanged,
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
    required this.onGlobalSettings,
    required this.previewController,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final TagLibraryState libraryState;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;
  final int selectedSection;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CategoryCardList(
        query: query,
        overviewHeader: _RecipeOverviewHeader(
          libraryState: libraryState,
          query: query,
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          onQueryChanged: onQueryChanged,
          showShortcutHint: false,
        ),
      ),
      ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          PreviewGeneratorPanel(controller: previewController, inline: true),
        ],
      ),
      ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [AlgorithmConfigCard(onGlobalSettings: onGlobalSettings)],
      ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SegmentedButton<int>(
            key: const ValueKey('random-manager-compact-sections'),
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.layers_outlined, size: 17),
                label: Text(context.l10n.randomManager_recipeTitle),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.preview_outlined, size: 17),
                label: Text(context.l10n.randomManager_previewGeneration),
              ),
              ButtonSegment(
                value: 2,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(context.l10n.randomManager_inspectorTitle),
              ),
            ],
            selected: {selectedSection},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                onSectionSelected(selection.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -2, vertical: -1),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: IndexedStack(index: selectedSection, children: pages),
        ),
      ],
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.width,
    required this.onGlobalSettings,
    required this.previewController,
  });

  final double width;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final setup = <Widget>[
            AlgorithmConfigCard(onGlobalSettings: onGlobalSettings),
            const SizedBox(height: 16),
          ];
          if (constraints.maxHeight < 620) {
            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                ...setup,
                PreviewGeneratorPanel(
                  controller: previewController,
                  inline: true,
                ),
              ],
            );
          }
          return Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...setup,
                Expanded(
                  child: PreviewGeneratorPanel(controller: previewController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecipeOverviewHeader extends StatelessWidget {
  const _RecipeOverviewHeader({
    required this.libraryState,
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    this.showShortcutHint = true,
  });

  final TagLibraryState libraryState;
  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecipeHeading(libraryState: libraryState),
        const SizedBox(height: 14),
        _LibrarySearchField(
          query: query,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onQueryChanged,
          showShortcutHint: showShortcutHint,
        ),
      ],
    );
  }
}

class _RecipeHeading extends ConsumerWidget {
  const _RecipeHeading({required this.libraryState});

  final TagLibraryState libraryState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mode = ref.watch(randomModeNotifierProvider);
    final model = ref.watch(generationParamsNotifierProvider).model;
    final profile = ModelCapabilityRegistry.tryOf(model)?.randomPromptProfile;
    final officialData = mode == RandomGenerationMode.custom
        ? null
        : ref.watch(officialWordlistDataProvider).valueOrNull;
    final heading = Column(
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
    );
    final library = libraryState.library;
    final status = library == null
        ? null
        : _LibraryStatusButton(
            library: library,
            mode: mode,
            profile: profile,
            officialData: officialData,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 600 || textScale > 1.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (status != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: status),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            if (status != null) status,
          ],
        );
      },
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.showShortcutHint = true,
  });

  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searchLabel = showShortcutHint
        ? context.l10n.randomManager_searchCategories
        : context.l10n.randomManager_searchCategoriesCompact;
    return Semantics(
      textField: true,
      label: searchLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: searchLabel,
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
          fillColor: inputSurfaceFillColor(colors),
          border: inputSurfaceBorder(colors, BorderRadius.circular(10)),
          enabledBorder: inputSurfaceBorder(colors, BorderRadius.circular(10)),
          focusedBorder: inputSurfaceBorder(
            colors,
            BorderRadius.circular(10),
            focused: true,
          ),
        ),
      ),
    );
  }
}

class _LibraryStatusButton extends StatelessWidget {
  const _LibraryStatusButton({
    required this.library,
    required this.mode,
    required this.profile,
    required this.officialData,
  });

  final TagLibrary library;
  final RandomGenerationMode mode;
  final RandomPromptProfile? profile;
  final OfficialWordlistData? officialData;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final includesOfficial = mode != RandomGenerationMode.custom;
    final unsupported = includesOfficial && profile == null;
    final supportedProfile = profile ?? RandomPromptProfile.characterPrompts;
    final officialCount = unsupported
        ? null
        : randomPromptProfileCount(supportedProfile);
    final label = unsupported
        ? context.l10n.randomMode_unsupportedModel
        : switch (mode) {
            RandomGenerationMode.naiOfficial =>
              context.l10n.randomManager_sourceOfficial(
                randomPromptProfileName(context, supportedProfile),
              ),
            RandomGenerationMode.custom =>
              context.l10n.randomManager_sourceCatalog,
            RandomGenerationMode.hybrid =>
              context.l10n.randomManager_sourceHybrid(
                randomPromptProfileName(context, supportedProfile),
              ),
          };
    final count = unsupported
        ? null
        : switch (mode) {
            RandomGenerationMode.naiOfficial => '$officialCount',
            RandomGenerationMode.custom => '${library.totalTagCount}',
            RandomGenerationMode.hybrid =>
              '$officialCount + ${library.totalTagCount}',
          };
    return Tooltip(
      message: unsupported
          ? context.l10n.randomMode_unsupportedModelHint
          : context.l10n.randomManager_sourceDetails,
      child: InkWell(
        key: const ValueKey('random-manager-source-status'),
        onTap: unsupported
            ? null
            : () => _showSourceDetails(
                context,
                library,
                mode: mode,
                profile: supportedProfile,
                officialData: officialData,
              ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unsupported
                    ? Icons.error_outline_rounded
                    : Icons.verified_rounded,
                size: 17,
                color: unsupported ? colors.error : colors.primary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  count,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showSourceDetails(
  BuildContext context,
  TagLibrary library, {
  required RandomGenerationMode mode,
  required RandomPromptProfile profile,
  required OfficialWordlistData? officialData,
}) => PromptSourceDetailsDialog.show(
  context,
  library: library,
  mode: mode,
  profile: profile,
  officialData: officialData,
);

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

bool useExpandedPromptConfigLayout(double availableWidth, double textScale) {
  return availableWidth >= 1050 && textScale <= 1.5;
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _PreviewIntent extends Intent {
  const _PreviewIntent();
}
