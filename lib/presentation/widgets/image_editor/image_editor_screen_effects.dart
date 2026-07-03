part of 'image_editor_screen.dart';

extension _ImageEditorScreenEffects on _ImageEditorScreenState {
  Future<void> _showEffectsDialog() async {
    final layer = _state.layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }

    final sourceBytes = await _readLayerPng(layer);
    if (!mounted) return;
    if (sourceBytes == null) {
      AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
      return;
    }

    var effectType = EditorEffectType.brightness;
    var intensity = 0.25;
    var previewBytes = sourceBytes;
    var previewLoading = false;
    var previewError = '';
    var previewVersion = 0;
    var previewInitialized = false;
    var dialogOpen = true;
    Timer? previewDebounce;

    Future<void> refreshPreview(StateSetter setDialogState) async {
      previewDebounce?.cancel();
      final version = ++previewVersion;
      setDialogState(() {
        previewLoading = true;
        previewError = '';
      });

      previewDebounce = Timer(const Duration(milliseconds: 180), () async {
        try {
          final cropRect = _selectionCropRect();
          final job = EditorEffectJob(
            imageBytes: sourceBytes,
            effectType: effectType,
            intensity: intensity,
            maxPreviewDimension: 768,
            cropRect: cropRect,
          );
          final resultMessage = await compute(
            runEditorEffectJobMessage,
            job.toMessage(),
            debugLabel: 'image_editor_effect_preview',
          );
          final result = EditorEffectResult.fromMessage(resultMessage);
          if (!dialogOpen || !mounted || version != previewVersion) {
            return;
          }
          setDialogState(() {
            previewBytes = result.bytes;
            previewLoading = false;
          });
        } catch (e) {
          if (!dialogOpen || !mounted || version != previewVersion) {
            return;
          }
          setDialogState(() {
            previewLoading = false;
            previewError = e.toString();
          });
        }
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!previewInitialized) {
              previewInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogOpen && mounted) {
                  unawaited(refreshPreview(setState));
                }
              });
            }
            final media = MediaQuery.of(context);
            final horizontalInset = media.size.width < 820 ? 12.0 : 32.0;
            final dialogWidth = (media.size.width - horizontalInset * 2)
                .clamp(360.0, 1120.0)
                .toDouble();
            final previewHeight = (media.size.height * 0.48)
                .clamp(320.0, 520.0)
                .toDouble();

            void selectEffect(EditorEffectType value) {
              setState(() {
                effectType = value;
                intensity = _defaultEffectIntensity(value);
              });
              unawaited(refreshPreview(setState));
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: media.size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.editor_localEffects,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.common_close,
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEffectSection(
                                title: context.l10n.editor_basicAdjustments,
                                effects: const [
                                  EditorEffectType.brightness,
                                  EditorEffectType.contrast,
                                  EditorEffectType.saturation,
                                  EditorEffectType.temperature,
                                  EditorEffectType.gamma,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                              ),
                              const SizedBox(height: 14),
                              _buildEffectSection(
                                title: context.l10n.editor_styleAndRepair,
                                effects: const [
                                  EditorEffectType.grayscale,
                                  EditorEffectType.invert,
                                  EditorEffectType.sepia,
                                  EditorEffectType.denoise,
                                  EditorEffectType.blur,
                                  EditorEffectType.sharpen,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                              ),
                              const SizedBox(height: 14),
                              _buildEffectSection(
                                title: context.l10n.editor_transformCrop,
                                description: context
                                    .l10n
                                    .editor_transformCropDescription,
                                effects: const [
                                  EditorEffectType.rotateLeft,
                                  EditorEffectType.rotateRight,
                                  EditorEffectType.flipHorizontal,
                                  EditorEffectType.flipVertical,
                                  EditorEffectType.cropToSelection,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                                prominent: true,
                              ),
                              const SizedBox(height: 16),
                              _buildEffectControl(
                                effectType: effectType,
                                intensity: intensity,
                                onChanged: (value) {
                                  setState(() => intensity = value);
                                  unawaited(refreshPreview(setState));
                                },
                                onReset: () {
                                  setState(
                                    () => intensity = _defaultEffectIntensity(
                                      effectType,
                                    ),
                                  );
                                  unawaited(refreshPreview(setState));
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildEffectPreviewComparison(
                                previewHeight: previewHeight,
                                sourceBytes: sourceBytes,
                                previewBytes: previewBytes,
                                previewLoading: previewLoading,
                                previewError: previewError,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.editor_effectPreviewHint,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.l10n.common_cancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: previewLoading || previewError.isNotEmpty
                                ? null
                                : () => Navigator.pop(context, true),
                            icon: const Icon(Icons.check),
                            label: Text(
                              context.l10n.editor_applyToCurrentLayer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    dialogOpen = false;
    previewDebounce?.cancel();

    if (confirmed == true) {
      await _applyEffect(effectType, intensity);
    }
  }

  Widget _buildEffectSection({
    required String title,
    required List<EditorEffectType> effects,
    required EditorEffectType selectedEffect,
    required ValueChanged<EditorEffectType> onSelected,
    String? description,
    bool prominent = false,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final effect in effects)
                  _buildEffectChip(
                    effect: effect,
                    selected: effect == selectedEffect,
                    onSelected: onSelected,
                    prominent: prominent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectChip({
    required EditorEffectType effect,
    required bool selected,
    required ValueChanged<EditorEffectType> onSelected,
    required bool prominent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurface;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: colorScheme.secondaryContainer,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      side: BorderSide(
        color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 14 : 10,
        vertical: prominent ? 10 : 7,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_effectIcon(effect), size: prominent ? 20 : 18),
          const SizedBox(width: 6),
          Text(
            _effectLabel(effect),
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
      onSelected: (_) => onSelected(effect),
    );
  }

  Widget _buildEffectControl({
    required EditorEffectType effectType,
    required double intensity,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (!_effectHasIntensity(effectType)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(_effectIcon(effectType), color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.editor_oneShotEffectHint(
                    _effectLabel(effectType),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_effectIcon(effectType), color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.editor_effectIntensity(
                      _effectLabel(effectType),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  intensity.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onReset,
                  child: Text(context.l10n.common_reset),
                ),
              ],
            ),
            Slider(
              value: intensity,
              min: _effectMin(effectType),
              max: _effectMax(effectType),
              divisions: 40,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectPreviewComparison({
    required double previewHeight,
    required Uint8List sourceBytes,
    required Uint8List previewBytes,
    required bool previewLoading,
    required String previewError,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        if (stacked) {
          return SizedBox(
            height: previewHeight * 1.7,
            child: Column(
              children: [
                Expanded(
                  child: _buildEffectPreviewPane(
                    title: context.l10n.editor_original,
                    bytes: sourceBytes,
                    loading: false,
                    error: '',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildEffectPreviewPane(
                    title: context.l10n.editor_effectPreview,
                    bytes: previewBytes,
                    loading: previewLoading,
                    error: previewError,
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: previewHeight,
          child: Row(
            children: [
              Expanded(
                child: _buildEffectPreviewPane(
                  title: context.l10n.editor_original,
                  bytes: sourceBytes,
                  loading: false,
                  error: '',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildEffectPreviewPane(
                  title: context.l10n.editor_effectPreview,
                  bytes: previewBytes,
                  loading: previewLoading,
                  error: previewError,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEffectPreviewPane({
    required String title,
    required Uint8List bytes,
    required bool loading,
    required String error,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
              child: error.isNotEmpty
                  ? Center(
                      child: Text(
                        error,
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
          if (loading)
            const Positioned(
              right: 8,
              top: 8,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  IconData _effectIcon(EditorEffectType type) {
    return switch (type) {
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

  Future<void> _applyEffect(
    EditorEffectType effectType,
    double intensity,
  ) async {
    final layer = _state.layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }

    try {
      final sourceBytes = await _readLayerPng(layer);
      if (!mounted) return;
      if (sourceBytes == null) {
        AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
        return;
      }

      final cropRect = _selectionCropRect();
      final job = EditorEffectJob(
        imageBytes: sourceBytes,
        effectType: effectType,
        intensity: intensity,
        cropRect: cropRect,
      );
      final resultMessage = await compute(
        runEditorEffectJobMessage,
        job.toMessage(),
        debugLabel: 'image_editor_effect_apply',
      );
      final result = EditorEffectResult.fromMessage(resultMessage);
      final bytes = result.bytes;
      final newImage = await _decodeUiImage(bytes);
      if (!mounted) return;
      _state.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: layer.id,
          newImageBytes: bytes,
          newImage: newImage,
          actionDescription: _effectLabel(effectType),
        ),
        _state,
      );
      _state.layerManager.invalidateSnapshot();
      _updateLayoutState(() {});
      AppToast.success(
        context,
        context.l10n.editor_effectApplied(_effectLabel(effectType)),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, context.l10n.editor_applyEffectFailed(e));
    }
  }

  Future<Uint8List?> _readLayerPng(dynamic layer) async {
    final rendered = await _renderLayerToImage(layer);
    try {
      final raw = await rendered.toByteData(format: ui.ImageByteFormat.png);
      return raw?.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  }

  Future<ui.Image> _renderLayerToImage(dynamic layer) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    layer.render(canvas, _state.canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _state.canvasSize.width.toInt(),
      _state.canvasSize.height.toInt(),
    );
    picture.dispose();
    return image;
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  String _effectLabel(EditorEffectType type) {
    return switch (type) {
      EditorEffectType.brightness => context.l10n.editor_effectBrightness,
      EditorEffectType.contrast => context.l10n.editor_effectContrast,
      EditorEffectType.saturation => context.l10n.editor_effectSaturation,
      EditorEffectType.temperature => context.l10n.editor_effectTemperature,
      EditorEffectType.gamma => context.l10n.editor_effectGamma,
      EditorEffectType.grayscale => context.l10n.editor_effectGrayscale,
      EditorEffectType.invert => context.l10n.editor_effectInvert,
      EditorEffectType.sepia => context.l10n.editor_effectSepia,
      EditorEffectType.denoise => context.l10n.editor_effectDenoise,
      EditorEffectType.blur => context.l10n.editor_effectBlur,
      EditorEffectType.sharpen => context.l10n.editor_effectSharpen,
      EditorEffectType.cropToSelection =>
        context.l10n.editor_effectCropToSelection,
      EditorEffectType.rotateLeft => context.l10n.editor_effectRotateLeft,
      EditorEffectType.rotateRight => context.l10n.editor_effectRotateRight,
      EditorEffectType.flipHorizontal =>
        context.l10n.editor_effectFlipHorizontal,
      EditorEffectType.flipVertical => context.l10n.editor_effectFlipVertical,
    };
  }

  double _defaultEffectIntensity(EditorEffectType type) {
    return editorEffectDefaultIntensity(type);
  }

  double _effectMin(EditorEffectType type) {
    return editorEffectMin(type);
  }

  double _effectMax(EditorEffectType type) {
    return editorEffectMax(type);
  }

  bool _effectHasIntensity(EditorEffectType type) {
    return editorEffectHasIntensity(type);
  }

  EditorEffectCropRect? _selectionCropRect() {
    final selection = _state.selectionPath;
    if (selection == null) {
      return null;
    }
    final bounds = selection.getBounds().intersect(
      Offset.zero & _state.canvasSize,
    );
    if (bounds.isEmpty) {
      return null;
    }
    final x = bounds.left.floor().clamp(0, _state.canvasSize.width - 1).toInt();
    final y = bounds.top.floor().clamp(0, _state.canvasSize.height - 1).toInt();
    final right = bounds.right
        .ceil()
        .clamp(x + 1, _state.canvasSize.width)
        .toInt();
    final bottom = bounds.bottom
        .ceil()
        .clamp(y + 1, _state.canvasSize.height)
        .toInt();
    return EditorEffectCropRect(
      x: x,
      y: y,
      width: right - x,
      height: bottom - y,
    );
  }

  /// 更改画布尺寸
}
