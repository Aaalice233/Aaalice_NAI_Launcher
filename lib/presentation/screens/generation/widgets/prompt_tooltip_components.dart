import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/character/character_prompt.dart';

/// Compact heading for prompt composition previews.
class TooltipHeader extends StatelessWidget {
  const TooltipHeader({
    super.key,
    required this.theme,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final ThemeData theme;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// One step in the effective-prompt composition.
class TooltipSection extends StatelessWidget {
  const TooltipSection({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.color,
    required this.content,
    required this.isDark,
  });

  final ThemeData theme;
  final IconData icon;
  final String label;
  final Color color;
  final String content;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 21),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 104),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TooltipCharacterSection extends StatelessWidget {
  const TooltipCharacterSection({
    super.key,
    required this.theme,
    required this.label,
    required this.characters,
    required this.globalAiChoice,
    required this.isDark,
  });

  final ThemeData theme;
  final String label;
  final List<CharacterPrompt> characters;
  final bool globalAiChoice;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${characters.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 112),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final character in characters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              character.gender == CharacterGender.female
                                  ? Icons.female
                                  : character.gender == CharacterGender.male
                                  ? Icons.male
                                  : Icons.person,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${character.name}: ${character.toNaiPrompt(useAiPosition: globalAiChoice)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The only filled surface in the tooltip, reserved for the composed result.
class TooltipFinalPromptSection extends StatelessWidget {
  const TooltipFinalPromptSection({
    super.key,
    required this.theme,
    required this.prompt,
    required this.isDark,
    required this.backgroundStartColor,
    required this.backgroundEndColor,
    this.label,
    this.color,
    this.onCopy,
  });

  final ThemeData theme;
  final String prompt;
  final bool isDark;
  final String? label;
  final Color? color;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme.colorScheme.primary;
    final base = theme.colorScheme.surfaceContainerHigh;
    final background = Color.alphaBlend(
      backgroundStartColor.withValues(alpha: isDark ? 0.16 : 0.10),
      Color.alphaBlend(
        backgroundEndColor.withValues(alpha: isDark ? 0.08 : 0.05),
        base,
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.output_rounded, size: 14, color: effectiveColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label ?? context.l10n.prompt_finalPrompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 4),
                _TooltipCopyButton(color: effectiveColor, onCopy: onCopy!),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 136),
            child: SingleChildScrollView(
              child: Text(
                prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipCopyButton extends StatefulWidget {
  const _TooltipCopyButton({required this.color, required this.onCopy});

  final Color color;
  final VoidCallback onCopy;

  @override
  State<_TooltipCopyButton> createState() => _TooltipCopyButtonState();
}

class _TooltipCopyButtonState extends State<_TooltipCopyButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.tooltip_copy,
    child: MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: IconButton(
        onPressed: widget.onCopy,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: _isHovering
              ? widget.color
              : widget.color.withValues(alpha: 0.72),
          backgroundColor: _isHovering
              ? widget.color.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.copy_rounded, size: 17),
      ),
    ),
  );
}
