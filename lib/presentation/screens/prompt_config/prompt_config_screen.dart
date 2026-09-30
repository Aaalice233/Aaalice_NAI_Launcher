import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_pinned_header_sliver.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/compact_control_metrics.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/random_preset_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../themes/core/input_surface_style.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/horizontal_segmented_control.dart';
import '../../widgets/prompt/diy/dialogs/preset_import_dialog.dart';
import '../../widgets/prompt/global_settings_dialog.dart';
import '../../widgets/prompt/random_manager/algorithm_config_card.dart';
import '../../widgets/prompt/random_manager/category_card_list.dart';
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
  final _previewController = PreviewGeneratorController();
  // 宽屏与紧凑排布互换时保留标题栏与类别列表（搜索焦点、展开状态、滚动位置）
  final _headerKey = GlobalKey();
  final _categoryListKey = GlobalKey();
  static const _recipeSection = 0;

  String _query = '';
  int _compactSection = _recipeSection;

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
            onInvoke: (_) => _focusSearch(),
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
              child: LayoutBuilder(
                builder: (context, constraints) => _buildWorkspace(
                  maxWidth: constraints.maxWidth,
                  unavailableState: _buildUnavailableState(
                    presetState: presetState,
                    libraryState: libraryState,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace({required double maxWidth, Widget? unavailableState}) {
    final header = KeyedSubtree(
      key: _headerKey,
      child: _StudioHeader(onImportExport: _showImportExportActions),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (useExpandedPromptConfigLayout(maxWidth, textScale)) {
      return Column(
        children: [
          header,
          Expanded(
            child: unavailableState != null
                ? _SectionScrollView(
                    slivers: [_UnavailableStateSliver(child: unavailableState)],
                  )
                : _ExpandedWorkspace(
                    categoryList: _buildCategoryList(showShortcutHint: true),
                    inspectorWidth: maxWidth >= 1500 ? 420 : 370,
                    onGlobalSettings: _showGlobalSettings,
                    previewController: _previewController,
                  ),
          ),
        ],
      );
    }

    if (unavailableState != null) {
      return _SectionScrollView(
        slivers: [
          _WorkspaceChromeSliver(child: header),
          _UnavailableStateSliver(child: unavailableState),
        ],
      );
    }
    return _CompactWorkspace(
      header: header,
      recipeBuilder: (leadingSlivers) => _buildCategoryList(
        showShortcutHint: false,
        leadingSlivers: leadingSlivers,
      ),
      onGlobalSettings: _showGlobalSettings,
      previewController: _previewController,
      selectedSection: _compactSection,
      onSectionSelected: (value) => setState(() => _compactSection = value),
    );
  }

  Widget? _buildUnavailableState({
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
    return null;
  }

  Widget _buildCategoryList({
    required bool showShortcutHint,
    List<Widget> leadingSlivers = const [],
  }) {
    return CategoryCardList(
      key: _categoryListKey,
      query: _query,
      leadingSlivers: leadingSlivers,
      overviewHeader: _RecipeOverviewHeader(
        query: _query,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onQueryChanged: _updateQuery,
        showShortcutHint: showShortcutHint,
      ),
    );
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  // 紧凑排布下搜索框只在配方分区，其他分区里它不可聚焦，先切回配方分区再聚焦
  void _focusSearch() {
    if (_searchFocusNode.canRequestFocus) {
      _searchFocusNode.requestFocus();
      return;
    }
    setState(() => _compactSection = _recipeSection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
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
        shrinkWrap: true,
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
      constraints: const BoxConstraints(minHeight: 56),
      color: sectionSurfaceColor(colors),
      padding: EdgeInsets.symmetric(
        horizontal: textScale > 1.5 ? 12 : 20,
        vertical: 8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840 || textScale > 1.5;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, size: 22, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                context.l10n.randomManager_workspaceTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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
              title,
              const SizedBox(width: 12),
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

class _ExpandedWorkspace extends StatelessWidget {
  const _ExpandedWorkspace({
    required this.categoryList,
    required this.inspectorWidth,
    required this.onGlobalSettings,
    required this.previewController,
  });

  final Widget categoryList;
  final double inspectorWidth;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: categoryList),
          const SizedBox(width: 16),
          _InspectorPanel(
            width: inspectorWidth,
            onGlobalSettings: onGlobalSettings,
            previewController: previewController,
          ),
        ],
      ),
    );
  }
}

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    required this.header,
    required this.recipeBuilder,
    required this.onGlobalSettings,
    required this.previewController,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final Widget header;
  final Widget Function(List<Widget> leadingSlivers) recipeBuilder;
  final VoidCallback onGlobalSettings;
  final PreviewGeneratorController previewController;
  final int selectedSection;
  final ValueChanged<int> onSectionSelected;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  // 标题栏与分区切换只放在当前分区的滚动视图里，换分区时整体迁移并保留焦点
  final _chromeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final chrome = _WorkspaceChromeSliver(
      child: KeyedSubtree(
        key: _chromeKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.header,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: HorizontalSegmentedControl(
                child: _SectionSwitcher(
                  selectedSection: widget.selectedSection,
                  onSectionSelected: widget.onSectionSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    List<Widget> leadingFor(int section) =>
        section == widget.selectedSection ? [chrome] : const [];

    return IndexedStack(
      index: widget.selectedSection,
      children: [
        widget.recipeBuilder(leadingFor(0)),
        _SectionScrollView(
          slivers: [
            ...leadingFor(1),
            _SectionBodySliver(
              child: PreviewGeneratorPanel(
                controller: widget.previewController,
                inline: true,
              ),
            ),
          ],
        ),
        _SectionScrollView(
          slivers: [
            ...leadingFor(2),
            _SectionBodySliver(
              child: AlgorithmConfigCard(
                onGlobalSettings: widget.onGlobalSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionSwitcher extends StatelessWidget {
  const _SectionSwitcher({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final int selectedSection;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
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
      onSelectionChanged: (selection) => onSectionSelected(selection.first),
      // 触屏保留 48 高的命中区，精确指针下维持紧凑
      style: ButtonStyle(
        visualDensity: CompactControlMetrics.forPolicy(
          context.interactionPolicy,
        ).density,
      ),
    );
  }
}

/// 页面顶部区域：高度允许时固定在滚动视图顶端，否则随内容一起滚动
class _WorkspaceChromeSliver extends StatelessWidget {
  const _WorkspaceChromeSliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdaptivePinnedHeaderSliver(
      // 固定时内容从下方滚过，用画布色遮住间距处的内容
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
    );
  }
}

class _SectionScrollView extends StatelessWidget {
  const _SectionScrollView({required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );
  }
}

class _SectionBodySliver extends StatelessWidget {
  const _SectionBodySliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class _UnavailableStateSliver extends StatelessWidget {
  const _UnavailableStateSliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(hasScrollBody: false, child: child);
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
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    this.showShortcutHint = true,
  });

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
        const _RecipeHeading(),
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

class _RecipeHeading extends StatelessWidget {
  const _RecipeHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
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
