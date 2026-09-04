import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../common/adaptive_dialog_frame.dart';
import '../image_editor_processing_service.dart';
import 'editor_effects.dart';
import 'image_editor_effects_controller.dart';

class EditorEffectSelection {
  const EditorEffectSelection(this.type, this.intensity);

  final EditorEffectType type;
  final double intensity;
}

class EffectsPreviewDialog extends StatefulWidget {
  const EffectsPreviewDialog({
    super.key,
    required this.sourceBytes,
    required this.cropRect,
    required this.processingService,
    this.scrollController,
  });

  final Uint8List sourceBytes;
  final EditorEffectCropRect? cropRect;
  final ImageEditorProcessingService processingService;
  final ScrollController? scrollController;

  static Future<EditorEffectSelection?> show(
    BuildContext context, {
    required Uint8List sourceBytes,
    required EditorEffectCropRect? cropRect,
    required ImageEditorProcessingService processingService,
  }) => AdaptivePresenter.showForm<EditorEffectSelection>(
    context: context,
    dialogWidth: 960,
    titleBuilder: (context) => Text(
      context.l10n.editor_localEffects,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    builder: (context, scrollController) => EffectsPreviewDialog(
      sourceBytes: sourceBytes,
      cropRect: cropRect,
      processingService: processingService,
      scrollController: scrollController,
    ),
  );

  @override
  State<EffectsPreviewDialog> createState() => _EffectsPreviewDialogState();
}

class _EffectsPreviewDialogState extends State<EffectsPreviewDialog> {
  EditorEffectType type = EditorEffectType.brightness;
  double intensity = .25;
  late Uint8List previewBytes = widget.sourceBytes;
  Timer? debounce;
  int previewEpoch = 0;
  bool loading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    previewEpoch++;
    debounce?.cancel();
    super.dispose();
  }

