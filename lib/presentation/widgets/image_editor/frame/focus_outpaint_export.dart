import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../core/utils/hard_edge_mask_exporter.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../image_editor_processing_service.dart';
import 'frame_geometry.dart';

/// 聚焦外扩交给生成页的内容，坐标与尺寸都已换算到压缩档位
@immutable
class FocusOutpaintExport {
  const FocusOutpaintExport({
    required this.sourceImage,
    required this.width,
    required this.height,
    required this.crop,
    this.maskImage,
  });

  /// 原图与取景框拼成的整张画布，没有原图内容处透明
  final Uint8List sourceImage;
  final int width;
  final int height;

  /// 取景框在整张画布中的位置
  final Rect crop;

  /// 画布尺寸的蒙版，只含取景框内的部分；框内没有要生成的像素时为 null
  final Uint8List? maskImage;
}

/// 不裁切时把原图与取景框拼成整张画布，生成页只送取景框、再按蒙版贴回
class FocusOutpaintExporter {
  const FocusOutpaintExporter(this._processing);

  final ImageEditorProcessingService _processing;

  /// 取景框在压缩档位整张画布中的位置；估价与导出共用
  static Rect projectCrop({
    required Rect frame,
    required Rect canvas,
    required EditorCompressionTarget target,
  }) {
    return EditorCompressionGeometry.projectCropToTarget(
      EditorFrameGeometry.frameInCanvas(frame: frame, canvas: canvas),
      workWidth: canvas.width.round(),
      workHeight: canvas.height.round(),
      target: target,
    );
  }

  /// [frameMask] 是取景框局部坐标的二值蒙版，已包含框内的空白区
  Future<FocusOutpaintExport> export({
    required Uint8List sourceImage,
    required Rect sourceRect,
    required Rect frame,
    required HardEdgeMaskRaster frameMask,
    required EditorCompressionTarget target,
  }) async {
    final canvas = EditorFrameGeometry.outputCanvas(
      frame: frame,
      sourceRect: sourceRect,
    );
    final materialized = await _processing.materializeOutpaint(
      sourceImage: sourceImage,
      frame: EditorFrameGeometry.virtualFrame(
        frame: canvas,
        sourceRect: sourceRect,
      ),
      targetWidth: target.width,
      targetHeight: target.height,
    );
    final maskImage = frameMask.mask.contains(1)
        ? await _placeFrameMask(
            frameMask,
            frame: frame,
            canvas: canvas,
            target: target,
          )
        : null;
    return FocusOutpaintExport(
      sourceImage: materialized.sourceImage,
      width: materialized.width,
      height: materialized.height,
      crop: projectCrop(frame: frame, canvas: canvas, target: target),
      maskImage: maskImage,
    );
  }

  Future<Uint8List> _placeFrameMask(
    HardEdgeMaskRaster frameMask, {
    required Rect frame,
    required Rect canvas,
    required EditorCompressionTarget target,
  }) {
    final offset = EditorFrameGeometry.frameInCanvas(
      frame: frame,
      canvas: canvas,
    ).topLeft;
    final placed =
        BinaryMask(
          pixels: frameMask.mask,
          width: frameMask.width,
          height: frameMask.height,
        ).placedIn(
          canvasWidth: canvas.width.round(),
          canvasHeight: canvas.height.round(),
          left: offset.dx.round(),
          top: offset.dy.round(),
        );
    return _processing.resizeBinaryMask(
      placed,
      width: target.width,
      height: target.height,
    );
  }
}
