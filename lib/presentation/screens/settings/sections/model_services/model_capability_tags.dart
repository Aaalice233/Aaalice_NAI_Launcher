import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../prompt_assistant/models/assistant_model_capability.dart';

/// 能力只来自内置目录；目录认不出的模型不显示任何标签，而不是猜测。
class ModelCapabilityTags extends StatelessWidget {
  const ModelCapabilityTags({
    super.key,
    required this.provider,
    required this.modelId,
  });

  final ProviderConfig provider;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metadata = AssistantModelCatalog.resolveProvider(
      provider: provider,
      model: modelId,
    );
    final profile = AssistantModelCatalog.catalogProfile(
      provider: provider,
      model: modelId,
    );
    final tags = <(IconData, String)>[
      if (metadata.reasoning)
        (Icons.psychology_outlined, l10n.modelServices_reasoning),
      if (profile?.imageInput ?? false)
        (Icons.image_outlined, l10n.modelServices_vision),
      if (metadata.contextWindow > 0)
        (
          Icons.notes_rounded,
          l10n.modelServices_contextWindow(
            formatContextWindow(metadata.contextWindow),
          ),
        ),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (icon, label) in tags)
          _CapabilityTag(icon: icon, label: label),
      ],
    );
  }
}

/// 按十进制取整：目录里同时有 128000 与 131072 这类写法，统一成用户熟悉的 K/M。
String formatContextWindow(int tokens) {
  if (tokens >= 1000000) {
    final millions = tokens / 1000000;
    final rounded = (millions * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}M'
        : '${rounded}M';
  }
  if (tokens >= 1000) return '${(tokens / 1000).round()}K';
  return '$tokens';
}

class _CapabilityTag extends StatelessWidget {
  const _CapabilityTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
