import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/autocomplete/autocomplete_settings.dart'
    as completion_settings;
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_regex_rules_provider.dart';
import '../../../widgets/character/character_prompt_button.dart';
import '../../../widgets/prompt/fixed_tags_button.dart';
import '../../../widgets/prompt/quality_tags_selector.dart';
import '../../../widgets/prompt/regex_rules_dialog.dart';
import '../../../widgets/prompt/toolbar/toolbar.dart';
import '../../../widgets/prompt/uc_preset_selector.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';
import 'prompt_type_switch.dart';

class PromptInputToolbar extends ConsumerWidget {
  const PromptInputToolbar({
    super.key,
    required this.controller,
    required this.commands,
    required this.viewData,
    this.mobileFullscreen = false,
    this.mobileEditor,
    this.mobileFooter,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;
  final bool mobileFullscreen;
  final Widget? mobileEditor;
  final Widget? mobileFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    if (mobileFullscreen) {
      return _MobileFullscreenToolbar(
        controller: controller,
        commands: commands,
        viewData: viewData,
        model: model,
        showRandomTools: showRandomTools,
        settings: () => _showSettingsMenu(context, ref),
        editor: mobileEditor!,
        footer: mobileFooter!,
      );
    }

    final typeSwitch = PromptTypeSwitch(
      controller: controller,
      commands: commands,
    );
    final toolbar = _editorToolbar(
      context,
      showRandom: showRandomTools,
      settings: () => _showSettingsMenu(context, ref),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (viewData.autoGrow && constraints.maxWidth >= 440) {
          return SizedBox(
            key: const ValueKey('generation_prompt_compact_single_row'),
            height: 48,
            child: Row(
              children: [
                PromptTypeSwitch(
                  controller: controller,
                  commands: commands,
                  compact: true,
                ),
                const SizedBox(width: 4),
                const FixedTagsButton(compact: true, iconOnly: true),
                const SizedBox(width: 4),
                QualityTagsSelector(
                  model: model,
                  compact: true,
                  iconOnly: true,
                ),
                const SizedBox(width: 4),
                UcPresetSelector(model: model, compact: true, iconOnly: true),
                const SizedBox(width: 4),
                const CharacterPromptButton(compact: true, iconOnly: true),
                const Spacer(),
                toolbar,
              ],
            ),
          );
        }
        if (constraints.maxWidth < 600) {
          final primary = _editorToolbar(
            context,
            showRandom: false,
            settings: () => _showSettingsMenu(context, ref),
          );
          final random = _randomToolbar(showRandomTools);
          final typeSwitch = PromptTypeSwitch(
            controller: controller,
            commands: commands,
            expand: true,
            compact: true,
          );
          final stackPrimary =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          return Column(
            key: const ValueKey('generation_prompt_mobile_toolbar'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stackPrimary) ...[
                typeSwitch,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: primary),
              ] else
                Row(
                  key: const ValueKey('generation_prompt_mobile_primary_row'),
                  children: [
                    Expanded(child: typeSwitch),
                    const SizedBox(width: 6),
                    primary,
                  ],
                ),
              const SizedBox(height: 4),
              Wrap(
                key: const ValueKey('generation_prompt_mobile_secondary_row'),
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showRandomTools)
                    _MobilePromptToolbarAction(
                      actionKey: const ValueKey(
                        'generation_prompt_mobile_random_action',
                      ),
                      child: random,
                    ),
                  const _MobilePromptToolbarAction(
                    actionKey: ValueKey(
                      'generation_prompt_mobile_fixed_tags_action',
                    ),
                    child: FixedTagsButton(),
                  ),
                  _MobilePromptToolbarAction(
                    actionKey: const ValueKey(
                      'generation_prompt_mobile_quality_action',
                    ),
                    child: QualityTagsSelector(model: model),
                  ),
                  _MobilePromptToolbarAction(
                    actionKey: const ValueKey(
                      'generation_prompt_mobile_uc_action',
                    ),
                    child: UcPresetSelector(model: model),
                  ),
                  const _MobilePromptToolbarAction(
                    actionKey: ValueKey(
                      'generation_prompt_mobile_character_action',
                    ),
                    child: CharacterPromptButton(),
                  ),
                ],
              ),
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            typeSwitch,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const FixedTagsButton(compact: true),
                QualityTagsSelector(model: model),
                UcPresetSelector(model: model),
                const CharacterPromptButton(),
                toolbar,
              ],
            ),
          ],
        );
      },
    );
  }

  PromptEditorToolbar _editorToolbar(
    BuildContext context, {
    required bool showRandom,
    required VoidCallback settings,
  }) => PromptEditorToolbar(
    config: PromptEditorToolbarConfig.mainEditor.copyWith(
      showRandomButton: showRandom,
      showFullscreenButton: viewData.showMaximizeButton,
    ),
    onRandomPressed: showRandom ? commands.generateRandomPrompt : null,
    onRandomLongPressed: showRandom ? commands.showRandomModeSelector : null,
    onFullscreenPressed: commands.toggleMaximize,
    isFullscreen: viewData.isMaximized,
    onClearPressed: controller.isNegativeMode
        ? commands.clearNegativePrompt
        : commands.clearPrompt,
    onSettingsPressed: settings,
  );

  PromptEditorToolbar _randomToolbar(bool visible) => PromptEditorToolbar(
    config: PromptEditorToolbarConfig.mainEditor.copyWith(
      showRandomButton: visible,
      showFullscreenButton: false,
      showClearButton: false,
      showSettingsButton: false,
    ),
    onRandomPressed: visible ? commands.generateRandomPrompt : null,
    onRandomLongPressed: visible ? commands.showRandomModeSelector : null,
  );

  Future<void> _showSettingsMenu(BuildContext context, WidgetRef ref) async {
    final position = PromptEditorToolbar.getSettingsButtonPosition(context);
    if (position == null) return;
    final theme = Theme.of(context);
    final autocomplete = ref.read(autocompleteSettingsProvider);
    final autoFormat = ref.read(autoFormatPromptSettingsProvider);
    final highlight = ref.read(highlightEmphasisSettingsProvider);
    final sdConvert = ref.read(sdSyntaxAutoConvertSettingsProvider);
    final resolveAlias = ref.read(resolveAliasOnCopySettingsProvider);
    final cooccurrence = ref
        .read(completion_settings.autocompleteSettingsProvider)
        .relatedTagsEnabled;
    final regexCount = ref.read(promptRegexRulesProvider).length;
    final value = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: [
        _toggleItem(
          context,
          theme,
          'autocomplete',
          autocomplete,
          context.l10n.prompt_smartAutocomplete,
          context.l10n.prompt_smartAutocompleteSubtitle,
        ),
        _toggleItem(
          context,
          theme,
          'auto_format',
          autoFormat,
          context.l10n.prompt_autoFormat,
          context.l10n.prompt_autoFormatSubtitle,
        ),
        _toggleItem(
          context,
          theme,
          'highlight',
          highlight,
          context.l10n.prompt_highlightEmphasis,
          context.l10n.prompt_highlightEmphasisSubtitle,
        ),
        _toggleItem(
          context,
          theme,
          'sd_syntax_convert',
          sdConvert,
          context.l10n.prompt_sdSyntaxAutoConvert,
          context.l10n.prompt_sdSyntaxAutoConvertSubtitle,
        ),
        _actionItem(
          theme,
          'regex_rules',
          Icons.find_replace,
          context.l10n.prompt_regexRulesManage,
          context.l10n.prompt_regexRulesCount(regexCount),
        ),
        _toggleItem(
          context,
          theme,
          'resolve_alias_on_copy',
          resolveAlias,
          context.l10n.prompt_resolveAliasOnCopy,
          context.l10n.prompt_resolveAliasOnCopySubtitle,
        ),
        _toggleItem(
          context,
          theme,
          'cooccurrence',
          cooccurrence,
          context.l10n.prompt_cooccurrenceRecommendation,
          context.l10n.prompt_cooccurrenceRecommendationSubtitle,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (value) {
      case 'autocomplete':
        ref.read(autocompleteSettingsProvider.notifier).toggle();
      case 'auto_format':
        ref.read(autoFormatPromptSettingsProvider.notifier).toggle();
      case 'highlight':
        ref.read(highlightEmphasisSettingsProvider.notifier).toggle();
      case 'sd_syntax_convert':
        ref.read(sdSyntaxAutoConvertSettingsProvider.notifier).toggle();
      case 'regex_rules':
        RegexRulesDialog.show(context);
      case 'resolve_alias_on_copy':
        ref.read(resolveAliasOnCopySettingsProvider.notifier).toggle();
      case 'cooccurrence':
        final provider = completion_settings.autocompleteSettingsProvider;
        final current = ref.read(provider).relatedTagsEnabled;
        ref.read(provider.notifier).setRelatedTagsEnabled(!current);
      case null:
        return;
    }
  }

  PopupMenuItem<String> _toggleItem(
    BuildContext context,
    ThemeData theme,
    String value,
    bool enabled,
    String title,
    String subtitle,
  ) => PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(
          enabled ? Icons.check_box : Icons.check_box_outline_blank,
          size: 20,
          color: enabled ? theme.colorScheme.primary : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: _menuLabels(theme, title, subtitle)),
      ],
    ),
  );

  PopupMenuItem<String> _actionItem(
    ThemeData theme,
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) => PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: _menuLabels(theme, title, subtitle)),
        Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline),
      ],
    ),
  );

  Widget _menuLabels(ThemeData theme, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ],
  );
}

