import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/generation/generation_panel_expansion_provider.dart';
import '../../../providers/generation/generation_params_selectors.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../providers/generation/novel_ai_upscale_task_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/themed_divider.dart';
import 'img2img_adjustment_section.dart';
import 'img2img_panel_coordinator.dart';
import 'img2img_panel_data.dart';
import 'img2img_source_section.dart';
import 'img2img_upscale_section.dart';

/// Provider shell for the image-to-image workbench.
///
/// The public API intentionally remains constructor-only so existing callers
/// and selectors keep their rebuild behavior.
class Img2ImgPanel extends ConsumerStatefulWidget {
  const Img2ImgPanel({super.key});

  @override
  ConsumerState<Img2ImgPanel> createState() => _Img2ImgPanelState();
}

class _Img2ImgPanelState extends ConsumerState<Img2ImgPanel> {
  @override
  Widget build(BuildContext context) {
    ref.listen<NovelAiUpscaleTaskState>(novelAiUpscaleTaskProvider, (
      previous,
      next,
    ) {
      if (previous?.isRunning != true) return;
      if (next.status == NovelAiUpscaleTaskStatus.completed) {
        AppToast.success(context, context.l10n.img2img_novelAiUpscaleComplete);
      } else if (next.status == NovelAiUpscaleTaskStatus.failed &&
          next.errorMessage != null) {
        AppToast.error(context, next.errorMessage!);
      }
    });

    final params = ref.watch(
      generationParamsNotifierProvider.select(selectImg2ImgPanelViewData),
    );
    final workflow = ref.watch(imageWorkflowControllerProvider);
    final data = Img2ImgPanelData(params: params, workflow: workflow);
    final isExpanded = ref.watch(
      generationPanelExpansionProvider.select(
        (value) => value.isExpanded(GenerationWorkbenchPanel.img2img),
      ),
    );
    final theme = Theme.of(context);
    final showBackground = data.hasSourceImage && !isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.img2img_title,
      icon: Icons.image,
      isExpanded: isExpanded,
      onToggle: () => ref
          .read(imageWorkflowControllerProvider.notifier)
          .setPanelExpanded(!isExpanded),
      hasData: data.hasSourceImage,
      backgroundImage: data.hasSourceImage
          ? DecodedMemoryImage(
              bytes: data.sourceImage!,
              fit: BoxFit.cover,
              decodeScale: 0.5,
            )
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withValues(alpha: 0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.img2img_enabled,
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      childBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            Img2ImgSourceSection(data: data),
            if (data.hasSourceImage) ...[
              const SizedBox(height: 16),
              if (workflow.isUpscale)
                Img2ImgUpscaleSection(workflow: workflow)
              else
                Img2ImgAdjustmentSection(data: data),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: ref.read(img2ImgPanelCoordinatorProvider).clear,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(context.l10n.img2img_clearSettings),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