  void _refresh() {
    debounce?.cancel();
    final epoch = ++previewEpoch;
    setState(() {
      loading = true;
      error = '';
    });
    debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final result = await widget.processingService.applyEffect(
          EditorEffectJob(
            imageBytes: widget.sourceBytes,
            effectType: type,
            intensity: intensity,
            maxPreviewDimension: 768,
            cropRect: widget.cropRect,
          ),
        );
        if (!mounted || epoch != previewEpoch) return;
        setState(() {
          previewBytes = result.bytes;
          loading = false;
        });
      } catch (exception) {
        if (!mounted || epoch != previewEpoch) return;
        setState(() {
          loading = false;
          error = exception.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveDialogFrame(
      key: const ValueKey('effects-preview-frame'),
      maxWidth: 960,
      maxHeight: 900,
      reservedVerticalSpace: 0,
      horizontalMargin: 0,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('effects-preview-scroll'),
              controller: widget.scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                _section(context.l10n.editor_basicAdjustments, const [
                  EditorEffectType.brightness,
                  EditorEffectType.contrast,
                  EditorEffectType.saturation,
                  EditorEffectType.temperature,
                  EditorEffectType.gamma,
                ]),
                const SizedBox(height: 14),
                _section(context.l10n.editor_styleAndRepair, const [
                  EditorEffectType.grayscale,
                  EditorEffectType.invert,
                  EditorEffectType.sepia,
                  EditorEffectType.denoise,
                  EditorEffectType.blur,
                  EditorEffectType.sharpen,
                ]),
                const SizedBox(height: 14),
                _section(
                  context.l10n.editor_transformCrop,
                  const [
                    EditorEffectType.rotateLeft,
                    EditorEffectType.rotateRight,
                    EditorEffectType.flipHorizontal,
                    EditorEffectType.flipVertical,
                    EditorEffectType.cropToSelection,
                  ],
                  description: context.l10n.editor_transformCropDescription,
                  prominent: true,
                ),
                const SizedBox(height: 16),
                _effectControl(),
                const SizedBox(height: 16),
                _previewComparison(),
                const SizedBox(height: 12),
                Text(
                  context.l10n.editor_effectPreviewHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackActions =
                      constraints.maxWidth < 520 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  final cancel = TextButton(
                    key: const ValueKey('effects-preview-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.common_cancel),
                  );
                  final apply = FilledButton.icon(
                    key: const ValueKey('effects-preview-apply'),
                    onPressed: loading || error.isNotEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            EditorEffectSelection(type, intensity),
                          ),
                    icon: const Icon(Icons.check),
                    label: Text(
                      context.l10n.editor_applyToCurrentLayer,
                      textAlign: TextAlign.center,
                    ),
                  );
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cancel, const SizedBox(height: 8), apply],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [cancel, const SizedBox(width: 12), apply],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<EditorEffectType> values, {
    String? description,
    bool prominent = false,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in values)
                  _effectChip(value, prominent: prominent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _effectChip(EditorEffectType value, {required bool prominent}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = value == type;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurface;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      backgroundColor: colorScheme.surfaceContainer,
      side: selected
          ? BorderSide(color: colorScheme.primary, width: 1)
          : BorderSide.none,
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 14 : 10,
        vertical: prominent ? 10 : 7,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_effectIcon(value), size: prominent ? 20 : 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              effectLabel(context, value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
      onSelected: (_) {
        setState(() {
          type = value;
          intensity = editorEffectDefaultIntensity(value);
        });
        _refresh();
      },
    );
  }

  Widget _effectControl() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (!editorEffectHasIntensity(type)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(_effectIcon(type), color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.editor_oneShotEffectHint(
                    effectLabel(context, type),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(_effectIcon(type), color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.editor_effectIntensity(
                      effectLabel(context, type),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    intensity.toStringAsFixed(2),
                    style: theme.textTheme.titleSmall,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(
                        () => intensity = editorEffectDefaultIntensity(type),
                      );
                      _refresh();
                    },
                    child: Text(context.l10n.common_reset),
                  ),
                ],
              ),
            ),
            Slider(
              value: intensity,
              min: editorEffectMin(type),
              max: editorEffectMax(type),
              divisions: 40,
              onChanged: (value) {
                setState(() => intensity = value);
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewComparison() {
    return LayoutBuilder(
      key: const ValueKey('effects-preview-comparison'),
      builder: (context, constraints) {
        final panes = [
          _preview(context.l10n.editor_original, widget.sourceBytes, false, ''),
          _preview(
            context.l10n.editor_effectPreview,
            previewBytes,
            loading,
            error,
          ),
        ];
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              SizedBox(height: 240, child: panes[0]),
              const SizedBox(height: 12),
              SizedBox(height: 240, child: panes[1]),
            ],
          );
        }
        return SizedBox(
          height: 420,
          child: Row(
            children: [
              Expanded(child: panes[0]),
              const SizedBox(width: 14),
              Expanded(child: panes[1]),
            ],
          ),
        );
      },
    );
  }

  Widget _preview(String title, Uint8List bytes, bool busy, String message) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
              child: message.isNotEmpty
                  ? Center(
                      child: Text(
                        message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  : Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          Positioned(
            left: 8,
            top: 6,
            child: Text(title, style: theme.textTheme.labelMedium),
          ),
          if (busy)
            Positioned(
              right: 8,
              top: 8,
              child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _effectIcon(EditorEffectType effectType) => switch (effectType) {
    EditorEffectType.brightness => Icons.wb_sunny_outlined,
    EditorEffectType.contrast => Icons.contrast,
    EditorEffectType.saturation => Icons.palette_outlined,
    EditorEffectType.temperature => Icons.thermostat,
    EditorEffectType.gamma => Icons.tune,
    EditorEffectType.grayscale => Icons.tonality,
    EditorEffectType.invert => Icons.invert_colors,
    EditorEffectType.sepia => Icons.filter_vintage,
    EditorEffectType.denoise => Icons.grain,
    EditorEffectType.blur => Icons.blur_on,
    EditorEffectType.sharpen => Icons.auto_fix_high,
    EditorEffectType.cropToSelection => Icons.crop,
    EditorEffectType.rotateLeft => Icons.rotate_left,
    EditorEffectType.rotateRight => Icons.rotate_right,
    EditorEffectType.flipHorizontal => Icons.swap_horiz,
    EditorEffectType.flipVertical => Icons.swap_vert,
  };
}