class _MobileFullscreenToolbar extends StatelessWidget {
  const _MobileFullscreenToolbar({
    required this.controller,
    required this.commands,
    required this.viewData,
    required this.model,
    required this.showRandomTools,
    required this.settings,
    required this.editor,
    required this.footer,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;
  final String model;
  final bool showRandomTools;
  final VoidCallback settings;
  final Widget editor;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final primary = PromptEditorToolbar(
      config: PromptEditorToolbarConfig.mainEditor.copyWith(
        showRandomButton: false,
        showFullscreenButton: false,
      ),
      onClearPressed: controller.isNegativeMode
          ? commands.clearNegativePrompt
          : commands.clearPrompt,
      onSettingsPressed: settings,
    );
    final random = PromptEditorToolbar(
      config: PromptEditorToolbarConfig.mainEditor.copyWith(
        showRandomButton: showRandomTools,
        showFullscreenButton: false,
        showClearButton: false,
        showSettingsButton: false,
      ),
      onRandomPressed: showRandomTools ? commands.generateRandomPrompt : null,
      onRandomLongPressed: showRandomTools
          ? commands.showRandomModeSelector
          : null,
    );
    return LayoutBuilder(
      key: const ValueKey('generation_prompt_mobile_workbench'),
      builder: (context, constraints) {
        final typeSwitch = PromptTypeSwitch(
          controller: controller,
          commands: commands,
          expand: true,
          compact: true,
        );
        final stackPrimary =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        Widget buildWorkbench() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stackPrimary) ...[
              typeSwitch,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: primary),
            ] else
              Row(
                key: const ValueKey('generation_prompt_mobile_primary_row'),
                children: [
                  Expanded(child: typeSwitch),
                  const SizedBox(width: 4),
                  primary,
                ],
              ),
            const SizedBox(height: 8),
            Expanded(child: editor),
            footer,
            const SizedBox(height: 8),
            SizedBox(
              key: const ValueKey('generation_prompt_mobile_context_bar'),
              height: 48,
              child: SingleChildScrollView(
                key: const ValueKey(
                  'generation_prompt_mobile_secondary_scroll',
                ),
                scrollDirection: Axis.horizontal,
                child: Row(
                  key: const ValueKey('generation_prompt_mobile_secondary_row'),
                  children: [
                    _MobilePromptToolbarAction(
                      actionKey: const ValueKey(
                        'generation_prompt_mobile_character_action',
                      ),
                      child: CharacterPromptButton(
                        onManage: commands.showMobileCharacterManager,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _MobilePromptToolbarAction(
                      actionKey: ValueKey(
                        'generation_prompt_mobile_fixed_tags_action',
                      ),
                      child: FixedTagsButton(),
                    ),
                    const SizedBox(width: 6),
                    _MobilePromptToolbarAction(
                      actionKey: const ValueKey(
                        'generation_prompt_mobile_quality_action',
                      ),
                      child: QualityTagsSelector(model: model),
                    ),
                    const SizedBox(width: 6),
                    _MobilePromptToolbarAction(
                      actionKey: const ValueKey(
                        'generation_prompt_mobile_uc_action',
                      ),
                      child: UcPresetSelector(model: model),
                    ),
                    if (showRandomTools) ...[
                      const SizedBox(width: 4),
                      _MobilePromptToolbarAction(
                        actionKey: const ValueKey(
                          'generation_prompt_mobile_random_action',
                        ),
                        child: random,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        if (constraints.maxHeight >= 240) return buildWorkbench();
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final scrollableHeight = 140 * textScale.clamp(1, 3).toDouble();
        return SingleChildScrollView(
          child: SizedBox(height: scrollableHeight, child: buildWorkbench()),
        );
      },
    );
  }
}

class _MobilePromptToolbarAction extends StatelessWidget {
  const _MobilePromptToolbarAction({
    required this.actionKey,
    required this.child,
  });

  final Key actionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(key: actionKey, height: 48, child: child);
}
