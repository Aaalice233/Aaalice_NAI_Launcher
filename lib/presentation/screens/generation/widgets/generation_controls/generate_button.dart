import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_button.dart';
import 'package:nai_launcher/presentation/widgets/common/anlas_cost_badge.dart';

/// 集成价格徽章的生成按钮
class GenerateButtonWithCost extends ConsumerWidget {
  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onSkipCurrent;

  /// 按钮高度（紧凑布局可压低）
  final double height;

  const GenerateButtonWithCost({
    super.key,
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    required this.onGenerate,
    required this.onCancel,
    required this.onSkipCurrent,
    this.height = 48,
  });

  bool get _canSkipCurrentBatch =>
      showCancel &&
      generationState.currentImage > 0 &&
      generationState.totalImages > generationState.currentImage;

  String _progressText() =>
      '${generationState.currentImage}/${generationState.totalImages}';

  String _generateLabelText(BuildContext context) {
    if (isGenerating) {
      return generationState.totalImages > 1
          ? _progressText()
          : context.l10n.generation_generating;
    }
    return context.l10n.generation_generate;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showCancel) {
      return SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canSkipCurrentBatch) ...[
              ThemedButton(
                onPressed: onSkipCurrent,
                icon: const Icon(Icons.skip_next),
                label: Text(
                  '${context.l10n.generation_skipCurrentBatch} ${_progressText()}',
                ),
                style: ThemedButtonStyle.outlined,
              ),
              const SizedBox(width: 8),
            ],
            ThemedButton(
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(context.l10n.generation_stopAllGeneration),
              style: ThemedButtonStyle.outlined,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ThemedButton(
        onPressed: isGenerating ? null : onGenerate,
        icon: isGenerating ? null : const Icon(Icons.auto_awesome),
        isLoading: isGenerating,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_generateLabelText(context)),
            AnlasCostBadge(isGenerating: isGenerating),
          ],
        ),
        style: ThemedButtonStyle.filled,
      ),
    );
  }
}
