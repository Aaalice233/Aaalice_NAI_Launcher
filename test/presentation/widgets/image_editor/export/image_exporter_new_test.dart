import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/export/image_exporter_new.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageExporterNew.exportMaskFromLayers', () {
    testWidgets('should export a focused selection rectangle as a full mask', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final maskBytes = await ImageExporterNew.exportMask(
          Path()..addRect(const Rect.fromLTWH(16, 20, 24, 28)),
          const Rect.fromLTWH(0, 0, 64, 64),
        );

        final decoded = img.decodePng(maskBytes)!;

        expect(decoded.getPixel(20, 24).r.toInt(), greaterThan(240));
        expect(decoded.getPixel(8, 8).r.toInt(), equals(0));
      });
    });

    testWidgets('should include brush strokes in exported inpaint mask', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final layerManager = LayerManager();
        final sourceLayer = layerManager.addLayer(name: '底图');
        final maskLayer = layerManager.addLayer(name: '蒙版');

        layerManager.addStrokeToLayer(
          maskLayer.id,
          StrokeData(
            points: const [
              Offset(12, 24),
              Offset(52, 24),
            ],
            size: 18,
            color: Colors.red,
            opacity: 1,
            hardness: 1,
          ),
        );

        final maskBytes = await ImageExporterNew.exportMaskFromLayers(
          layerManager,
          const Rect.fromLTWH(0, 0, 64, 64),
          excludedBaseImageLayerIds: {sourceLayer.id},
        );

        final decoded = img.decodePng(maskBytes)!;

        expect(decoded.getPixel(32, 24).r.toInt(), greaterThan(240));
        expect(decoded.getPixel(2, 2).r.toInt(), equals(0));

        layerManager.dispose();
      });
    });

    testWidgets(
        'should export inpaint masks with hard edges even when brush hardness is soft',
        (tester) async {
      await tester.runAsync(() async {
        final layerManager = LayerManager();
        final maskLayer = layerManager.addLayer(name: '蒙版');

        layerManager.addStrokeToLayer(
          maskLayer.id,
          StrokeData(
            points: const [
              Offset(32, 12),
              Offset(32, 52),
            ],
            size: 18,
            color: Colors.white,
            opacity: 0.55,
            hardness: 0.1,
          ),
        );

        final maskBytes = await ImageExporterNew.exportMaskFromLayers(
          layerManager,
          const Rect.fromLTWH(0, 0, 64, 64),
          forceHardEdges: true,
        );

        final decoded = img.decodePng(maskBytes)!;

        expect(decoded.getPixel(32, 32).r.toInt(), equals(255));
        expect(decoded.getPixel(20, 32).r.toInt(), equals(0));

        layerManager.dispose();
      });
    });

    testWidgets(
        'should keep accidental strokes on source layer when excluding only the base image',
        (tester) async {
      await tester.runAsync(() async {
        final layerManager = LayerManager();
        final sourceLayer = layerManager.addLayer(name: '底图');

        layerManager.addStrokeToLayer(
          sourceLayer.id,
          StrokeData(
            points: const [
              Offset(16, 16),
              Offset(48, 16),
            ],
            size: 16,
            color: Colors.white,
            opacity: 1,
            hardness: 1,
          ),
        );

        final maskBytes = await ImageExporterNew.exportMaskFromLayers(
          layerManager,
          const Rect.fromLTWH(0, 0, 64, 64),
          excludedBaseImageLayerIds: {sourceLayer.id},
        );

        final decoded = img.decodePng(maskBytes)!;

        expect(decoded.getPixel(32, 16).r.toInt(), greaterThan(240));
        expect(decoded.getPixel(2, 2).r.toInt(), equals(0));

        layerManager.dispose();
      });
    });

    testWidgets(
        'should preserve imported mask pixels while allowing eraser edits', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final layerManager = LayerManager();
        final maskBytes = _buildSolidMaskPng(
          width: 64,
          height: 64,
        );
        final maskLayer = await layerManager.addLayerFromImage(
          maskBytes,
          name: '已有蒙版',
        );

        expect(maskLayer, isNotNull);

        layerManager.addStrokeToLayer(
          maskLayer!.id,
          StrokeData(
            points: const [
              Offset(32, 32),
              Offset(32, 32),
            ],
            size: 20,
            color: Colors.transparent,
            opacity: 1,
            hardness: 1,
            isEraser: true,
          ),
        );

        final exportedBytes = await ImageExporterNew.exportMaskFromLayers(
          layerManager,
          const Rect.fromLTWH(0, 0, 64, 64),
        );

        final decoded = img.decodePng(exportedBytes)!;

        expect(decoded.getPixel(8, 8).r.toInt(), greaterThan(240));
        expect(decoded.getPixel(32, 32).r.toInt(), lessThan(16));

        layerManager.dispose();
      });
    });
  });
}

Uint8List _buildSolidMaskPng({
  required int width,
  required int height,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}
