import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../data/models/character/character_prompt.dart';
import '../common/translated_tag_text.dart';

/// 折叠角色栏的只读悬浮预览。
///
/// 只展示快速判断配置所需的信息：启用数量、性别、名称和前三个提示词标签。
/// 预览本身不接收指针，完整编辑仍由角色栏展开态承载。
class CharacterTooltipContent extends StatelessWidget {
  const CharacterTooltipContent({super.key, required this.config});

  static const _maxVisibleCharacters = 3;

  final CharacterPromptConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final characters = config.characters;
    final visibleCharacters = characters.take(_maxVisibleCharacters).toList();
    final enabledCount = characters
        .where((character) => character.enabled)
        .length;
    final remainingCount = characters.length - visibleCharacters.length;

    return Material(
      key: const Key('character-hover-preview'),
      color: colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 17,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.characterTooltip_previewTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _EnabledSummaryBadge(
                  label: l10n.characterTooltip_enabledSummary(
                    enabledCount,
                    characters.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < visibleCharacters.length; index++) ...[
              if (index > 0) const SizedBox(height: 6),
              _CharacterPreviewRow(
                character: visibleCharacters[index],
                fallbackName: l10n.character_number(index + 1),
              ),
            ],
            if (remainingCount > 0) ...[
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.characterTooltip_more(remainingCount),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _EnabledSummaryBadge extends StatelessWidget {
  const _EnabledSummaryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _CharacterPreviewRow extends StatelessWidget {
  const _CharacterPreviewRow({
    required this.character,
    required this.fallbackName,
  });

  final CharacterPrompt character;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final gender = character.effectiveGender;
    final genderColor = _genderColor(gender);
    final promptPreview = _buildPromptPreview(character.prompt);
    final name = character.name.trim().isEmpty
        ? fallbackName
        : character.name.trim();

    return Opacity(
      opacity: character.enabled ? 1 : 0.52,
      child: Container(
        key: ValueKey('character-hover-item-${character.id}'),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            genderColor.withValues(alpha: 0.065),
            colorScheme.surfaceContainerLow,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PreviewGenderBadge(gender: gender, color: genderColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!character.enabled) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.characterTooltip_disabledLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            if (promptPreview.isEmpty)
              Text(
                l10n.characterTooltip_notSet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                  height: 1.2,
                ),
              )
            else
              TranslatedPromptText(
                promptPreview.replaceAll(' · ', ', '),
                selectable: false,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _buildPromptPreview(String prompt) {
    return prompt
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(3)
        .join(' · ');
  }

  static Color _genderColor(CharacterGender gender) => switch (gender) {
    CharacterGender.female => const Color(0xFFEC4899),
    CharacterGender.male => const Color(0xFF3B82F6),
    CharacterGender.other => const Color(0xFF8B5CF6),
  };
}

class _PreviewGenderBadge extends StatelessWidget {
  const _PreviewGenderBadge({required this.gender, required this.color});

  final CharacterGender gender;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, label) = switch (gender) {
      CharacterGender.female => (
        Icons.female,
        l10n.characterEditor_genderFemale,
      ),
      CharacterGender.male => (Icons.male, l10n.characterEditor_genderMale),
      CharacterGender.other => (
        Icons.transgender,
        l10n.characterEditor_genderOther,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
