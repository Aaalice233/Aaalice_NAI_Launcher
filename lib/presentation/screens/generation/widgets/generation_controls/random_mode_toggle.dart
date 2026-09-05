import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// 抽卡模式状态按钮。
class RandomModeToggle extends ConsumerStatefulWidget {
  const RandomModeToggle({
    super.key,
    required this.enabled,
    this.compact = false,
  });

  final bool enabled;
  final bool compact;

  @override
  ConsumerState<RandomModeToggle> createState() => _RandomModeToggleState();
}

class _RandomModeToggleState extends ConsumerState<RandomModeToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : theme.appTheme.fastDuration;
    final controlExtent = widget.compact
        ? 36.0
        : context.interactionPolicy.minimumControlExtent;
    final tooltip = widget.enabled
        ? context.l10n.randomMode_enabledTip
        : context.l10n.randomMode_disabledTip;
    final baseColor = widget.enabled
        ? colors.primaryContainer
        : Colors.transparent;
    final backgroundColor = _hovered
        ? Color.alphaBlend(colors.onSurface.withValues(alpha: 0.07), baseColor)
        : baseColor;

    return Semantics(
      button: true,
      toggled: widget.enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            key: const ValueKey('random-mode-button-surface'),
            width: controlExtent,
            height: controlExtent,
            duration: duration,
            curve: theme.appTheme.standardCurve,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(widget.compact ? 10 : 13),
            ),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.compact ? 10 : 13),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    ref.read(randomPromptModeProvider.notifier).toggle(),
                child: Center(
                  child: AnimatedRotation(
                    key: const ValueKey('random-mode-dice-rotation'),
                    turns: widget.enabled ? 0.125 : 0,
                    duration: duration,
                    curve: theme.appTheme.enterCurve,
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: theme.appTheme.enterCurve,
                      switchOutCurve: theme.appTheme.exitCurve,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Icon(
                        widget.enabled
                            ? Icons.casino_rounded
                            : Icons.casino_outlined,
                        key: ValueKey(widget.enabled),
                        size: widget.compact ? 19 : 22,
                        color: widget.enabled
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
