import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/utils/contiguous_region_selector.dart';
import '../../../core/utils/editor_compression_utils.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../data/services/efficient_vit_sam_service.dart';
import 'effects/editor_effects.dart';
import 'services/compression_export_service.dart';
import 'services/effects_service.dart';
import 'services/image_decode_service.dart';
import 'services/magic_wand_service.dart';
import 'services/mask_service.dart';
import 'services/outpaint_service.dart';

export 'services/image_decode_service.dart'
    show FlutterImageEditorIo, ImageEditorIo;

/// Stable facade used by the session controller. Resource ownership and each
/// processing responsibility live in the focused services below.
class ImageEditorProcessingService {
  ImageEditorProcessingService({
    ImageEditorIo io = const FlutterImageEditorIo(),
    EfficientVitSamService? magicWandService,
  }) : _decode = ImageDecodeService(io: io),
       _magicWand = MagicWandService(service: magicWandService);

  final ImageDecodeService _decode;
  final InpaintMaskService _mask = const InpaintMaskService();
  final OutpaintService _outpaint = const OutpaintService();
  final CompressionExportService _compression =
      const CompressionExportService();
  final EditorEffectsService _effects = const EditorEffectsService();
  final MagicWandService _magicWand;

  Future<ui.Image> decode(Uint8List bytes) => _decode.decode(bytes);

  Future<Uint8List> resize(
    Uint8List bytes, {
    required int width,
    required int height,
    ui.FilterQuality quality = ui.FilterQuality.medium,
  }) => _decode.resize(bytes, width: width, height: height, quality: quality);

  Future<EditorEffectResult> applyEffect(EditorEffectJob job) =>
      _effects.apply(job);

  Future<ContiguousRegionSelection> selectMagicWand({
    required EditorRawRgbaImage source,
    required int startX,
    required int startY,
    required bool invert,
    EfficientVitSamProgressCallback? onProgress,
  }) => _magicWand.select(
    source: source,
    startX: startX,
    startY: startY,
    invert: invert,
    onProgress: onProgress,
  );

  Future<Uint8List> encodeRgba(
    EditorRawRgbaImage image, {
    required int width,
    required int height,
  }) => _compression.encodeRgba(image, width: width, height: height);

  Future<OutpaintVirtualMaterializeResult> materializeOutpaint({
    required Uint8List sourceImage,
    required OutpaintVirtualFrame frame,
    int? targetWidth,
    int? targetHeight,
  }) => _outpaint.materialize(
    sourceImage: sourceImage,
    frame: frame,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );

  Future<Uint8List> resizeMask(
    Uint8List mask, {
    required int width,
    required int height,
  }) => _mask.resize(mask, width: width, height: height);

  void dispose() => _magicWand.dispose();
}
