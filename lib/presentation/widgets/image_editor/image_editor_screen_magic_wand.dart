part of 'image_editor_screen.dart';

extension _ImageEditorScreenMagicWand on _ImageEditorScreenState {
  String _magicWandProgressLabel() {
    return switch (_magicWandProgress?.stage) {
      EfficientVitSamProgressStage.checkingModels =>
        context.l10n.editor_magicWandModelPreparing,
      EfficientVitSamProgressStage.downloadingModels =>
        context.l10n.editor_magicWandModelDownloading(
          (((_magicWandProgress?.fraction ?? 0) * 100).round()),
        ),
      EfficientVitSamProgressStage.loadingModels =>
        context.l10n.editor_magicWandModelLoading,
      EfficientVitSamProgressStage.encodingImage =>
        context.l10n.editor_magicWandEncoding,
      EfficientVitSamProgressStage.decodingMask =>
        context.l10n.editor_magicWandSegmenting,
      EfficientVitSamProgressStage.postprocessingMask =>
        context.l10n.editor_magicWandPostprocessing,
      null => context.l10n.common_loading,
    };
  }

  Widget _buildMagicWandProgressOverlay() {
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black26,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value:
                            _magicWandProgress?.stage ==
                                EfficientVitSamProgressStage.downloadingModels
                            ? _magicWandProgress?.fraction
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(child: Text(_magicWandProgressLabel())),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Layer? _resolveMagicWandEditTarget() {
    final sourceLayerId = _sourceLayerId;
    if (sourceLayerId != null) {
      final sourceLayer = _state.layerManager.getLayerById(sourceLayerId);
      if (sourceLayer != null &&
          !sourceLayer.locked &&
          sourceLayer.hasContent) {
        return sourceLayer;
      }
    }

    final activeLayer = _state.layerManager.activeLayer;
    if (activeLayer != null && !activeLayer.locked && activeLayer.hasContent) {
      return activeLayer;
    }

    for (final layer in _state.layerManager.layers) {
      if (layer.visible && !layer.locked && layer.hasContent) {
        return layer;
      }
    }
    return null;
  }

  Layer? _resolveMagicWandSourceLayer() {
    final sourceLayerId = _sourceLayerId;
    if (sourceLayerId == null) {
      return null;
    }
    final sourceLayer = _state.layerManager.getLayerById(sourceLayerId);
    return sourceLayer?.hasContent == true ? sourceLayer : null;
  }

  Layer _resolveMagicWandMaskTarget() {
    final activeLayer = _state.layerManager.activeLayer;
    if (activeLayer != null &&
        activeLayer.id != _sourceLayerId &&
        !activeLayer.locked) {
      return activeLayer;
    }

    for (final layer in _state.layerManager.layers) {
      if (layer.id != _sourceLayerId && !layer.locked) {
        return layer;
      }
    }

    return _addEmptyMaskLayerAboveSource(
      name: context.l10n.editor_maskLayerName,
    );
  }

  Future<EditorRawRgbaImage> _renderMagicWandSource(Layer layer) async {
    final width = _state.canvasSize.width.round();
    final height = _state.canvasSize.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (layer.baseImage != null && layer.strokes.isEmpty) {
      canvas.drawImage(layer.baseImage!, layer.baseImageOffset, Paint());
    } else {
      layer.render(canvas, _state.canvasSize);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw StateError('Failed to read Magic Wand source pixels.');
      }
      return EditorRawRgbaImage(
        bytes: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        width: width,
        height: height,
      );
    } finally {
      image.dispose();
    }
  }

