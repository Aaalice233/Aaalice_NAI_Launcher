import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/quality_preset_provider.dart';
import '../../../providers/uc_preset_provider.dart';
import '../../../../data/services/alias_resolver_service.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';
import 'prompt_input_tooltips.dart';

bool shouldUseRichPromptTypeTooltip(TargetPlatform platform) =>
    platform != TargetPlatform.windows;

class PromptTypeSwitch extends ConsumerWidget {
  const PromptTypeSwitch({
    super.key,
    required this.controller,
    required this.commands,
    this.expand = false,
    this.compact = false,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fixedTags = ref.watch(fixedTagsNotifierProvider);
    final quality = ref.watch(qualityPresetNotifierProvider);
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    final qualityContent = ref
        .watch(qualityPresetNotifierProvider.notifier)
        .getEffectiveContent(model);
    ref.watch(ucPresetNotifierProvider);
    final ucContent =
        ref
            .watch(ucPresetNotifierProvider.notifier)
            .getEffectiveContent(model) ??
        '';
    final characters = ref.watch(characterPromptNotifierProvider);
    final aliases = ref.read(aliasResolverServiceProvider.notifier);

    final positive = PromptTypeButton(
      icon: Icons.auto_awesome,
      label: context.l10n.prompt_positive,
      count: controller.promptCount,
      isSelected: !controller.isNegativeMode,
      color: theme.colorScheme.primary,
      compact: compact,
      onTap: () => commands.setNegativeMode(false),
      tooltipBuilder: (theme) => PositivePromptTooltip(
        theme: theme,
        userPrompt: controller.promptController.text,
        prefixes: fixedTags.enabledPrefixes,
        suffixes: fixedTags.enabledSuffixes,
        qualityMode: quality.mode,
        qualityContent: qualityContent,
        characters: characters.characters,
        globalAiChoice: characters.globalAiChoice,
        l10n: context.l10n,
        aliasResolver: aliases,
      ),
    );
    final negative = PromptTypeButton(
      icon: Icons.block,
      label: context.l10n.prompt_negative,
      count: controller.negativePromptCount,
      isSelected: controller.isNegativeMode,
      color: theme.colorScheme.error,
      compact: compact,
      onTap: () => commands.setNegativeMode(true),
      tooltipBuilder: (theme) => NegativePromptTooltip(
        theme: theme,
        userNegativePrompt: controller.negativeController.text,
        prefixes: fixedTags.negativeEnabledPrefixes,
        suffixes: fixedTags.negativeEnabledSuffixes,
        ucPresetContent: ucContent,
        l10n: context.l10n,
        aliasResolver: aliases,
      ),
    );

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (expand) Expanded(child: positive) else positive,
        SizedBox(width: compact ? 6 : 8),
        if (expand) Expanded(child: negative) else negative,
      ],
    );
  }
}

class PromptTypeButton extends StatefulWidget {
  const PromptTypeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.compact = false,
    this.tooltipBuilder,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  final Widget Function(ThemeData theme)? tooltipBuilder;

  @override
  State<PromptTypeButton> createState() => _PromptTypeButtonState();
}

class _PromptTypeButtonState extends State<PromptTypeButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeInOut));

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _animation.forward(),
        onTapUp: (_) {
          _animation.reverse();
          widget.onTap();
        },
        onTapCancel: _animation.reverse,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.16)
                  : _isHovering
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: widget.compact
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? widget.color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isSelected
                        ? widget.color
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(width: widget.compact ? 5 : 8),
                if (widget.compact)
                  Expanded(child: _label(theme))
                else
                  _label(theme),
                if (widget.count > 0 && !widget.compact) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? widget.color.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? widget.color
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final tooltipBuilder = widget.tooltipBuilder;
    if (tooltipBuilder == null) return button;
    final rich = shouldUseRichPromptTypeTooltip(theme.platform);
    return Tooltip(
      message: rich ? null : widget.label,
      richMessage: rich
          ? WidgetSpan(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: tooltipBuilder(theme),
              ),
            )
          : null,
      preferBelow: true,
      verticalOffset: 20,
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: button,
    );
  }

  Widget _label(ThemeData theme) => Text(
    widget.label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 13,
      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
      color: widget.isSelected
          ? widget.color
          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
      letterSpacing: 0.3,
    ),
  );
}
