import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/quality_preset_provider.dart';
import '../../../providers/uc_preset_provider.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/rich_tooltip_surface.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';
import 'prompt_input_tooltips.dart';

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
    ref.watch(qualityPresetNotifierProvider);
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

    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.promptController,
        controller.negativeController,
      ]),
      builder: (context, _) {
        final positive = PromptTypeButton(
          key: const ValueKey('generation_prompt_positive_mode'),
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
            qualityContent: qualityContent,
            characters: characters.characters,
            globalAiChoice: characters.globalAiChoice,
            l10n: context.l10n,
            aliasResolver: aliases,
          ),
        );
        final negative = PromptTypeButton(
          key: const ValueKey('generation_prompt_negative_mode'),
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

        return SizedBox(
          key: const ValueKey('generation_prompt_type_switch'),
          width: expand ? double.infinity : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (expand) Expanded(child: positive) else positive,
              SizedBox(width: compact ? 6 : 8),
              if (expand) Expanded(child: negative) else negative,
            ],
          ),
        );
      },
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) {
          if (!disableAnimations) _animation.forward();
        },
        onTapUp: (_) {
          if (!disableAnimations) _animation.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          if (!disableAnimations) _animation.reverse();
        },
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: disableAnimations ? 1 : _scale.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: transitionDuration,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 6 : 14,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fillsAvailableWidth =
                    widget.compact && constraints.hasBoundedWidth;
                final label = _label(theme);
                return Row(
                  mainAxisSize: fillsAvailableWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: transitionDuration,
                      padding: EdgeInsets.all(widget.compact ? 2 : 4),
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
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                    SizedBox(width: widget.compact ? 4 : 8),
                    if (fillsAvailableWidth) Flexible(child: label) else label,
                    SizedBox(width: widget.compact ? 3 : 6),
                    PromptTagCountBadge(
                      count: widget.count,
                      selected: widget.isSelected,
                      color: widget.color,
                      compact: widget.compact,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    final tooltipBuilder = widget.tooltipBuilder;
    if (tooltipBuilder == null) return button;
    final rich = context.interactionPolicy.precisePointerAvailable;
    return Tooltip(
      message: rich ? null : widget.label,
      richMessage: rich
          ? WidgetSpan(
              child: RichTooltipSurface(
                maxWidth: 420,
                child: tooltipBuilder(theme),
              ),
            )
          : null,
      preferBelow: true,
      verticalOffset: 20,
      waitDuration: const Duration(milliseconds: 300),
      exitDuration: rich ? const Duration(milliseconds: 300) : null,
      enableTapToDismiss: !rich,
      ignorePointer: false,
      decoration: richTooltipOuterDecoration,
      padding: EdgeInsets.zero,
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

class PromptTagCountBadge extends StatelessWidget {
  const PromptTagCountBadge({
    super.key,
    required this.count,
    required this.selected,
    required this.color,
    this.compact = false,
  });

  final int count;
  final bool selected;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.2)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: selected ? color : colors.onSurface.withValues(alpha: 0.6),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
