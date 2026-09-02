import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/character/character_prompt.dart';

/// Tooltip 头部组件
class TooltipHeader extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  const TooltipHeader({
    super.key,
    required this.theme,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.2 : 0.1),
            color.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tooltip 内容区块组件
class TooltipSection extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final Color color;
  final String content;
  final bool isDark;

  const TooltipSection({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.color,
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.4)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    const color = Colors.teal;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.4)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.people_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${characters.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: characters.map((character) {
                  return Padding(
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
                          size: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${character.name}: ${character.toNaiPrompt(useAiPosition: globalAiChoice)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tooltip 最终提示词区块
class TooltipFinalPromptSection extends StatelessWidget {
  final ThemeData theme;
  final String prompt;
  final bool isDark;
  final String? label;
  final Color? color;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final VoidCallback? onCopy;

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

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundStartColor.withValues(alpha: isDark ? 0.3 : 0.4),
            backgroundEndColor.withValues(alpha: isDark ? 0.2 : 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Icon(Icons.output_rounded, size: 12, color: effectiveColor),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (constraints.maxWidth - (onCopy == null ? 18 : 40))
                            .clamp(0, double.infinity),
                  ),
                  child: Text(
                    label ?? context.l10n.prompt_finalPrompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: effectiveColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (onCopy != null)
                  _TooltipCopyButton(color: effectiveColor, onCopy: onCopy!),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
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
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.tooltip_copy,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onCopy,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isHovering
                  ? widget.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.copy_rounded,
              size: 14,
              color: _isHovering
                  ? widget.color
                  : widget.color.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
