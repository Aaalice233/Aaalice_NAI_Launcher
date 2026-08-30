import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart'
    show ImageParamsExtension;
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_token_counter_provider.dart';
import '../../../widgets/prompt/prompt_token_count_bar.dart';
import 'generation_toggle_button.dart';

class PromptInputFooter extends ConsumerWidget {
  const PromptInputFooter({
    super.key,
    required this.target,
    required this.topPadding,
    this.leading,
    this.assistant,
    this.assistantExpanded = false,
    this.assistantCollapsedWidth = 0,
  });

  final PromptTokenCountTarget target;
  final double topPadding;
  final Widget? leading;
  final Widget? assistant;
  final bool assistantExpanded;
  final double assistantCollapsedWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokenUsage = ref.watch(promptTokenUsageProvider(target));
    final transparentBackground = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          supported: params.capabilities.supportsTransparentBackground,
          enabled: params.transparentBackground,
        ),
      ),
    );
    final showTransparentBackground =
        target == PromptTokenCountTarget.positive &&
        transparentBackground.supported;

    final tokenCount = RepaintBoundary(
      key: const ValueKey('generation_prompt_footer_count'),
      child: PromptTokenCountAsyncBar(usage: tokenUsage),
    );

    return Padding(
      key: const ValueKey('generation_prompt_footer'),
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        children: [
          if (showTransparentBackground) ...[
            Tooltip(
              richMessage: WidgetSpan(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.qualityTags_addToEnd,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ', ${QualityTags.transparentBackgroundTag}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              preferBelow: true,
              verticalOffset: 20,
              waitDuration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: GenerationToggleButton(
                key: const ValueKey('generation_transparent_background_toggle'),
                label: context.l10n.generation_transparentBackground,
                isEnabled: transparentBackground.enabled,
                onChanged: (value) => ref
                    .read(generationParamsNotifierProvider.notifier)
                    .updateTransparentBackground(value),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          if (assistant == null)
            Expanded(child: tokenCount)
          else
            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Positioned.fill(
                    right: assistantCollapsedWidth + 8,
                    child: Offstage(
                      offstage: assistantExpanded,
                      child: tokenCount,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: KeyedSubtree(
                      key: const ValueKey('generation_prompt_footer_assistant'),
                      child: assistant!,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
