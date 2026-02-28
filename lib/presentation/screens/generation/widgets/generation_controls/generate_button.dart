import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../widgets/anlas/anlas_balance_chip.dart';
import '../../../../widgets/common/themed_button.dart';

/// 集成价格徽章的生成按钮
class GenerateButtonWithCost extends ConsumerWidget {
  final bool isGenerating;
  final bool showCancel;
  final ImageGenerationState generationState;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;

  const GenerateButtonWithCost({
    super.key,
    required this.isGenerating,
    required this.showCancel,
    required this.generationState,
    required this.onGenerate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ThemedButton(
        onPressed: isGenerating ? onCancel : onGenerate,
        icon: showCancel
            ? const Icon(Icons.stop)
            : (isGenerating ? null : const Icon(Icons.auto_awesome)),
        isLoading: isGenerating && !showCancel,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              showCancel
                  ? context.l10n.generation_cancel
                  : (isGenerating
                      ? (generationState.totalImages > 1
                          ? '${generationState.currentImage}/${generationState.totalImages}'
                          : context.l10n.generation_generating)
                      : context.l10n.generation_generate),
            ),
            AnlasCostBadge(isGenerating: isGenerating),
          ],
        ),
        style:
            showCancel ? ThemedButtonStyle.outlined : ThemedButtonStyle.filled,
      ),
    );
  }
}
