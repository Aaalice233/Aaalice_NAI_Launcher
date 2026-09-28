import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/prompt_editor_preferences_provider.dart';
import 'prompt_footer_style.dart';

class PromptTagModeToggle extends ConsumerWidget {
  const PromptTagModeToggle({
    super.key,
    required this.sessionId,
    this.enabled = true,
  });

  final Object sessionId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(promptTagModeProvider(sessionId));
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final tooltip = enabled
        ? context.l10n.tagMode_exit
        : context.l10n.tagMode_enter;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        toggled: enabled,
        label: context.l10n.tagMode_label,
        child: TextButton(
          key: const ValueKey('tag-mode-button'),
          onPressed: this.enabled || enabled
              ? () {
                  ref
                      .read(promptTagModeProvider(sessionId).notifier)
                      .setEnabled(!enabled);
                }
              : null,
          style: PromptFooterStyle.button(context, width: 88).copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.all(3)),
            backgroundColor: WidgetStatePropertyAll(
              colors.surfaceContainerHigh,
            ),
          ),
          child: ExcludeSemantics(
            child: SizedBox(
              width: 82,
              height: PromptFooterStyle.height(context) - 6,
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    alignment: enabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: AnimatedContainer(
                        key: const ValueKey('tag-mode-thumb'),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: enabled
                              ? colors.tertiaryContainer
                              : colors.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: _modeIcons(colors, enabled)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeIcons(ColorScheme colors, bool enabled) => Row(
    children: [
      Expanded(
        child: Icon(
          Icons.text_fields,
          size: PromptFooterStyle.iconSize,
          color: enabled ? colors.onSurfaceVariant : colors.onPrimaryContainer,
        ),
      ),
      Expanded(
        child: Icon(
          Icons.sell_outlined,
          size: PromptFooterStyle.iconSize,
          color: enabled ? colors.onTertiaryContainer : colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
