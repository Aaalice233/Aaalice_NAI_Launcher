import 'package:flutter/material.dart';

import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/common/translated_tag_text.dart';

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

class TooltipCompositionHeading extends StatelessWidget {
  const TooltipCompositionHeading({super.key, required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
    child: Row(
      children: [
        Icon(
          Icons.layers_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.prompt_composition,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// One independently collapsible step in the effective-prompt composition.
class TooltipSection extends StatelessWidget {
  const TooltipSection({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.color,
    required this.content,
    required this.isDark,
    this.initiallyExpanded = true,
    this.maxLines = 3,
  });

  final ThemeData theme;
  final IconData icon;
  final String label;
  final Color color;
  final String content;
  final bool isDark;
  final bool initiallyExpanded;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => _TooltipCompositionCard(
    theme: theme,
    icon: icon,
    label: label,
    color: color,
    itemCount: _promptTagCount(content),
    isDark: isDark,
    initiallyExpanded: initiallyExpanded,
    child: TranslatedPromptText(
      content,
      selectable: false,
      maxLines: maxLines,
      includeUntranslated: true,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
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
    this.initiallyExpanded = true,
  });

  final ThemeData theme;
  final String label;
  final List<CharacterPrompt> characters;
  final bool globalAiChoice;
  final bool isDark;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.tertiary;
    final tagCount = characters.fold<int>(
      0,
      (total, character) =>
          total +
          _promptTagCount(character.toNaiPrompt(useAiPosition: globalAiChoice)),
    );
    return _TooltipCompositionCard(
      theme: theme,
      icon: Icons.people_rounded,
      label: label,
      color: color,
      itemCount: tagCount,
      isDark: isDark,
      initiallyExpanded: initiallyExpanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                    child: TranslatedPromptText(
                      character.toNaiPrompt(useAiPosition: globalAiChoice),
                      originalText:
                          '${character.name}: ${character.toNaiPrompt(useAiPosition: globalAiChoice)}',
                      selectable: false,
                      maxLines: 3,
                      includeUntranslated: true,
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
    );
  }
}

class _TooltipCompositionCard extends StatefulWidget {
  const _TooltipCompositionCard({
    required this.theme,
    required this.icon,
    required this.label,
    required this.color,
    required this.itemCount,
    required this.isDark,
    required this.initiallyExpanded,
    required this.child,
  });

  final ThemeData theme;
  final IconData icon;
  final String label;
  final Color color;
  final int itemCount;
  final bool isDark;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_TooltipCompositionCard> createState() =>
      _TooltipCompositionCardState();
}

class _TooltipCompositionCardState extends State<_TooltipCompositionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final background = Color.alphaBlend(
      widget.color.withValues(alpha: widget.isDark ? 0.10 : 0.065),
      widget.theme.colorScheme.surfaceContainerLow,
    );
    final contentBackground = Color.alphaBlend(
      widget.color.withValues(alpha: widget.isDark ? 0.065 : 0.035),
      widget.theme.colorScheme.surfaceContainerHigh,
    );
    final actionLabel = _expanded
        ? l10n?.common_collapse ?? 'Collapse'
        : l10n?.common_expand ?? 'Expand';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: '${widget.label}, ${widget.itemCount}',
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 8, 7),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(widget.icon, size: 16, color: widget.color),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.labelMedium?.copyWith(
                          color: widget.theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.itemCount > 0) ...[
                      const SizedBox(width: 8),
                      _TooltipCountBadge(
                        theme: widget.theme,
                        label: '${widget.itemCount}',
                      ),
                    ],
                    const SizedBox(width: 6),
                    Tooltip(
                      message: actionLabel,
                      child: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: duration,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: widget.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                      decoration: BoxDecoration(
                        color: contentBackground,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: widget.child,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// The visually dominant surface in the tooltip, reserved for the result.
class TooltipFinalPromptSection extends StatefulWidget {
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
  State<TooltipFinalPromptSection> createState() =>
      _TooltipFinalPromptSectionState();
}

class _TooltipFinalPromptSectionState extends State<TooltipFinalPromptSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveColor = widget.color ?? widget.theme.colorScheme.primary;
    final base = widget.theme.colorScheme.surfaceContainerHigh;
    final background = Color.alphaBlend(
      widget.backgroundStartColor.withValues(
        alpha: widget.isDark ? 0.16 : 0.10,
      ),
      Color.alphaBlend(
        widget.backgroundEndColor.withValues(
          alpha: widget.isDark ? 0.08 : 0.05,
        ),
        base,
      ),
    );
    final tagCount = _promptTagCount(widget.prompt);
    final canExpand = widget.prompt.length > 140 || tagCount > 12;
    final compactHeader = MediaQuery.textScalerOf(context).scale(12) > 24;
    final countLabel = l10n?.tagGroup_tagCount(tagCount) ?? '$tagCount';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
                  widget.label ??
                      l10n?.prompt_finalPrompt ??
                      'Final effective prompt',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.theme.textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (tagCount > 0 && !compactHeader) ...[
                const SizedBox(width: 6),
                _TooltipCountBadge(theme: widget.theme, label: countLabel),
              ],
              if (widget.onCopy != null) ...[
                const SizedBox(width: 4),
                _TooltipCopyButton(
                  color: effectiveColor,
                  onCopy: widget.onCopy!,
                ),
              ],
            ],
          ),
          if (tagCount > 0 && compactHeader) ...[
            const SizedBox(height: 5),
            _TooltipCountBadge(theme: widget.theme, label: countLabel),
          ],
          const SizedBox(height: 7),
          TranslatedPromptText(
            widget.prompt,
            selectable: false,
            maxLines: _expanded ? null : 3,
            includeUntranslated: true,
            style: widget.theme.textTheme.bodySmall?.copyWith(
              color: widget.theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          if (canExpand) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const ValueKey('tooltip-final-expand-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: effectiveColor,
                  minimumSize: const Size(40, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                    ),
                    Text(
                      _expanded
                          ? l10n?.prompt_collapseFull ?? 'Collapse full text'
                          : l10n?.prompt_expandFull ?? 'Expand full text',
                      textAlign: TextAlign.center,
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: effectiveColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TooltipCountBadge extends StatelessWidget {
  const _TooltipCountBadge({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

int _promptTagCount(String prompt) {
  final value = prompt.trim();
  if (value.isEmpty || value == '-') return 0;
  return NaiPromptParser.splitSegments(value).length;
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
