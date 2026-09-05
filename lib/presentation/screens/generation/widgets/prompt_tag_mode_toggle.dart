import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/prompt_editor_preferences_provider.dart';

class PromptTagModeToggle extends ConsumerWidget {
  const PromptTagModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(promptTagModeProvider);
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
          onPressed: () =>
              ref.read(promptTagModeProvider.notifier).setEnabled(!enabled),
          style: TextButton.styleFrom(
            minimumSize: const Size(88, 44),
            padding: EdgeInsets.zero,
            shape: const StadiumBorder(),
          ),
          child: ExcludeSemantics(
            child: SizedBox(
              width: 88,
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
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
          size: 18,
          color: enabled ? colors.onSurfaceVariant : colors.onPrimaryContainer,
        ),
      ),
      Expanded(
        child: Icon(
          Icons.sell_outlined,
          size: 18,
          color: enabled ? colors.onTertiaryContainer : colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