  Future<ui.Image> _decodeMagicWandImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec?.dispose();
    }
  }

  Future<Uint8List> _readExistingMagicWandMask(int width, int height) async {
    final excludedLayerIds = {if (_sourceLayerId != null) _sourceLayerId!};
    final raster = await ImageExporterNew.tryExportHardEdgeMaskRasterFromLayers(
      _state.layerManager,
      _state.canvasSize,
      excludedBaseImageLayerIds: excludedLayerIds,
    );
    if (raster != null &&
        raster.width == width &&
        raster.height == height &&
        raster.mask.length == width * height) {
      return Uint8List.fromList(raster.mask);
    }

    final encodedMask = await ImageExporterNew.exportMaskFromLayers(
      _state.layerManager,
      _state.canvasSize,
      excludedBaseImageLayerIds: excludedLayerIds,
      forceHardEdges: true,
      preferCpuHardEdgeExport: true,
    );
    final decodedMask = InpaintMaskUtils.decodeBinaryMask(encodedMask);
    if (decodedMask == null ||
        decodedMask.width != width ||
        decodedMask.height != height) {
      throw StateError('Failed to read the current inpaint mask.');
    }
    return Uint8List.fromList(decodedMask.mask);
  }

  Future<ContiguousRegionSelection> _selectMagicWandRegion({
    required EditorRawRgbaImage source,
    required MagicWandSelectionMode mode,
    required int startX,
    required int startY,
    required int tolerance,
    required bool invert,
  }) async {
    if (mode == MagicWandSelectionMode.colorArea) {
      return ContiguousRegionSelector.selectRgbaAsync(
        rgba: source.bytes,
        width: source.width,
        height: source.height,
        startX: startX,
        startY: startY,
        tolerance: tolerance,
        invert: invert,
      );
    }

    final selector =
        widget.debugEfficientVitSamSelector ??
        _efficientVitSamService.selectRgba;
    return selector(
      rgba: source.bytes,
      width: source.width,
      height: source.height,
      startX: startX,
      startY: startY,
      invert: invert,
      onProgress: _setMagicWandProgress,
    );
  }

  Future<void> _applyMagicWandAt(
    Offset canvasPoint, {
    required MagicWandSelectionMode mode,
    required int tolerance,
    required bool invert,
  }) async {
    if (!mounted || _isMagicWandProcessing) {
      return;
    }

    final width = _state.canvasSize.width.round();
    final height = _state.canvasSize.height.round();
    final startX = canvasPoint.dx.floor();
    final startY = canvasPoint.dy.floor();
    if (width <= 0 ||
        height <= 0 ||
        startX < 0 ||
        startX >= width ||
        startY < 0 ||
        startY >= height) {
      return;
    }

    final targetLayer = _isInpaintMode
        ? _resolveMagicWandSourceLayer()
        : _resolveMagicWandEditTarget();
    if (targetLayer == null) {
      AppToast.warning(context, context.l10n.editor_magicWandNoSource);
      return;
    }

    _setMagicWandProcessing(true);

    try {
      final source = await _renderMagicWandSource(targetLayer);
      final selection = await _selectMagicWandRegion(
        source: source,
        mode: mode,
        startX: startX,
        startY: startY,
        tolerance: tolerance,
        invert: invert,
      );
      if (!mounted) {
        return;
      }
      if (selection.width != width ||
          selection.height != height ||
          selection.mask.length != width * height) {
        throw StateError('Magic Wand returned an invalid selection mask.');
      }

      if (_isInpaintMode) {
        final combinedMask = await _readExistingMagicWandMask(width, height);
        if (!mounted) {
          return;
        }
        var addedPixelCount = 0;
        for (var index = 0; index < combinedMask.length; index++) {
          if (selection.mask[index] == 1 && combinedMask[index] == 0) {
            combinedMask[index] = 1;
            addedPixelCount++;
          }
        }
        if (addedPixelCount == 0) {
          AppToast.info(context, context.l10n.editor_magicWandNothingChanged);
          return;
        }

        final overlayBytes =
            await InpaintMaskUtils.encodeEditorOverlayFromBinaryMaskAsync(
              combinedMask,
              width: width,
              height: height,
            );
        final overlayImage = await _decodeMagicWandImage(overlayBytes);
        if (!mounted) {
          overlayImage.dispose();
          return;
        }
        final maskLayer = _resolveMagicWandMaskTarget();
        _state.historyManager.execute(
          ReplaceLayerImageAction(
            layerId: maskLayer.id,
            newImageBytes: overlayBytes,
            newImage: overlayImage,
            actionDescription: 'Apply Magic Wand Mask',
          ),
          _state,
        );
        _state.layerManager.setActiveLayer(maskLayer.id);
      } else {
        final editedBytes = Uint8List.fromList(source.bytes);
        var erasedPixelCount = 0;
        for (var index = 0; index < selection.mask.length; index++) {
          if (selection.mask[index] == 1 && editedBytes[index * 4 + 3] != 0) {
            editedBytes[index * 4 + 3] = 0;
            erasedPixelCount++;
          }
        }
        if (erasedPixelCount == 0) {
          AppToast.info(context, context.l10n.editor_magicWandNothingChanged);
          return;
        }

        final editedImageBytes =
            await EditorCompressionEncoder.encodeRgbaPngAsync(
              EditorRawRgbaImage(
                bytes: editedBytes,
                width: width,
                height: height,
              ),
              targetWidth: width,
              targetHeight: height,
            );
        final editedImage = await _decodeMagicWandImage(editedImageBytes);
        if (!mounted) {
          editedImage.dispose();
          return;
        }
        _state.historyManager.execute(
          ReplaceLayerImageAction(
            layerId: targetLayer.id,
            newImageBytes: editedImageBytes,
            newImage: editedImage,
            actionDescription: 'Erase Magic Wand Region',
          ),
          _state,
        );
        _state.layerManager.setActiveLayer(targetLayer.id);
        _hasTransparentCutout = true;
      }

      _state.layerManager.invalidateSnapshot();
      _state.notifyRenderChange();
      _state.requestUiUpdate();
    } catch (error) {
      if (mounted) {
        AppToast.error(context, context.l10n.editor_magicWandFailed(error));
      }
    } finally {
      _setMagicWandProcessing(false);
    }
  }
}
