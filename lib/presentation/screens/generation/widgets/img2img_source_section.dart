import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/comfyui/workflow_template.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_picker_card/image_picker_card.dart';
import '../../../utils/comfyui_workflow_l10n.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import 'comfyui_workflow_dialog.dart';
import 'img2img_panel_coordinator.dart';
import 'img2img_panel_data.dart';
import 'img2img_preview_cache.dart';
import 'img2img_source_preview.dart';

class Img2ImgSourceSection extends ConsumerWidget {
  const Img2ImgSourceSection({super.key, required this.data});

  final Img2ImgPanelData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coordinator = ref.read(img2ImgPanelCoordinatorProvider);
    final source = data.sourceImage;
    if (source == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.img2img_sourceImage,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ImagePickerCard(
                  key: const ValueKey('img2img-upload-source'),
                  icon: Icons.upload_file,
                  label: context.l10n.img2img_uploadImage,
                  height: 80,
                  centerHorizontalContent: true,
                  onImageSelected: (bytes, _, _) =>
                      unawaited(coordinator.replaceSource(bytes)),
                  onError: (error) => AppToast.error(
                    context,
                    context.l10n.img2img_selectFailed(error),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ImagePickerCard(
                  key: const ValueKey('img2img-draw-source'),
                  icon: Icons.brush,
                  label: context.l10n.img2img_drawSketch,
                  height: 80,
                  enableDragDrop: false,
                  centerHorizontalContent: true,
                  onTap: () => coordinator.openBlankCanvas(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const Key('img2img-from-precise-ref-library'),
            onPressed: () => coordinator.importSourceFromLibrary(context),
            icon: const Icon(Icons.photo_library_outlined, size: 16),
            label: Text(
              context.l10n.img2img_fromPreciseRefLibrary,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final workflow = data.workflow;
    final dimensions = resolveSourcePreviewDimensions(
      sourceBytes: source,
      sourceWidth: workflow.sourceImageWidth,
      sourceHeight: workflow.sourceImageHeight,
      fallbackWidth: workflow.sourceWidth,
      fallbackHeight: workflow.sourceHeight,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              context.l10n.img2img_sourceImage,
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            _SmallIconButton(
              key: const Key('img2img-save-source-to-library'),
              icon: Icons.bookmark_add_outlined,
              onPressed: () => coordinator.saveSourceToLibrary(context, ref),
              tooltip: context.l10n.preciseRefLib_saveCurrentToLibrary,
            ),
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.refresh,
              onPressed: () => coordinator.pickSource(context),
              tooltip: context.l10n.img2img_changeImage,
            ),
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.close,
              onPressed: coordinator.clear,
              tooltip: context.l10n.img2img_removeImage,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 280,
            child: Img2ImgSourcePreview(
              sourceBytes: source,
              maskBytes: data.maskImage,
              focusedInpaintEnabled:
                  workflow.isInpaint && workflow.focusedInpaintEnabled,
              focusedSelectionRect: workflow.focusedSelectionRect,
              minimumContextMegaPixels: workflow.minimumContextMegaPixels,
              imageWidth: dimensions.$1,
              imageHeight: dimensions.$2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OperationChip(
              icon: Icons.edit_outlined,
              label: context.l10n.img2img_editImage,
              onPressed: () => coordinator.openEditor(
                context,
                ref,
                source,
                ImageEditorMode.edit,
              ),
            ),
            _OperationChip(
              icon: data.isInpaintReady
                  ? Icons.check_circle
                  : Icons.draw_outlined,
              label: context.l10n.img2img_inpaint,
              selected: workflow.isInpaint,
              onPressed: () => coordinator.openEditor(
                context,
                ref,
                source,
                ImageEditorMode.inpaint,
              ),
            ),
            _OperationChip(
              icon: Icons.auto_awesome_motion_outlined,
              label: context.l10n.img2img_generateVariations,
              onPressed: () =>
                  coordinator.generateVariations(context, ref, source),
            ),
            _OperationChip(
              icon: Icons.auto_fix_high_outlined,
              label: context.l10n.img2img_directorTools,
              onPressed: () =>
                  coordinator.openDirectorTools(context, ref, source),
            ),
            _OperationChip(
              icon: workflow.isEnhance
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
              label: context.l10n.img2img_enhance,
              selected: workflow.isEnhance,
              onPressed: () => coordinator.toggleEnhance(workflow),
            ),
            _OperationChip(
              icon: workflow.isUpscale
                  ? Icons.zoom_out_map
                  : Icons.zoom_out_map_rounded,
              label: context.l10n.image_upscale,
              selected: workflow.isUpscale,
              onPressed: () => coordinator.toggleUpscale(workflow),
            ),
            ..._comfyChips(context, ref, source),
          ],
        ),
        if (workflow.isInpaint) ...[
          const SizedBox(height: 10),
          _InpaintStatus(isReady: data.isInpaintReady),
        ],
      ],
    );
  }

  List<Widget> _comfyChips(
    BuildContext context,
    WidgetRef ref,
    Uint8List source,
  ) {
    bool enabled;
    List<WorkflowTemplate> workflows;
    try {
      enabled = ref.watch(
        comfyUISettingsProvider.select((value) => value.enabled),
      );
      workflows = ref.watch(comfyUIWorkflowsProvider);
    } catch (_) {
      return const [];
    }
    if (!enabled) return const [];
    return workflows
        .where(
          (template) =>
              !const {
                comfySeedvr2NativeUpscaleTemplateId,
                comfySeedvr2LegacyUpscaleTemplateId,
                comfySeedvr2LegacyTiledUpscaleTemplateId,
                comfyModelUpscaleTemplateId,
                comfyRtxUpscaleTemplateId,
              }.contains(template.id) &&
              template.requiresInputImage,
        )
        .map(
          (template) => _OperationChip(
            icon: switch (template.category) {
              WorkflowCategory.img2img => Icons.image_outlined,
              WorkflowCategory.inpaint => Icons.draw_outlined,
              WorkflowCategory.enhance => Icons.auto_fix_high_outlined,
              _ => Icons.account_tree_outlined,
            },
            label: template.localizedName(context),
            onPressed: () => ComfyUIWorkflowDialog.show(
              context,
              template: template,
              image: source,
            ),
          ),
        )
        .toList();
  }
}

class _InpaintStatus extends StatelessWidget {
  const _InpaintStatus({required this.isReady});
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isReady
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.tertiaryContainer;
    final foreground = isReady
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isReady
                  ? context.l10n.img2img_inpaintReadyHint
                  : context.l10n.img2img_inpaintPendingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationChip extends StatelessWidget {
  const _OperationChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
