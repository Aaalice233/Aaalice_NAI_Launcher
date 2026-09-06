import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../dlss/dlss_enhancement_panel.dart';
import '../../dlss/dlss_preset_editor.dart';
import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/cost_estimate_provider.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import 'img2img_panel_data.dart';

class Img2ImgAdjustmentSection extends ConsumerWidget {
  const Img2ImgAdjustmentSection({super.key, required this.data});
  final Img2ImgPanelData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = data.workflow;
    if (workflow.isEnhance) return _EnhancePanel(workflow: workflow);
    if (workflow.isInpaint) return _InpaintPanel(data: data);
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    return Column(
      children: [
        Img2ImgSlider(
          label: context.l10n.img2img_strength,
          value: data.params.strength,
          hint: context.l10n.img2img_strengthHint,
          onChanged: notifier.updateStrength,
        ),
        const SizedBox(height: 12),
        Img2ImgSlider(
          label: context.l10n.img2img_noise,
          value: data.params.noise,
          hint: context.l10n.img2img_noiseHint,
          onChanged: notifier.updateNoise,
        ),
      ],
    );
  }
}

class _InpaintPanel extends ConsumerWidget {
  const _InpaintPanel({required this.data});
  final Img2ImgPanelData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workflow = data.workflow;
    final generationSize = ref.watch(
      generationParamsNotifierProvider.select(
        (value) => (value.width, value.height),
      ),
    );
    final selection = workflow.focusedSelectionRect;
    final geometry = selection == null
        ? null
        : FocusedInpaintUtils.resolveGeometryForSelection(
            sourceWidth:
                workflow.sourceImageWidth ??
                workflow.sourceWidth ??
                generationSize.$1,
            sourceHeight:
                workflow.sourceImageHeight ??
                workflow.sourceHeight ??
                generationSize.$2,
            selectionRect: selection,
            minContextMegaPixels: workflow.minimumContextMegaPixels,
          );
    final focusedCost = geometry == null
        ? null
        : ref.watch(estimatedCostProvider);
    return _SubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Img2ImgSlider(
            label: context.l10n.img2img_inpaintStrength,
            value: data.params.inpaintStrength,
            hint: context.l10n.img2img_inpaintStrengthHint,
            onChanged: ref
                .read(generationParamsNotifierProvider.notifier)
                .updateInpaintStrength,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.img2img_focusedInpaint,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              workflow.focusedInpaintEnabled && geometry != null
                  ? '${context.l10n.img2img_focusedInpaintEnabledHint}\n${context.l10n.editor_focusRequestSummary(geometry.contextCrop.width, geometry.contextCrop.height, geometry.requestWidth, geometry.requestHeight, focusedCost ?? 0)}'
                  : workflow.focusedInpaintEnabled
                  ? context.l10n.img2img_focusedInpaintEnabledHint
                  : context.l10n.img2img_focusedInpaintDisabledHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: workflow.focusedInpaintEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                workflow.focusedInpaintEnabled
                    ? context.l10n.img2img_enabled
                    : context.l10n.img2img_disabled,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: workflow.focusedInpaintEnabled
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnhancePanel extends ConsumerStatefulWidget {
  const _EnhancePanel({required this.workflow});
  final ImageWorkflowState workflow;
  @override
  ConsumerState<_EnhancePanel> createState() => _EnhancePanelState();
}

class _EnhancePanelState extends ConsumerState<_EnhancePanel> {
  bool _local = false;
  ImageWorkflowState get workflow => widget.workflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    final enhance = workflow.enhance;
    final capabilities = ref.watch(
      generationParamsNotifierProvider.select((value) => value.capabilities),
    );
    final maxAvailable = E2eUpscale.allowsMaxEnhance(
      capabilities,
      sourceWidth: workflow.sourceWidth ?? workflow.baseWidth,
      sourceHeight: workflow.sourceHeight ?? workflow.baseHeight,
    );
    final useMax = enhance.maxScale && maxAvailable;
    return _SubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.img2img_enhance,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (PlatformCapabilities.current.supportsDlssEnhancement) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => SegmentedButton<bool>(
                direction:
                    constraints.maxWidth < 280 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.5
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('NovelAI'),
                    icon: Icon(Icons.cloud_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('DLSSNR'),
                    icon: Icon(Icons.computer_outlined, size: 16),
                  ),
                ],
                selected: {_local},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _local = value.first),
              ),
            ),
          ],
          if (_local) ...[
            const SizedBox(height: 12),
            Text(context.l10n.dlss_description),
            const SizedBox(height: 12),
            const DlssPresetEditor(),
            FilledButton.icon(
              key: const Key('img2img-dlss-enhance'),
              icon: const Icon(Icons.tonality_outlined),
              label: Text(context.l10n.dlss_title),
              onPressed: () async {
                final source = ref
                    .read(generationParamsNotifierProvider)
                    .sourceImage;
                if (source != null) await showDlssEnhancement(context, source);
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.img2img_enhanceHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Img2ImgSlider(
              label: context.l10n.img2img_enhanceMagnitude,
              value: enhance.level.toDouble(),
              min: EnhanceLevels.minLevel.toDouble(),
              max: EnhanceLevels.maxLevel.toDouble(),
              divisions: EnhanceLevels.maxLevel - EnhanceLevels.minLevel,
              valueLabelBuilder: (value) => value.round().toString(),
              onChanged: (value) =>
                  controller.updateEnhanceLevel(value.round()),
            ),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.img2img_enhanceShowIndividualSettings,
                  style: theme.textTheme.bodyMedium,
                ),
                value: enhance.showIndividualSettings,
                onChanged: controller.toggleEnhanceIndividualSettings,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.img2img_enhanceUpscaleAmount,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ...controller.availableEnhanceFactors.reversed.map(
                  (factor) => ChoiceChip(
                    label: Text(
                      factor == factor.roundToDouble()
                          ? '${factor.toStringAsFixed(0)}x'
                          : '${factor.toStringAsFixed(1)}x',
                    ),
                    selected:
                        !useMax && controller.effectiveEnhanceFactor == factor,
                    onSelected: (_) =>
                        controller.updateEnhanceUpscaleFactor(factor),
                  ),
                ),
                if (maxAvailable)
                  ChoiceChip(
                    label: Text(context.l10n.img2img_enhanceScaleMax),
                    selected: useMax,
                    onSelected: (_) => controller.selectEnhanceMaxScale(),
                  ),
              ],
            ),
            if (enhance.showIndividualSettings) ...[
              const SizedBox(height: 12),
              Img2ImgSlider(
                label: context.l10n.img2img_strength,
                value: enhance.strength,
                onChanged: (value) =>
                    controller.updateEnhanceIndividualSettings(strength: value),
              ),
              const SizedBox(height: 12),
              Img2ImgSlider(
                label: context.l10n.img2img_noise,
                value: enhance.noise,
                onChanged: (value) =>
                    controller.updateEnhanceIndividualSettings(noise: value),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class Img2ImgSlider extends StatelessWidget {
  const Img2ImgSlider({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.hint,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabelBuilder,
  });
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final String? hint;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? valueLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              valueLabelBuilder?.call(value) ?? value.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? ((max - min) * 100).round(),
          onChanged: onChanged,
        ),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SubPanel extends StatelessWidget {
  const _SubPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}
