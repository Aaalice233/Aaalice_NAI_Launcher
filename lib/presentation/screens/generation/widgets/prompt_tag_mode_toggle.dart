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
    return Semantics(
      toggled: enabled,
      child: TextButton.icon(
        key: const ValueKey('tag-mode-button'),
        onPressed: () =>
            ref.read(promptTagModeProvider.notifier).setEnabled(!enabled),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: enabled ? colors.primary : colors.onSurfaceVariant,
          backgroundColor: enabled
              ? colors.surfaceContainerHigh
              : Colors.transparent,
        ),
        icon: Icon(enabled ? Icons.sell : Icons.sell_outlined, size: 18),
        label: Text(context.l10n.tagMode_label),
      ),
    );
  }
}
