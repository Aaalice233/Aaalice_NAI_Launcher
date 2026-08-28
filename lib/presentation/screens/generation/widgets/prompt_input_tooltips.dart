import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/prompt/prompt_preset_mode.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../widgets/common/app_toast.dart';
import 'prompt_tooltip_components.dart';

class PositivePromptTooltip extends StatelessWidget {
  const PositivePromptTooltip({
    super.key,
    required this.theme,
    required this.userPrompt,
    required this.prefixes,
    required this.suffixes,
    required this.qualityMode,
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
  final PromptPresetMode qualityMode;
  final String? qualityContent;
  final List<CharacterPrompt> characters;
  final bool globalAiChoice;
  final AppLocalizations l10n;
  final AliasResolverService aliasResolver;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final enabledCharacters = characters
        .where((character) => character.enabled && character.prompt.isNotEmpty)
        .toList();
    final effectivePrompt = _buildEffectivePrompt();
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
        if (prefixes.isNotEmpty) ...[
          _section(
            Icons.arrow_forward_rounded,
            l10n.fixedTags_prefix,
            theme.colorScheme.primary,
            prefixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (userPrompt.trim().isNotEmpty) ...[
          _section(
            Icons.edit_rounded,
            l10n.prompt_mainPositive,
            theme.colorScheme.secondary,
            _resolve(userPrompt.trim()),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (qualityContent?.isNotEmpty ?? false) ...[
          _section(
            Icons.star_rounded,
            l10n.qualityTags_positive,
            Colors.amber,
            qualityContent!,
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (enabledCharacters.isNotEmpty) ...[
          TooltipCharacterSection(
            theme: theme,
            label: l10n.prompt_characterPrompts,
            characters: enabledCharacters,
            globalAiChoice: globalAiChoice,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (suffixes.isNotEmpty) ...[
          _section(
            Icons.arrow_back_rounded,
            l10n.fixedTags_suffix,
            theme.colorScheme.tertiary,
            suffixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        const _TooltipDivider(),
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
      ],
    );
  }

  TooltipSection _section(
    IconData icon,
    String label,
    Color color,
    String content,
    bool isDark,
  ) => TooltipSection(
    theme: theme,
    icon: icon,
    label: label,
    color: color,
    content: content,
    isDark: isDark,
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
    // Reading the mode here keeps the view data complete for callers even when
    // the effective quality content is empty for the selected mode.
    qualityMode;
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
    final effectivePrompt = _effectivePrompt();
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
        if (ucPresetContent.isNotEmpty) ...[
          _section(
            Icons.shield_rounded,
            l10n.qualityTags_negative,
            theme.colorScheme.error,
            ucPresetContent,
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (prefixes.isNotEmpty) ...[
          _section(
            Icons.arrow_forward_rounded,
            l10n.prompt_negativeFixedTagPrefix,
            theme.colorScheme.error,
            prefixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (userNegativePrompt.trim().isNotEmpty) ...[
          _section(
            Icons.edit_rounded,
            l10n.prompt_mainNegative,
            theme.colorScheme.tertiary,
            _resolve(userNegativePrompt.trim()),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (suffixes.isNotEmpty) ...[
          _section(
            Icons.arrow_back_rounded,
            l10n.prompt_negativeFixedTagSuffix,
            theme.colorScheme.tertiary,
            suffixes.map((tag) => _resolve(tag.content)).join(', '),
            isDark,
          ),
          const SizedBox(height: 8),
        ],
        const _TooltipDivider(),
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
      ],
    );
  }

  TooltipSection _section(
    IconData icon,
    String label,
    Color color,
    String content,
    bool isDark,
  ) => TooltipSection(
    theme: theme,
    icon: icon,
    label: label,
    color: color,
    content: content,
    isDark: isDark,
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

class _TooltipDivider extends StatelessWidget {
  const _TooltipDivider();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    height: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
  );
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
