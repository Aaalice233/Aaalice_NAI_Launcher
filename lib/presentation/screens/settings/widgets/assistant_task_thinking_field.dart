import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../prompt_assistant/models/assistant_execution_settings.dart';
import '../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';

class AssistantTaskThinkingField extends StatelessWidget {
  const AssistantTaskThinkingField({
    super.key,
    required this.task,
    required this.provider,
    required this.model,
    required this.value,
    required this.onChanged,
  });

  final AssistantTaskType task;
  final ProviderConfig? provider;
  final String? model;
  final AssistantThinkingLevel value;
  final ValueChanged<AssistantThinkingLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final metadata = provider == null || model == null
        ? AssistantModelMetadata.unknown
        : AssistantModelCatalog.resolveProvider(
            provider: provider!,
            model: model!,
          );
    final supported = metadata.selectableThinkingLevels
        .map((level) => level.name)
        .toSet();
    final choices = AssistantThinkingLevel.values
        .where(
          (level) =>
              level == AssistantThinkingLevel.automatic ||
              supported.contains(level.name),
        )
        .toList();
    final selected = choices.contains(value)
        ? value
        : AssistantThinkingLevel.automatic;
    final l10n = context.l10n;
    String label(AssistantThinkingLevel level) => switch (level) {
      AssistantThinkingLevel.automatic => l10n.promptAssistant_thinkingDefault,
      AssistantThinkingLevel.off => l10n.agentChat_reasoningOff,
      AssistantThinkingLevel.minimal => l10n.agentChat_reasoningMinimal,
      AssistantThinkingLevel.low => l10n.agentChat_reasoningLow,
      AssistantThinkingLevel.medium => l10n.agentChat_reasoningMedium,
      AssistantThinkingLevel.high =>
        metadata.thinkingIsToggle
            ? l10n.promptAssistant_thinkingEnabled
            : l10n.agentChat_reasoningHigh,
      AssistantThinkingLevel.xhigh => l10n.agentChat_reasoningXHigh,
      AssistantThinkingLevel.max => l10n.agentChat_reasoningMax,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AssistantThinkingLevel>(
          key: ValueKey(
            'assistant-thinking-${task.name}-${provider?.id}-$model-${selected.name}',
          ),
          initialValue: selected,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: l10n.promptAssistant_thinkingLevel,
          ),
          items: [
            for (final level in choices)
              DropdownMenuItem(value: level, child: Text(label(level))),
          ],
          onChanged: supported.isEmpty
              ? null
              : (level) {
                  if (level != null) onChanged(level);
                },
        ),
        if (supported.isEmpty || selected != value) ...[
          const SizedBox(height: 6),
          Text(
            supported.isEmpty
                ? l10n.promptAssistant_thinkingUnavailable
                : l10n.promptAssistant_thinkingReset,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
