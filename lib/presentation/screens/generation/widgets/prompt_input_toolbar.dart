import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/autocomplete/autocomplete_settings.dart'
    as completion_settings;
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_regex_rules_provider.dart';
import '../../../widgets/character/character_prompt_button.dart';
import '../../../widgets/common/horizontal_action_strip.dart';
import '../../../widgets/prompt/fixed_tags_button.dart';
import '../../../widgets/prompt/quality_tags_selector.dart';
import '../../../widgets/prompt/regex_rules_dialog.dart';
import '../../../widgets/prompt/toolbar/toolbar.dart';
import '../../../widgets/prompt/uc_preset_selector.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';
import '../../../widgets/prompt/prompt_footer_style.dart';
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
    if (mobileFullscreen) {
      return _MobileFullscreenToolbar(
        controller: controller,
        commands: commands,
        model: model,
        editor: mobileEditor!,
        footer: mobileFooter!,
      );
    }

    final typeSwitch = PromptTypeSwitch(
      controller: controller,
      commands: commands,
    );
    final toolbar = _fullscreenToolbar();

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesLargeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final usesCompactSingleRow =
            viewData.autoGrow && constraints.maxWidth >= 360 && !usesLargeText;
        if (usesCompactSingleRow) {
          final showUtilityLabels =
              constraints.maxWidth >= (viewData.showMaximizeButton ? 520 : 450);
          return SizedBox(
            key: const ValueKey('generation_prompt_compact_single_row'),
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: PromptTypeSwitch(
                    controller: controller,
                    commands: commands,
                    expand: true,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  key: const ValueKey(
                    'generation_prompt_compact_single_row_actions',
                  ),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FixedTagsButton(
                      compact: true,
                      iconOnly: !showUtilityLabels,
                      maxLabelWidth: showUtilityLabels ? 48 : null,
                    ),
                    const SizedBox(width: 4),
                    QualityTagsSelector(
                      model: model,
                      compact: true,
                      iconOnly: !showUtilityLabels,
                      maxLabelWidth: showUtilityLabels ? 48 : null,
                    ),
                    const SizedBox(width: 4),
                    UcPresetSelector(
                      model: model,
                      compact: true,
                      iconOnly: !showUtilityLabels,
                      maxLabelWidth: showUtilityLabels ? 48 : null,
                    ),
                    const SizedBox(width: 4),
                    toolbar,
                  ],
                ),
              ],
            ),
          );
        }
        if (constraints.maxWidth < 600) {
          final primary = _fullscreenToolbar();
          final showTouchCharacter =
              context.interactionPolicy.shouldExposeTouchAlternatives;
          final typeSwitch = PromptTypeSwitch(
            controller: controller,
            commands: commands,
            expand: true,
            compact: true,
          );
          final stackPrimary = constraints.maxWidth < 360 || usesLargeText;
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
                  if (showTouchCharacter)
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
                toolbar,
              ],
            ),
          ],
        );
      },
    );
  }

  PromptEditorToolbar _fullscreenToolbar() => PromptEditorToolbar(
    config: PromptEditorToolbarConfig.mainEditor.copyWith(
      showRandomButton: false,
      showFullscreenButton: viewData.showMaximizeButton,
      showClearButton: false,
      showSettingsButton: false,
    ),
    onFullscreenPressed: commands.toggleMaximize,
    isFullscreen: viewData.isMaximized,
  );

  static Future<void> _showSettingsMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

  static PopupMenuItem<String> _toggleItem(
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

  static PopupMenuItem<String> _actionItem(
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

  static Widget _menuLabels(ThemeData theme, String title, String subtitle) =>
      Column(
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

class PromptInputBottomActions extends ConsumerWidget {
  const PromptInputBottomActions({
    super.key,
    required this.controller,
    required this.commands,
    this.showClearButton = true,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final bool showClearButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    return PromptEditorToolbar(
      key: const ValueKey('generation_prompt_bottom_actions'),
      buttonStyle: PromptFooterStyle.button(context).copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        fixedSize: WidgetStatePropertyAll(
          Size.square(PromptFooterStyle.height(context)),
        ),
      ),
      actionIconSize: PromptFooterStyle.iconSize,
      config: PromptEditorToolbarConfig.mainEditor.copyWith(
        showRandomButton: showRandomTools,
        showFullscreenButton: false,
        showClearButton: showClearButton,
      ),
      onRandomPressed: showRandomTools ? commands.generateRandomPrompt : null,
      onClearPressed: controller.isNegativeMode
          ? commands.clearNegativePrompt
          : commands.clearPrompt,
      onSettingsPressed: () =>
          PromptInputToolbar._showSettingsMenu(context, ref),
    );
  }
}

class _MobileFullscreenToolbar extends StatelessWidget {
  const _MobileFullscreenToolbar({
    required this.controller,
    required this.commands,
    required this.model,
    required this.editor,
    required this.footer,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final String model;
  final Widget editor;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('generation_prompt_mobile_workbench'),
      builder: (context, constraints) {
        final typeSwitch = PromptTypeSwitch(
          controller: controller,
          commands: commands,
          expand: true,
          compact: true,
        );
        Widget buildWorkbench() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            typeSwitch,
            const SizedBox(height: 8),
            Expanded(child: editor),
            footer,
            const SizedBox(height: 8),
            SizedBox(
              key: const ValueKey('generation_prompt_mobile_context_bar'),
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: HorizontalActionStrip(
                      minimumExtent: 48,
                      scrollKey: const ValueKey(
                        'generation_prompt_mobile_secondary_scroll',
                      ),
                      hintKey: const ValueKey(
                        'generation_prompt_mobile_secondary_scroll_hint',
                      ),
                      child: Row(
                        key: const ValueKey(
                          'generation_prompt_mobile_secondary_row',
                        ),
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
                          const SizedBox(width: 6),
                          _MobilePromptToolbarAction(
                            actionKey: const ValueKey(
                              'generation_prompt_mobile_bottom_actions',
                            ),
                            child: PromptInputBottomActions(
                              controller: controller,
                              commands: commands,
                              showClearButton: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox.square(
                    key: const ValueKey(
                      'generation_prompt_mobile_clear_action',
                    ),
                    dimension: 48,
                    child: PromptEditorToolbar(
                      config: PromptEditorToolbarConfig.mainEditor.copyWith(
                        showRandomButton: false,
                        showFullscreenButton: false,
                        showSettingsButton: false,
                      ),
                      onClearPressed: controller.isNegativeMode
                          ? commands.clearNegativePrompt
                          : commands.clearPrompt,
                    ),
                  ),
                ],
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
