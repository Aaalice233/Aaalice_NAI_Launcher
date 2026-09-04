import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../themes/prompt_semantic_colors.dart';
import '../../../widgets/common/app_toast.dart';
import 'prompt_tooltip_components.dart';

class PositivePromptTooltip extends StatelessWidget {
  const PositivePromptTooltip({
    super.key,
    required this.theme,
    required this.userPrompt,
    required this.prefixes,
    required this.suffixes,
    required this.qualityContent,
    required this.characters,
    required this.globalAiChoice,
    required this.l10n,
    required this.aliasResolver,
    this.onCopy,
  });

  final ThemeData theme;
  final String userPrompt;
  final List<FixedTagEntry> prefixes;
  final List<FixedTagEntry> suffixes;
  final String? qualityContent;
  final List<CharacterPrompt> characters;
  final bool globalAiChoice;
  final AppLocalizations l10n;
  final AliasResolverService aliasResolver;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final promptColors = theme.promptSemanticColors;
    final enabledCharacters = characters
        .where((character) => character.enabled && character.prompt.isNotEmpty)
        .toList();
    final effectivePrompt = _buildEffectivePrompt();
    final hasComposition =
        prefixes.isNotEmpty ||
        userPrompt.trim().isNotEmpty ||
        (qualityContent?.isNotEmpty ?? false) ||
        enabledCharacters.isNotEmpty ||
        suffixes.isNotEmpty;
    var visibleSectionIndex = 0;
    bool expandSection() => visibleSectionIndex++ < 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TooltipHeader(
          theme: theme,
          label: l10n.prompt_positivePrompt,
          icon: Icons.auto_awesome,
          color: theme.colorScheme.primary,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _CopyableFinalPrompt(
          theme: theme,
          prompt: effectivePrompt,
          isDark: isDark,
          label: l10n.prompt_finalPrompt,
          color: theme.colorScheme.primary,
          backgroundStartColor: theme.colorScheme.primaryContainer,
          backgroundEndColor: theme.colorScheme.secondaryContainer,
          copyWhenEmpty: true,
          onCopy: onCopy,
        ),
        if (hasComposition) ...[
          const SizedBox(height: 10),
          TooltipCompositionHeading(theme: theme),
          const SizedBox(height: 6),
        ],
        if (prefixes.isNotEmpty) ...[
          _section(
            'positive-prefix',
            Icons.arrow_forward_rounded,
            l10n.fixedTags_prefix,
            promptColors.positiveFixedTag,
            prefixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (userPrompt.trim().isNotEmpty) ...[
          _section(
            'positive-main',
            Icons.edit_rounded,
            l10n.prompt_mainPositive,
            promptColors.mainPrompt,
            _resolve(userPrompt.trim()),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (qualityContent?.isNotEmpty ?? false) ...[
          _section(
            'positive-quality',
            Icons.star_rounded,
            l10n.qualityTags_positive,
            promptColors.positiveQuality,
            qualityContent!,
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (enabledCharacters.isNotEmpty) ...[
          TooltipCharacterSection(
            key: const ValueKey('prompt-composition-positive-characters'),
            theme: theme,
            label: l10n.prompt_characterPrompts,
            characters: enabledCharacters,
            globalAiChoice: globalAiChoice,
            isDark: isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (suffixes.isNotEmpty) ...[
          _section(
            'positive-suffix',
            Icons.arrow_back_rounded,
            l10n.fixedTags_suffix,
            theme.colorScheme.secondary,
            suffixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  TooltipSection _section(
    String id,
    IconData icon,
    String label,
    Color color,
    String content,
    bool isDark, {
    required bool initiallyExpanded,
  }) => TooltipSection(
    key: ValueKey('prompt-composition-$id'),
    theme: theme,
    icon: icon,
    label: label,
    color: color,
    content: content,
    isDark: isDark,
    initiallyExpanded: initiallyExpanded,
  );

  String _resolve(String value) => aliasResolver.resolveAliases(value);

  String _buildEffectivePrompt() {
    final parts = <String>[
      ...prefixes
          .map((tag) => tag.content.trim())
          .where((value) => value.isNotEmpty)
          .map(_resolve),
      if (userPrompt.trim().isNotEmpty) _resolve(userPrompt.trim()),
      if (qualityContent?.isNotEmpty ?? false) qualityContent!,
      ...characters
          .where(
            (character) => character.enabled && character.prompt.isNotEmpty,
          )
          .map(
            (character) => character.toNaiPrompt(useAiPosition: globalAiChoice),
          ),
      ...suffixes
          .map((tag) => tag.content.trim())
          .where((value) => value.isNotEmpty)
          .map(_resolve),
    ];
    return parts.join(', ');
  }
}

class NegativePromptTooltip extends StatelessWidget {
  const NegativePromptTooltip({
    super.key,
    required this.theme,
    required this.userNegativePrompt,
    required this.prefixes,
    required this.suffixes,
    required this.ucPresetContent,
    required this.l10n,
    required this.aliasResolver,
    this.onCopy,
  });

  final ThemeData theme;
  final String userNegativePrompt;
  final List<FixedTagEntry> prefixes;
  final List<FixedTagEntry> suffixes;
  final String ucPresetContent;
  final AppLocalizations l10n;
  final AliasResolverService aliasResolver;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final promptColors = theme.promptSemanticColors;
    final effectivePrompt = _effectivePrompt();
    final hasComposition =
        ucPresetContent.isNotEmpty ||
        prefixes.isNotEmpty ||
        userNegativePrompt.trim().isNotEmpty ||
        suffixes.isNotEmpty;
    var visibleSectionIndex = 0;
    bool expandSection() => visibleSectionIndex++ < 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TooltipHeader(
          theme: theme,
          label: l10n.prompt_negativePrompt,
          icon: Icons.block,
          color: theme.colorScheme.error,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _CopyableFinalPrompt(
          theme: theme,
          prompt: effectivePrompt,
          isDark: isDark,
          label: l10n.prompt_finalNegative,
          color: theme.colorScheme.error,
          backgroundStartColor: theme.colorScheme.errorContainer,
          backgroundEndColor: theme.colorScheme.surfaceContainerHighest,
          onCopy: onCopy,
        ),
        if (hasComposition) ...[
          const SizedBox(height: 10),
          TooltipCompositionHeading(theme: theme),
          const SizedBox(height: 6),
        ],
        if (ucPresetContent.isNotEmpty) ...[
          _section(
            'negative-uc-preset',
            Icons.shield_rounded,
            l10n.qualityTags_negative,
            promptColors.negativeQuality,
            ucPresetContent,
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (prefixes.isNotEmpty) ...[
          _section(
            'negative-prefix',
            Icons.arrow_forward_rounded,
            l10n.prompt_negativeFixedTagPrefix,
            promptColors.negativeFixedTag,
            prefixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (userNegativePrompt.trim().isNotEmpty) ...[
          _section(
            'negative-main',
            Icons.edit_rounded,
            l10n.prompt_mainNegative,
            promptColors.mainPrompt,
            _resolve(userNegativePrompt.trim()),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
        if (suffixes.isNotEmpty) ...[
          _section(
            'negative-suffix',
            Icons.arrow_back_rounded,
            l10n.prompt_negativeFixedTagSuffix,
            theme.colorScheme.tertiary,
            suffixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
            initiallyExpanded: expandSection(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  TooltipSection _section(
    String id,
    IconData icon,
    String label,
    Color color,
    String content,
    bool isDark, {
    required bool initiallyExpanded,
  }) => TooltipSection(
    key: ValueKey('prompt-composition-$id'),
    theme: theme,
    icon: icon,
    label: label,
    color: color,
    content: content,
    isDark: isDark,
    initiallyExpanded: initiallyExpanded,
  );

  String _resolve(String value) => aliasResolver.resolveAliases(value);

  String _effectivePrompt() => <String>[
    if (ucPresetContent.isNotEmpty) ucPresetContent,
    ...prefixes
        .map((tag) => tag.content.trim())
        .where((value) => value.isNotEmpty)
        .map(_resolve),
    if (userNegativePrompt.trim().isNotEmpty)
      _resolve(userNegativePrompt.trim()),
    ...suffixes
        .map((tag) => tag.content.trim())
        .where((value) => value.isNotEmpty)
        .map(_resolve),
  ].join(', ');
}

class _CopyableFinalPrompt extends StatelessWidget {
  const _CopyableFinalPrompt({
    required this.theme,
    required this.prompt,
    required this.isDark,
    required this.label,
    required this.color,
    required this.backgroundStartColor,
    required this.backgroundEndColor,
    required this.onCopy,
    this.copyWhenEmpty = false,
  });

  final ThemeData theme;
  final String prompt;
  final bool isDark;
  final String label;
  final Color color;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final VoidCallback? onCopy;
  final bool copyWhenEmpty;

  @override
  Widget build(BuildContext context) => TooltipFinalPromptSection(
    theme: theme,
    prompt: prompt.isEmpty && !copyWhenEmpty ? '-' : prompt,
    isDark: isDark,
    label: label,
    color: color,
    backgroundStartColor: backgroundStartColor,
    backgroundEndColor: backgroundEndColor,
    onCopy: prompt.isNotEmpty || copyWhenEmpty
        ? onCopy ??
              () async {
                await Clipboard.setData(ClipboardData(text: prompt));
                if (context.mounted) {
                  AppToast.success(
                    context,
                    l10nFromContext(context).common_copied,
                  );
                }
              }
        : null,
  );
}

AppLocalizations l10nFromContext(BuildContext context) =>
    AppLocalizations.of(context)!;
