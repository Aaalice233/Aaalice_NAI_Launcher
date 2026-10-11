import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/enums/generation_effort.dart';
import '../../../../core/enums/image_model_mode.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/horizontal_segmented_control.dart';
import 'generation_segmented_toggle.dart';

/// 模型标题行右侧的模式与档位切换，按当前模型能力显示。
class ModelOptionControls extends ConsumerWidget {
  const ModelOptionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          hasFurryMode: params.capabilities.hasFurryMode,
          modelMode: params.modelMode,
          effort: ImageModels.effortOf(params.model),
        ),
      ),
    );
    final effort = data.effort;
    if (!data.hasFurryMode && effort == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return HorizontalSegmentedControl(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8,
        children: [
          if (data.hasFurryMode)
            GenerationSegmentedToggle<ImageModelMode>(
              key: const ValueKey('generation-model-mode'),
              semanticLabel: l10n.generation_modelMode,
              segments: [
                GenerationSegment(
                  value: ImageModelMode.anime,
                  label: l10n.generation_modelModeAnime,
                ),
                GenerationSegment(
                  value: ImageModelMode.furry,
                  label: l10n.generation_modelModeFurry,
                ),
              ],
              selected: data.modelMode,
              onChanged: (mode) => ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateModelMode(mode),
            ),
          if (effort != null)
            GenerationSegmentedToggle<GenerationEffort>(
              key: const ValueKey('generation-effort'),
              semanticLabel: l10n.generation_effort,
              segments: [
                GenerationSegment(
                  value: GenerationEffort.medium,
                  label: l10n.generation_effortMedium,
                ),
                GenerationSegment(
                  value: GenerationEffort.high,
                  label: l10n.generation_effortHigh,
                ),
              ],
              selected: effort,
              onChanged: (value) => ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateEffort(value),
            ),
        ],
      ),
    );
  }
}
