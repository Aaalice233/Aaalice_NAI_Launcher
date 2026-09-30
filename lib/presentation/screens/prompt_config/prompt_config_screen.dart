import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/random_preset_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/prompt/diy/dialogs/preset_import_dialog.dart';
import '../../widgets/prompt/global_settings_dialog.dart';
import '../../widgets/prompt/random_manager/category_card_list.dart';
import '../../widgets/prompt/random_manager/preview_generator_panel.dart';
import 'widgets/preset_transfer_chooser.dart';
import 'widgets/prompt_config_compact_workspace.dart';
import 'widgets/prompt_config_expanded_workspace.dart';
import 'widgets/prompt_config_recipe_header.dart';
import 'widgets/prompt_config_studio_header.dart';
import 'widgets/prompt_config_unavailable_states.dart';
import 'widgets/prompt_config_workspace_slivers.dart';

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
      child: PromptConfigStudioHeader(onImportExport: _showImportExportActions),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (useExpandedPromptConfigLayout(maxWidth, textScale)) {
      return Column(
        children: [
          header,
          Expanded(
            child: unavailableState != null
                ? PromptConfigSectionScrollView(
                    slivers: [
                      PromptConfigUnavailableSliver(child: unavailableState),
                    ],
                  )
                : PromptConfigExpandedWorkspace(
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
      return PromptConfigSectionScrollView(
        slivers: [
          PromptConfigChromeSliver(child: header),
          PromptConfigUnavailableSliver(child: unavailableState),
        ],
      );
    }
    return PromptConfigCompactWorkspace(
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
      return const PromptConfigLoadingState();
    }
    final error = presetState.error ?? libraryState.error;
    if (error != null) {
      return PromptConfigErrorState(
        message: error,
        onRetry: () =>
            ref.read(tagLibraryNotifierProvider.notifier).loadLibrary(),
      );
    }
    if (presetState.selectedPreset == null || libraryState.library == null) {
      return PromptConfigEmptyState(
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
      overviewHeader: PromptConfigRecipeHeader(
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
    final action = await showPresetTransferChooser(
      context,
      selectedPresetName: selectedPreset?.name,
    );
    if (!mounted || action == null) return;

    if (action == PresetTransferAction.importPreset) {
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

bool useExpandedPromptConfigLayout(double availableWidth, double textScale) {
  return availableWidth >= 1050 && textScale <= 1.5;
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _PreviewIntent extends Intent {
  const _PreviewIntent();
}
