import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// 抽卡模式开关
class RandomModeToggle extends ConsumerStatefulWidget {
  final bool enabled;
  final bool compact;
  final bool showLabel;

  const RandomModeToggle({
    super.key,
    required this.enabled,
    this.compact = false,
    this.showLabel = false,
  });

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
    final trackWidth = widget.compact ? 36.0 : 52.0;
    final trackHeight = widget.compact ? 24.0 : 30.0;
    final thumbExtent = trackHeight - 6;
    final tooltip = widget.enabled
        ? context.l10n.randomMode_enabledTip
        : context.l10n.randomMode_disabledTip;
    final trackColor = widget.enabled
        ? colors.primaryContainer
        : colors.surfaceContainerHigh;
    final switchTrack = AnimatedContainer(
      key: const ValueKey('random-mode-switch-track'),
      width: trackWidth,
      height: trackHeight,
      padding: const EdgeInsets.all(3),
      duration: duration,
      curve: theme.appTheme.standardCurve,
      decoration: BoxDecoration(
        color: _hovered
            ? Color.alphaBlend(
                colors.onSurface.withValues(alpha: 0.06),
                trackColor,
              )
            : trackColor,
        borderRadius: BorderRadius.circular(trackHeight / 2),
      ),
      child: AnimatedAlign(
        key: const ValueKey('random-mode-switch-thumb-position'),
        alignment: widget.enabled
            ? Alignment.centerRight
            : Alignment.centerLeft,
        duration: duration,
        curve: theme.appTheme.standardCurve,
        child: AnimatedContainer(
          key: const ValueKey('random-mode-switch-thumb'),
          width: thumbExtent,
          height: thumbExtent,
          duration: duration,
          curve: theme.appTheme.standardCurve,
          decoration: BoxDecoration(
            color: widget.enabled
                ? colors.primary
                : colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: theme.appTheme.enterCurve,
            switchOutCurve: theme.appTheme.exitCurve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Icon(
              widget.enabled ? Icons.casino_rounded : Icons.casino_outlined,
              key: ValueKey(widget.enabled),
              size: widget.compact ? 15 : 16,
              color: widget.enabled
                  ? colors.onPrimary
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );

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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.read(randomPromptModeProvider.notifier).toggle(),
              customBorder: const StadiumBorder(),
              child: widget.showLabel
                  ? ConstrainedBox(
                      constraints: BoxConstraints(minHeight: controlExtent),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            switchTrack,
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                context.l10n.toolbar_randomPrompt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      width: widget.compact ? trackWidth : 52,
                      height: controlExtent,
                      child: Center(child: switchTrack),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
