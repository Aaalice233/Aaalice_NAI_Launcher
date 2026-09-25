import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/editor_compression_utils.dart';
import 'package:nai_launcher/core/utils/hard_edge_mask_exporter.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/focus_outpaint_export.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/frame_geometry.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_processing_service.dart';

/// 物化与蒙版缩放在当前 isolate 内完成，测试不依赖后台 isolate 调度
class _InlineProcessingService extends ImageEditorProcessingService {
  @override
  Future<OutpaintVirtualMaterializeResult> materializeOutpaint({
    required Uint8List sourceImage,
    required OutpaintVirtualFrame frame,
    int? targetWidth,
    int? targetHeight,
  }) async {
    return InpaintOutpaintUtils.materializeVirtualFrame(
      sourceImage: sourceImage,
      frame: frame,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  }

  @override
  Future<Uint8List> resizeBinaryMask(
    BinaryMask mask, {
    required int width,
    required int height,
  }) async {
    final resized = InpaintMaskUtils.resizeBinaryMask(
      mask.pixels,
      sourceWidth: mask.width,
      sourceHeight: mask.height,
      targetWidth: width,
      targetHeight: height,
    );
    return InpaintMaskUtils.encodeBinaryMask(resized, width, height);
  }
}

void main() {
  const source = Rect.fromLTWH(0, 0, 256, 128);
  final exporter = FocusOutpaintExporter(_InlineProcessingService());
  final sourcePng = _gradientPng(256, 128);

  Future<FocusOutpaintExport> export(
    Rect frame, {
    EditorCompressionTarget? target,
    List<Rect> paintedMask = const [],
  }) {
    final canvas = EditorFrameGeometry.outputCanvas(
      frame: frame,
      sourceRect: source,
    );
    return exporter.export(
      sourceImage: sourcePng,
      sourceRect: source,
      frame: frame,
      frameMask: _frameMask(frame, source, paintedMask),
      target:
          target ??
          EditorCompressionTarget(
            width: canvas.width.round(),
            height: canvas.height.round(),
            isOriginal: true,
          ),
    );
  }

  test(
    'a frame moved right sends only the frame and keeps the source',
    () async {
      const frame = Rect.fromLTWH(64, 0, 256, 128);

      final result = await export(frame);

      expect(result.width, 320);
      expect(result.height, 128);
      expect(result.crop, frame);
      final canvas = img.decodePng(result.sourceImage)!;
      for (final x in const [0, 63, 64, 200, 255]) {
        final pixel = canvas.getPixel(x, 64);
        expect(pixel.r.toInt(), x % 256, reason: 'x=$x keeps the source');
        expect(pixel.a.toInt(), 255, reason: 'x=$x');
      }
      expect(canvas.getPixel(256, 64).a.toInt(), 0);
      expect(canvas.getPixel(319, 0).a.toInt(), 0);

      final mask = _decodeMask(result.maskImage!);
      expect(mask.width, 320);
      expect(mask.pixels[mask.indexOf(254, 64)], 0);
      expect(mask.pixels[mask.indexOf(255, 64)], 1, reason: '1 px overlap');
      expect(mask.pixels[mask.indexOf(319, 127)], 1);
      expect(mask.pixels[mask.indexOf(10, 10)], 0, reason: 'outside frame');
    },
  );

  test(
    'diagonal corners outside the frame stay transparent and unmasked',
    () async {
      const frame = Rect.fromLTWH(64, 64, 256, 128);

      final result = await export(frame);

      expect(result.width, 320);
      expect(result.height, 192);
      expect(result.crop, frame);
      final canvas = img.decodePng(result.sourceImage)!;
      final mask = _decodeMask(result.maskImage!);
      for (final corner in const [Offset(300, 20), Offset(20, 170)]) {
        final x = corner.dx.toInt();
        final y = corner.dy.toInt();
        expect(canvas.getPixel(x, y).a.toInt(), 0, reason: '$corner');
        expect(mask.pixels[mask.indexOf(x, y)], 0, reason: '$corner');
      }
      expect(mask.pixels[mask.indexOf(300, 150)], 1);
      expect(mask.pixels[mask.indexOf(100, 150)], 1);
    },
  );

  test(
    'masks painted inside the frame are placed at the frame offset',
    () async {
      const frame = Rect.fromLTWH(0, 0, 192, 128);

      final result = await export(
        frame,
        paintedMask: const [Rect.fromLTWH(32, 32, 16, 16)],
      );

      expect(result.width, 256);
      expect(result.crop, frame);
      final mask = _decodeMask(result.maskImage!);
      expect(mask.pixels[mask.indexOf(40, 40)], 1);
      expect(mask.pixels[mask.indexOf(220, 40)], 0);
    },
  );

  test(
    'a frame inside the source with nothing masked exports no mask',
    () async {
      final result = await export(const Rect.fromLTWH(64, 0, 192, 128));

      expect(result.maskImage, isNull);
      expect(result.width, 256);
      expect(result.crop, const Rect.fromLTWH(64, 0, 192, 128));
    },
  );

  test('compression scales the canvas, crop and mask together', () async {
    const frame = Rect.fromLTWH(64, 0, 256, 128);

    final result = await export(
      frame,
      target: const EditorCompressionTarget(width: 160, height: 64),
    );

    expect(result.width, 160);
    expect(result.height, 64);
    expect(result.crop, const Rect.fromLTWH(32, 0, 128, 64));
    final mask = _decodeMask(result.maskImage!);
    expect(mask.width, 160);
    expect(mask.pixels[mask.indexOf(140, 32)], 1);
    expect(mask.pixels[mask.indexOf(100, 32)], 0);
    expect(
      FocusOutpaintExporter.projectCrop(
        frame: frame,
        canvas: const Rect.fromLTWH(0, 0, 320, 128),
        target: const EditorCompressionTarget(width: 160, height: 64),
      ),
      result.crop,
    );
  });
}

HardEdgeMaskRaster _frameMask(Rect frame, Rect source, List<Rect> painted) {
  final width = frame.width.round();
  final height = frame.height.round();
  final mask = Uint8List(width * height);
  final rects = [
    ...EditorFrameGeometry.virtualFrame(
      frame: frame,
      sourceRect: source,
    ).outpaintMaskRects,
    ...painted,
  ];
  for (final rect in rects) {
    for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
      for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
        mask[y * width + x] = 1;
      }
    }
  }
  return HardEdgeMaskRaster(mask: mask, width: width, height: height);
}

BinaryMask _decodeMask(Uint8List bytes) {
  final decoded = InpaintMaskUtils.decodeBinaryMask(bytes)!;
  return BinaryMask(
    pixels: decoded.mask,
    width: decoded.width,
    height: decoded.height,
  );
}

Uint8List _gradientPng(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 256, y % 256, 128, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
