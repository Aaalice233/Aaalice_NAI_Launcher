import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import '../../../../core/comfyui/comfyui_models.dart';
import '../../../../core/comfyui/seedvr2_support.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../providers/dlss_provider.dart';
import '../../../providers/generation/dlss_upscale_task_provider.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../providers/generation/novel_ai_upscale_task_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/anlas_cost_badge.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/editable_double_field.dart';
import 'img2img_upscale_coordinator.dart';
import 'img2img_dlss_upscale_controls.dart';

class Img2ImgUpscaleSection extends ConsumerStatefulWidget {
  const Img2ImgUpscaleSection({super.key, required this.workflow});
  final ImageWorkflowState workflow;

  @override
  ConsumerState<Img2ImgUpscaleSection> createState() =>
      _Img2ImgUpscaleSectionState();
}

class _Img2ImgUpscaleSectionState extends ConsumerState<Img2ImgUpscaleSection> {
  final Set<String> _persistedResolutions = {};
  bool _persistScheduled = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<List<String>>(
      comfyUISeedvr2ModelsProvider,
      (_, __) => _schedulePersistResolvedModel(),
      fireImmediately: true,
    );
    ref.listenManual<ImageWorkflowState>(
      imageWorkflowControllerProvider,
      (_, __) => _schedulePersistResolvedModel(),
    );
  }

  void _schedulePersistResolvedModel() {
    if (_persistScheduled) return;
    _persistScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistScheduled = false;
      if (mounted) _persistResolvedModelOnce();
    });
  }

  void _persistResolvedModelOnce() {
    final workflow = ref.read(imageWorkflowControllerProvider);
    final settings = workflow.upscale;
    if (settings.backend != UpscaleBackend.comfyui ||
        settings.comfyModule == ComfyUpscaleModule.rtx) {
      return;
    }
    final notifier = ref.read(comfyUISeedvr2ModelsProvider.notifier);
    final backend = settings.comfyModule == ComfyUpscaleModule.seedvr2
        ? notifier.capabilities.resolveBackend(settings.seedvr2Engine)
        : null;
    final models = settings.comfyModule == ComfyUpscaleModule.seedvr2
        ? notifier.capabilities.modelsForBackend(backend)
        : filterComfyUpscaleModelsForModule(
            ref.read(comfyUISeedvr2ModelsProvider),
            module: settings.comfyModule,
          );
    final current = settings.comfyModelForModule(
      settings.comfyModule,
      seedvr2Backend: backend,
    );
    final resolved = resolveComfyUpscaleModelForModule(
      models,
      module: settings.comfyModule,
      currentModel: current,
    );
    if (resolved == null ||
        !shouldAutoPersistResolvedUpscaleModel(
          isComfyBackend: true,
          hasFetchedFromServer: notifier.hasFetchedFromServer,
          availableModels: models,
          currentModel: current,
          resolvedModel: resolved,
        )) {
      return;
    }
    final signature = '${settings.comfyModule.name}:${backend?.name}:$resolved';
    if (_persistedResolutions.add(signature)) {
      ref
          .read(imageWorkflowControllerProvider.notifier)
          .updateUpscaleComfyModel(resolved, seedvr2Backend: backend);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workflow = widget.workflow;
    final settings = workflow.upscale;
    final controller = ref.read(imageWorkflowControllerProvider.notifier);
    final comfyEnabled = ref.watch(
      comfyUISettingsProvider.select((value) => value.enabled),
    );
    final task = ref.watch(comfyUITaskProvider);
    final taskError = task.localizedError(context.l10n);
    final naiTask = ref.watch(novelAiUpscaleTaskProvider);
    final hasSource = ref.watch(
      generationParamsNotifierProvider.select(
        (value) => value.sourceImage != null,
      ),
    );
    final isNai = settings.backend == UpscaleBackend.novelai;
    final isSr = settings.backend == UpscaleBackend.dlssSr;
    final supportsSr =
        PlatformCapabilities.operatingSystem.supportsDlssEnhancement;
    final srRunning = isSr && ref.watch(dlssUpscaleTaskProvider).running;
    final capabilities = ref
        .read(comfyUISeedvr2ModelsProvider.notifier)
        .capabilities;
    final backend = settings.comfyModule == ComfyUpscaleModule.seedvr2
        ? capabilities.resolveBackend(settings.seedvr2Engine)
        : null;
    final allModels = ref.watch(comfyUISeedvr2ModelsProvider);
    final moduleModels = settings.comfyModule == ComfyUpscaleModule.seedvr2
        ? capabilities.modelsForBackend(backend)
        : filterComfyUpscaleModelsForModule(
            allModels,
            module: settings.comfyModule,
          );
    final currentModel = settings.comfyModelForModule(
      settings.comfyModule,
      seedvr2Backend: backend,
    );
    final resolvedModel = resolveComfyUpscaleModelForModule(
      moduleModels,
      module: settings.comfyModule,
      currentModel: currentModel,
    );
    final canStart = isNai
        ? hasSource && !naiTask.isRunning
        : isSr
        ? supportsSr &&
              hasSource &&
              !srRunning &&
              ref.watch(dlssProvider).enabled &&
              ref.watch(dlssProvider).options.nativeScale > 1
        : comfyEnabled &&
              hasSource &&
              !task.isRunning &&
              (settings.comfyModule == ComfyUpscaleModule.rtx ||
                  resolvedModel != null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.image_upscale,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => SegmentedButton<UpscaleBackend>(
              direction:
                  constraints.maxWidth < 420 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: [
                const ButtonSegment(
                  value: UpscaleBackend.novelai,
                  label: Text('NovelAI'),
                  icon: Icon(Icons.cloud_outlined, size: 16),
                ),
                ButtonSegment(
                  value: UpscaleBackend.comfyui,
                  label: const Text('ComfyUI'),
                  icon: const Icon(Icons.computer, size: 16),
                  enabled: comfyEnabled,
                ),
                if (supportsSr || isSr)
                  ButtonSegment(
                    value: UpscaleBackend.dlssSr,
                    label: const Text('DLSS SR'),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    enabled: supportsSr,
                  ),
              ],
              selected: {settings.backend},
              onSelectionChanged: (value) =>
                  controller.updateUpscaleBackend(value.first),
              showSelectedIcon: false,
              style: _compactButtonStyle,
            ),
          ),
          const SizedBox(height: 12),
          if (isNai)
            Text(
              context.l10n.img2img_novelAiCloudUpscale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (isSr)
            const Img2ImgDlssUpscaleControls()
          else if (!comfyEnabled)
            Text(
              context.l10n.img2img_comfyuiEnableHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else ...[
            Text(
              context.l10n.img2img_upscaleMode,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            SegmentedButton<ComfyUpscaleModule>(
              segments: [
                ButtonSegment(
                  value: ComfyUpscaleModule.regular,
                  label: Text(context.l10n.img2img_upscaleRegularModel),
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                ),
                const ButtonSegment(
                  value: ComfyUpscaleModule.seedvr2,
                  label: Text('SeedVR2'),
                  icon: Icon(Icons.video_settings_outlined, size: 16),
                ),
                const ButtonSegment(
                  value: ComfyUpscaleModule.rtx,
                  label: Text('RTX'),
                  icon: Icon(Icons.memory_outlined, size: 16),
                ),
              ],
              selected: {settings.comfyModule},
              onSelectionChanged: (value) =>
                  controller.updateComfyUpscaleModule(value.first),
              showSelectedIcon: false,
              style: _compactButtonStyle,
            ),
            const SizedBox(height: 12),
            _UpscaleMetrics(module: settings.comfyModule),
            const SizedBox(height: 12),
            if (settings.comfyModule != ComfyUpscaleModule.rtx) ...[
              Text(
                context.l10n.img2img_upscaleModel,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'upscale_model_${settings.comfyModule.name}_${moduleModels.length}',
                ),
                initialValue: moduleModels.contains(resolvedModel)
                    ? resolvedModel
                    : null,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                items: moduleModels
                    .map(
                      (model) => DropdownMenuItem(
                        value: model,
                        child: Text(
                          _friendlyName(model),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: moduleModels.isEmpty
                    ? null
                    : (model) {
                        if (model != null) {
                          controller.updateUpscaleComfyModel(
                            model,
                            seedvr2Backend: backend,
                          );
                        }
                      },
              ),
              if (moduleModels.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  settings.comfyModule == ComfyUpscaleModule.seedvr2
                      ? context.l10n.img2img_noSeedvr2Models
                      : context.l10n.img2img_noRegularUpscaleModels,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(comfyUISeedvr2ModelsProvider.notifier)
                      .fetch(force: true),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(
                    context.l10n.img2img_refreshModelList,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ],
            Text(
              _workflowHint(
                context,
                settings.comfyModule,
                backend,
                capabilities,
                settings,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _ScaleControl(settings: settings, controller: controller),
            if (settings.comfyModule == ComfyUpscaleModule.seedvr2) ...[
              const SizedBox(height: 8),
              _SeedVr2Controls(
                settings: settings,
                controller: controller,
                capabilities: capabilities,
                backend: backend,
              ),
            ],
            if (task.isRunning) ...[
              const SizedBox(height: 8),
              if (task.hasPreview) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImageViewportSurface(
                    child: Image.memory(
                      task.previewImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const LinearProgressIndicator(),
            ] else if (task.status == ComfyUITaskStatus.failed &&
                taskError != null)
              Text(
                taskError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
          if (naiTask.isRunning) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else if (isNai &&
              naiTask.status == NovelAiUpscaleTaskStatus.failed &&
              naiTask.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              naiTask.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canStart ? _run : null,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.img2img_startUpscale),
                if (isNai)
                  AnlasCostBadge(
                    key: const ValueKey('upscale_anlas_cost_badge'),
                    isGenerating: naiTask.isRunning,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run() async {
    final result = await ref.read(img2ImgUpscaleCoordinatorProvider).run();
    if (!mounted ||
        result is Img2ImgUpscaleSuccess &&
            (result.kind == Img2ImgUpscaleKind.novelAi ||
                result.kind == Img2ImgUpscaleKind.dlssSr)) {
      return;
    }
    if (result case Img2ImgUpscaleSuccess(
      :final kind,
      :final width,
      :final height,
    )) {
      final message = switch (kind) {
        Img2ImgUpscaleKind.regular =>
          context.l10n.img2img_regularUpscaleComplete(width!, height!),
        Img2ImgUpscaleKind.rtx => context.l10n.img2img_rtxUpscaleComplete(
          width!,
          height!,
        ),
        _ => context.l10n.img2img_upscaleComplete(width!, height!),
      };
      AppToast.success(context, message);
    } else if (result case Img2ImgUpscaleRejected(:final reason)) {
      final message = switch (reason) {
        Img2ImgUpscaleFailure.engineUnavailable ||
        Img2ImgUpscaleFailure.nativeVaeUnavailable =>
          context.l10n.img2img_seedvr2EngineUnavailable,
        Img2ImgUpscaleFailure.regularModelUnavailable =>
          context.l10n.img2img_noAvailableRegularUpscaleModel,
        Img2ImgUpscaleFailure.seedVr2ModelUnavailable =>
          context.l10n.img2img_noAvailableSeedvr2Model,
        Img2ImgUpscaleFailure.sourceDecodeFailed =>
          context.l10n.img2img_decodeSourceFailed,
        Img2ImgUpscaleFailure.sourceMissing ||
        Img2ImgUpscaleFailure.noResult => null,
      };
      if (message != null) AppToast.error(context, message);
    }
  }

  static const _compactButtonStyle = ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static String _friendlyName(String filename) => filename
      .replaceAll('.safetensors', '')
      .replaceAll('.ckpt', '')
      .replaceAll('.pth', '')
      .replaceAll('.pt', '');

  String _workflowHint(
    BuildContext context,
    ComfyUpscaleModule module,
    ComfySeedvr2Backend? backend,
    ComfySeedvr2Capabilities capabilities,
    UpscaleWorkflowSettings settings,
  ) => switch (module) {
    ComfyUpscaleModule.seedvr2 when backend == ComfySeedvr2Backend.native =>
      context.l10n.img2img_useNativeSeedvr2Workflow,
    ComfyUpscaleModule.seedvr2
        when backend == ComfySeedvr2Backend.legacy &&
            capabilities.legacyTilingAvailable &&
            settings.seedvr2Tiled =>
      context.l10n.img2img_useSeedvr2TiledWorkflow,
    ComfyUpscaleModule.seedvr2 => context.l10n.img2img_useSeedvr2Workflow,
    ComfyUpscaleModule.regular =>
      context.l10n.img2img_useRegularUpscaleWorkflow,
    ComfyUpscaleModule.rtx => context.l10n.img2img_useRtxUpscaleWorkflow,
  };
}

class _ScaleControl extends StatelessWidget {
  const _ScaleControl({required this.settings, required this.controller});
  final UpscaleWorkflowSettings settings;
  final ImageWorkflowController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = settings.comfyScale.clamp(
      UpscaleWorkflowSettings.minScale,
      UpscaleWorkflowSettings.maxScale,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.upscale_scale,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            EditableDoubleField(
              value: value,
              min: UpscaleWorkflowSettings.minScale,
              max: UpscaleWorkflowSettings.maxScale,
              decimals: 1,
              width: 60,
              onChanged: controller.updateUpscaleComfyScale,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: UpscaleWorkflowSettings.minScale,
            max: UpscaleWorkflowSettings.maxScale,
            divisions: 10,
            onChanged: controller.updateUpscaleComfyScale,
          ),
        ),
      ],
    );
  }
}

class _SeedVr2Controls extends StatelessWidget {
  const _SeedVr2Controls({
    required this.settings,
    required this.controller,
    required this.capabilities,
    required this.backend,
  });
  final UpscaleWorkflowSettings settings;
  final ImageWorkflowController controller;
  final ComfySeedvr2Capabilities capabilities;
  final ComfySeedvr2Backend? backend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.img2img_seedvr2Engine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        SegmentedButton<ComfySeedvr2Engine>(
          segments: [
            ButtonSegment(
              value: ComfySeedvr2Engine.automatic,
              label: Text(context.l10n.img2img_seedvr2EngineAuto),
              icon: const Icon(Icons.auto_mode_outlined, size: 16),
            ),
            ButtonSegment(
              value: ComfySeedvr2Engine.native,
              label: Text(context.l10n.img2img_seedvr2EngineNative),
              icon: const Icon(Icons.verified_outlined, size: 16),
              enabled: capabilities.nativeUsable,
            ),
            ButtonSegment(
              value: ComfySeedvr2Engine.legacy,
              label: Text(context.l10n.img2img_seedvr2EngineLegacy),
              icon: const Icon(Icons.extension_outlined, size: 16),
              enabled: capabilities.legacyUsable,
            ),
          ],
          selected: {settings.seedvr2Engine},
          onSelectionChanged: (value) {
            if (value.isNotEmpty) controller.updateSeedvr2Engine(value.first);
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 6),
        Text(
          switch (backend) {
            ComfySeedvr2Backend.native =>
              context.l10n.img2img_seedvr2EngineResolvedNative,
            ComfySeedvr2Backend.legacy =>
              context.l10n.img2img_seedvr2EngineResolvedLegacy,
            null => context.l10n.img2img_seedvr2EngineUnavailable,
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: backend == null
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _IntegerControl(
          label: 'VAE Tile Size',
          value: settings.seedvr2VaeTileSize,
          min: UpscaleWorkflowSettings.minSeedvr2VaeTileSize,
          max: UpscaleWorkflowSettings.maxSeedvr2VaeTileSize,
          step: 64,
          onChanged: controller.updateSeedvr2VaeTileSize,
          hint: context.l10n.img2img_seedvr2VaeTileHint,
        ),
        if (backend == ComfySeedvr2Backend.legacy) ...[
          _IntegerControl(
            label: context.l10n.img2img_seedvr2BlocksToSwap,
            value: settings.seedvr2BlocksToSwap,
            min: UpscaleWorkflowSettings.minSeedvr2BlocksToSwap,
            max: UpscaleWorkflowSettings.maxSeedvr2BlocksToSwap,
            step: 1,
            onChanged: controller.updateSeedvr2BlocksToSwap,
            hint: context.l10n.img2img_seedvr2BlocksToSwapHint,
          ),
          if (capabilities.legacyTilingAvailable)
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.img2img_seedvr2UseTiledUpscale,
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(context.l10n.img2img_seedvr2UseTiledUpscaleHint),
                value: settings.seedvr2Tiled,
                onChanged: controller.updateSeedvr2Tiled,
              ),
            ),
        ],
        if (capabilities.legacyTilingAvailable && settings.seedvr2Tiled)
          _IntegerControl(
            label: context.l10n.img2img_seedvr2TileSize,
            value: settings.seedvr2TileSize,
            min: UpscaleWorkflowSettings.minSeedvr2TileSize,
            max: UpscaleWorkflowSettings.maxSeedvr2TileSize,
            step: 64,
            onChanged: controller.updateSeedvr2TileSize,
            hint: context.l10n.img2img_seedvr2TileSizeHint,
          ),
      ],
    );
  }
}

class _IntegerControl extends StatelessWidget {
  const _IntegerControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.hint,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<double> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            EditableDoubleField(
              value: current,
              min: min.toDouble(),
              max: max.toDouble(),
              decimals: 0,
              width: 72,
              onChanged: onChanged,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: current,
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            onChanged: onChanged,
          ),
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

enum _MetricLevel { low, medium, high }

class _UpscaleMetrics extends StatelessWidget {
  const _UpscaleMetrics({required this.module});
  final ComfyUpscaleModule module;

  @override
  Widget build(BuildContext context) {
    final levels = switch (module) {
      ComfyUpscaleModule.regular => (
        _MetricLevel.medium,
        _MetricLevel.medium,
        _MetricLevel.medium,
      ),
      ComfyUpscaleModule.seedvr2 => (
        _MetricLevel.low,
        _MetricLevel.high,
        _MetricLevel.high,
      ),
      ComfyUpscaleModule.rtx => (
        _MetricLevel.high,
        _MetricLevel.low,
        _MetricLevel.medium,
      ),
    };
    return Column(
      children: [
        _Metric(
          label: context.l10n.img2img_metricSpeed,
          level: levels.$1,
          lowerIsBetter: false,
        ),
        const SizedBox(height: 6),
        _Metric(
          label: context.l10n.img2img_metricVram,
          level: levels.$2,
          lowerIsBetter: true,
        ),
        const SizedBox(height: 6),
        _Metric(
          label: context.l10n.img2img_metricQuality,
          level: levels.$3,
          lowerIsBetter: false,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.level,
    required this.lowerIsBetter,
  });
  final String label;
  final _MetricLevel level;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = switch (level) {
      _MetricLevel.low => .34,
      _MetricLevel.medium => .66,
      _MetricLevel.high => 1.0,
    };
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: value, minHeight: 8),
          ),
        ),
      ],
    );
  }
}
