import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/hard_edge_mask_exporter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/export/image_exporter_new.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports additional mask rects as white hard-edge pixels', () async {
    final bytes = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 8,
        height: 6,
        strokes: [],
        baseMasks: [],
        additionalRects: [Rect.fromLTWH(0, 0, 3, 2)],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.width, equals(8));
    expect(mask.height, equals(6));
    expect(mask.getPixel(0, 0).r, equals(255));
    expect(mask.getPixel(2, 1).r, equals(255));
    expect(mask.getPixel(3, 1).r, equals(0));
  });

  test('draws stroke polylines and erases over earlier strokes', () async {
    final bytes = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 16,
        height: 8,
        strokes: [
          HardEdgeMaskStroke(
            points: [Offset(1, 4), Offset(14, 4)],
            size: 5,
            isEraser: false,
          ),
          HardEdgeMaskStroke(
            points: [Offset(8, 4)],
            size: 5,
            isEraser: true,
          ),
        ],
        baseMasks: [],
        additionalRects: [],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(2, 4).r, equals(255));
    expect(mask.getPixel(8, 4).r, equals(0));
    expect(mask.getPixel(13, 4).r, equals(255));
  });

  test('pastes an offset base mask before drawing strokes', () async {
    final base = img.Image(width: 2, height: 2, numChannels: 4);
    img.fill(base, color: img.ColorRgba8(0, 0, 0, 0));
    base.setPixelRgba(0, 0, 255, 255, 255, 255);

    final bytes = await HardEdgeMaskExporter.exportAsync(
      HardEdgeMaskExportInput(
        width: 6,
        height: 6,
        strokes: const [],
        baseMasks: [
          HardEdgeMaskBaseImage(
            bytes: Uint8List.fromList(img.encodePng(base)),
            offsetX: 2,
            offsetY: 3,
          ),
        ],
        additionalRects: const [],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(2, 3).r, equals(255));
    expect(mask.getPixel(1, 3).r, equals(0));
  });

  test('draws additional mask rects after eraser strokes', () async {
    final bytes = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 8,
        height: 6,
        strokes: [
          HardEdgeMaskStroke(
            points: [Offset(1, 1)],
            size: 5,
            isEraser: true,
          ),
        ],
        baseMasks: [],
        additionalRects: [Rect.fromLTWH(0, 0, 4, 4)],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(1, 1).r, equals(255));
    expect(mask.getPixel(4, 1).r, equals(0));
  });

  test('ordered operations preserve base and stroke order', () async {
    final basePixel = _singleWhitePixelPng();

    final bytes = await HardEdgeMaskExporter.exportAsync(
      HardEdgeMaskExportInput(
        width: 8,
        height: 6,
        strokes: const [],
        baseMasks: const [],
        additionalRects: const [],
        orderedOperations: [
          HardEdgeMaskBaseImageOperation(
            baseMask: HardEdgeMaskBaseImage(
              bytes: basePixel,
              offsetX: 2,
              offsetY: 2,
            ),
          ),
          const HardEdgeMaskStrokeOperation(
            stroke: HardEdgeMaskStroke(
              points: [Offset(2, 2), Offset(4, 2)],
              size: 3,
              isEraser: true,
            ),
          ),
          HardEdgeMaskBaseImageOperation(
            baseMask: HardEdgeMaskBaseImage(
              bytes: basePixel,
              offsetX: 4,
              offsetY: 2,
            ),
          ),
        ],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(2, 2).r, equals(0));
    expect(mask.getPixel(4, 2).r, equals(255));
  });

  test('draws three-point strokes with smoothed quadratic path semantics',
      () async {
    final bytes = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 22,
        height: 14,
        strokes: [
          HardEdgeMaskStroke(
            points: [Offset(2, 10), Offset(10, 2), Offset(18, 10)],
            size: 3,
            isEraser: false,
          ),
        ],
        baseMasks: [],
        additionalRects: [],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(9, 5).r, equals(255));
    expect(mask.getPixel(10, 2).r, equals(0));
  });

  test('CPU exporter matches the expected hard-edge canvas semantics',
      () async {
    final bytes = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 12,
        height: 12,
        strokes: [
          HardEdgeMaskStroke(
            points: [Offset(2, 6), Offset(9, 6)],
            size: 3,
            isEraser: false,
          ),
        ],
        baseMasks: [],
        additionalRects: [Rect.fromLTWH(0, 0, 2, 2)],
      ),
    );

    final mask = img.decodeImage(bytes)!;
    expect(mask.getPixel(0, 0).r, equals(255));
    expect(mask.getPixel(2, 6).r, equals(255));
    expect(mask.getPixel(9, 6).r, equals(255));
    expect(mask.getPixel(11, 11).r, equals(0));
  });

  test('Layer exports hard-edge mask DTOs in canvas order', () async {
    final layer = Layer();
    addTearDown(layer.dispose);

    await layer.setBaseImage(_singleWhitePixelPng());
    layer.addStroke(
      StrokeData(
        points: const [Offset(2, 2), Offset(5, 2)],
        size: 3,
        color: const Color(0xFFFFFFFF),
        opacity: 1,
        hardness: 1,
        isEraser: true,
      ),
    );

    final baseMask = layer.toHardEdgeBaseMask();
    expect(baseMask, isNotNull);
    expect(baseMask!.offsetX, equals(0));
    expect(baseMask.offsetY, equals(0));
    expect(layer.baseImageOffset, Offset.zero);
    final originalFirstByte = layer.baseImageBytes!.first;
    baseMask.bytes[0] = originalFirstByte == 0 ? 1 : 0;
    expect(layer.baseImageBytes!.first, equals(originalFirstByte));

    final strokes = layer.toHardEdgeMaskStrokes();
    expect(strokes, hasLength(1));
    expect(strokes.single.points, const [Offset(2, 2), Offset(5, 2)]);
    expect(strokes.single.size, equals(3));
    expect(strokes.single.isEraser, isTrue);

    final operations = layer.toHardEdgeMaskOperations();
    expect(operations, hasLength(2));
    expect(operations.first, isA<HardEdgeMaskBaseImageOperation>());
    expect(operations.last, isA<HardEdgeMaskStrokeOperation>());
  });

  test('ImageExporterNew routes hard-edge layer masks through CPU exporter',
      () async {
    final layerManager = LayerManager();
    addTearDown(layerManager.dispose);
    final layer = layerManager.addLayer();
    layer.addStroke(
      StrokeData(
        points: const [Offset(2, 6), Offset(9, 6)],
        size: 3,
        color: const Color(0xFFFFFFFF),
        opacity: 1,
        hardness: 1,
      ),
    );

    final exported = await ImageExporterNew.exportMaskFromLayers(
      layerManager,
      const Rect.fromLTWH(0, 0, 12, 12),
      forceHardEdges: true,
      additionalMaskRects: const [Rect.fromLTWH(0, 0, 2, 2)],
      preferCpuHardEdgeExport: true,
    );
    final expected = await HardEdgeMaskExporter.exportAsync(
      const HardEdgeMaskExportInput(
        width: 12,
        height: 12,
        strokes: [],
        baseMasks: [],
        additionalRects: [Rect.fromLTWH(0, 0, 2, 2)],
        orderedOperations: [
          HardEdgeMaskStrokeOperation(
            stroke: HardEdgeMaskStroke(
              points: [Offset(2, 6), Offset(9, 6)],
              size: 3,
              isEraser: false,
            ),
          ),
        ],
      ),
    );

    final exportedMask = img.decodeImage(exported)!;
    final expectedMask = img.decodeImage(expected)!;
    expect(_redAt(exportedMask, 0, 0), equals(_redAt(expectedMask, 0, 0)));
    expect(_redAt(exportedMask, 2, 6), equals(_redAt(expectedMask, 2, 6)));
    expect(_redAt(exportedMask, 9, 6), equals(_redAt(expectedMask, 9, 6)));
    expect(_redAt(exportedMask, 11, 11), equals(_redAt(expectedMask, 11, 11)));
  });

  test(
    'ImageExporterNew CPU export preserves base mask black and transparency',
    () async {
      final layerManager = LayerManager();
      addTearDown(layerManager.dispose);

      final strokeLayer = layerManager.addLayer();
      strokeLayer.addStroke(
        StrokeData(
          points: const [Offset(0, 0.5), Offset(2.5, 0.5)],
          size: 2,
          color: const Color(0xFFFFFFFF),
          opacity: 1,
          hardness: 1,
        ),
      );

      final importedMaskLayer = layerManager.addLayer();
      await importedMaskLayer.setBaseImage(_blackWhiteTransparentPng());

      final cpuExported = await ImageExporterNew.exportMaskFromLayers(
        layerManager,
        const Rect.fromLTWH(0, 0, 4, 2),
        forceHardEdges: true,
        preferCpuHardEdgeExport: true,
      );
      final canvasExported = await ImageExporterNew.exportMaskFromLayers(
        layerManager,
        const Rect.fromLTWH(0, 0, 4, 2),
        forceHardEdges: true,
        preferCpuHardEdgeExport: false,
      );

      final cpuMask = img.decodeImage(cpuExported)!;
      final canvasMask = img.decodeImage(canvasExported)!;
      expect(_redAt(canvasMask, 0, 0), equals(0));
      expect(_redAt(canvasMask, 1, 0), equals(255));
      expect(_redAt(canvasMask, 2, 0), equals(255));
      expect(_redAt(cpuMask, 0, 0), equals(_redAt(canvasMask, 0, 0)));
      expect(_redAt(cpuMask, 1, 0), equals(_redAt(canvasMask, 1, 0)));
      expect(_redAt(cpuMask, 2, 0), equals(_redAt(canvasMask, 2, 0)));
    },
  );

  test('ImageExporterNew Canvas fallback honors base mask layer offsets',
      () async {
    final layerManager = LayerManager();
    addTearDown(layerManager.dispose);
    final layer = layerManager.addLayer();
    await layer.setBaseImage(_singleWhitePixelPng());
    layer.setBaseImageOffset(const Offset(3, 2));

    final exported = await ImageExporterNew.exportMaskFromLayers(
      layerManager,
      const Rect.fromLTWH(0, 0, 8, 8),
      forceHardEdges: true,
      preferCpuHardEdgeExport: false,
    );

    final mask = img.decodeImage(exported)!;
    expect(_redAt(mask, 0, 0), equals(0));
    expect(_redAt(mask, 3, 2), equals(255));
  });

  test('ImageExporterNew keeps Canvas fallback for selection paths', () async {
    final layerManager = LayerManager();
    addTearDown(layerManager.dispose);
    final selectionPath = Path()..addRect(const Rect.fromLTWH(10, 10, 1, 1));

    final exported = await ImageExporterNew.exportMaskFromLayers(
      layerManager,
      const Rect.fromLTWH(0, 0, 12, 12),
      selectionPath: selectionPath,
      forceHardEdges: true,
      additionalMaskRects: const [Rect.fromLTWH(0, 0, 2, 2)],
      preferCpuHardEdgeExport: true,
    );

    final mask = img.decodeImage(exported)!;
    expect(_redAt(mask, 0, 0), equals(255));
    expect(_redAt(mask, 10, 10), equals(255));
    expect(_redAt(mask, 11, 11), equals(0));
  });
}

Uint8List _singleWhitePixelPng() {
  final base = img.Image(width: 1, height: 1, numChannels: 4);
  base.setPixelRgba(0, 0, 255, 255, 255, 255);
  return Uint8List.fromList(img.encodePng(base));
}

Uint8List _blackWhiteTransparentPng() {
  final base = img.Image(width: 3, height: 1, numChannels: 4);
  base.setPixelRgba(0, 0, 0, 0, 0, 255);
  base.setPixelRgba(1, 0, 255, 255, 255, 255);
  base.setPixelRgba(2, 0, 0, 0, 0, 0);
  return Uint8List.fromList(img.encodePng(base));
}

int _redAt(img.Image image, int x, int y) => image.getPixel(x, y).r.toInt();
