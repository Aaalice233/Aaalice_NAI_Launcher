import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/interaction_policy.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_state_provider.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../widgets/prompt/prompt_viewport_actions.dart';
import '../../../themes/core/layered_surface_style.dart';

/// The assistant overlays the editor without changing its text layout.
class PromptInputAssistant extends ConsumerWidget {
  const PromptInputAssistant({
    super.key,
    required this.sessionId,
    required this.controller,
    required this.onChanged,
    required this.onOpenSettings,
  });

  final String sessionId;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(promptAssistantConfigProvider);
    final policy = context.interactionPolicy;
    if (!config.enabled ||
        (policy.usesAnchoredMenus && !config.desktopOverlayEnabled)) {
      return const SizedBox.shrink();
    }
    final expanded = ref.watch(
      promptAssistantStateProvider.select(
        (states) => states[sessionId]?.expanded ?? false,
      ),
    );
    final height = PromptAssistantOverlay.effectiveInlineToolbarHeight(
      policy,
    ).clamp(44.0, double.infinity);
    return PromptViewportActions(
      child: SizedBox(
        width: expanded
            ? PromptAssistantOverlay.expandedInlineToolbarWidth(policy)
            : height,
        height: height,
        child: Material(
          key: ValueKey('generation_prompt_assistant_$sessionId'),
          color: expanded
              ? overlaySurfaceColor(Theme.of(context).colorScheme)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: PromptAssistantOverlay(
            sessionId: sessionId,
            controller: controller,
            onChanged: onChanged,
            onOpenSettings: onOpenSettings,
            supportsTagMode: true,
            iconOnly: true,
            floatOverEditor: false,
            interactionPolicy: policy,
          ),
        ),
      ),
    );
  }
}
