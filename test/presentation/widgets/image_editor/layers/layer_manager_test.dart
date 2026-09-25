import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'replaceLayerImage updates base image bytes and notifies listeners', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();
      final originalBytes = _buildSolidPng(8, 8, const Color(0xFFAA3322));
      final replacementBytes = _buildSolidPng(8, 8, const Color(0xFF2244AA));

      final layer = await layerManager.addLayerFromImage(
        originalBytes,
        name: 'source',
      );
      expect(layer, isNotNull);

      var notificationCount = 0;
      layerManager.addListener(() {
        notificationCount++;
      });

      final replaced = await layerManager.replaceLayerImage(
        layer!.id,
        replacementBytes,
      );

      expect(replaced, isTrue);
      expect(layer.baseImageBytes, same(replacementBytes));
      expect(notificationCount, equals(1));

      final missingReplaced = await layerManager.replaceLayerImage(
        'missing-layer',
        originalBytes,
      );

      expect(missingReplaced, isFalse);
      expect(notificationCount, equals(1));

      layerManager.dispose();
    });
  });

  testWidgets(
      'reopened mask layer should remain visible above source and show new strokes',
      (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();
      layerManager.addLayer(name: '图层 1');

      final sourceLayer = await layerManager.addLayerFromImage(
        _buildSolidPng(64, 64, const Color(0xFFAA3322)),
        name: '底图',
      );

      expect(sourceLayer, isNotNull);

      final existingMask = _buildMaskPng(
        width: 64,
        height: 64,
        rect: const Rect.fromLTWH(18, 18, 28, 28),
      );
      final overlayBytes = InpaintMaskUtils.maskToEditorOverlay(
        existingMask,
        overlayAlpha: 255,
      );

      final maskLayer = await layerManager.addLayerFromImage(
        overlayBytes,
        name: '已有蒙版',
        index: layerManager.layers.indexOf(sourceLayer!),
      );

      expect(maskLayer, isNotNull);

      layerManager.addStrokeToLayer(
        maskLayer!.id,
        StrokeData(
          points: const [
            Offset(20, 32),
            Offset(44, 32),
          ],
          size: 8,
          color: Colors.green,
          opacity: 1,
          hardness: 1,
        ),
      );

      final merged = await layerManager.exportMergedImage(
        const Rect.fromLTWH(0, 0, 64, 64),
      );
      final bytes = await merged.toByteData(format: ui.ImageByteFormat.png);
      final decoded = img.decodePng(
        Uint8List.fromList(bytes!.buffer.asUint8List()),
      )!;

      final overlayPixel = decoded.getPixel(24, 24);
      expect(overlayPixel.g.toInt(), equals(170));
      expect(overlayPixel.b.toInt(), equals(255));

      final strokePixel = decoded.getPixel(32, 32);
      expect(strokePixel.g.toInt(), greaterThan(170));
      expect(strokePixel.r.toInt(), lessThan(120));

      merged.dispose();
      layerManager.dispose();
    });
  });

  testWidgets(
      'batched outpaint layer replacement emits one notification and keeps order',
      (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();
      final background = layerManager.addLayer(name: 'background');
      final sourceLayer = await layerManager.addLayerFromImage(
        _buildSolidPng(8, 8, const Color(0xFFAA3322)),
        name: 'source',
      );
      final oldMaskLayer = await layerManager.addLayerFromImage(
        _buildSolidPng(8, 8, const Color(0x6600AAFF)),
        name: 'old mask',
        index: layerManager.layers.indexOf(sourceLayer!),
      );
      expect(oldMaskLayer, isNotNull);

      var notificationCount = 0;
      layerManager.addListener(() {
        notificationCount++;
      });

      Layer? newMaskLayer;
      await layerManager.runBatchAsync(() async {
        newMaskLayer = await layerManager.addLayerFromImage(
          _buildSolidPng(8, 8, const Color(0x6600FF00)),
          name: 'new mask',
          index: layerManager.layers.indexOf(sourceLayer),
        );
        expect(newMaskLayer, isNotNull);

        final replaced = await layerManager.replaceLayerImage(
          sourceLayer.id,
          _buildSolidPng(16, 16, const Color(0xFF2244AA)),
        );
        expect(replaced, isTrue);

        final removed = layerManager.removeLayer(oldMaskLayer!.id);
        expect(removed, isTrue);
      });

      expect(notificationCount, equals(1));
      expect(
        layerManager.layers.map((layer) => layer.id),
        equals([background.id, newMaskLayer!.id, sourceLayer.id]),
      );
      expect(layerManager.activeLayerId, equals(newMaskLayer!.id));
      expect(sourceLayer.baseImageBytes, isNotNull);

      layerManager.dispose();
    });
  });

  testWidgets('nested batches still emit only one final notification', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();

      var notificationCount = 0;
      layerManager.addListener(() {
        notificationCount++;
      });

      layerManager.runBatch(() {
        layerManager.addLayer(name: 'bottom');
        layerManager.runBatch(() {
          layerManager.addLayer(name: 'top');
        });

        expect(notificationCount, equals(0));
      });

      expect(notificationCount, equals(1));
      expect(
        layerManager.layers.map((layer) => layer.name),
        equals(['bottom', 'top']),
      );

      layerManager.dispose();
    });
  });

  testWidgets('active layer notifiers flush only after outer batch completion',
      (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();
      final bottomLayer = layerManager.addLayer(name: 'bottom');
      final topLayer = layerManager.addLayer(name: 'top');

      final activeLayerEvents = <String?>[];
      final bottomActiveEvents = <bool>[];
      final topActiveEvents = <bool>[];
      layerManager.activeLayerNotifier.addListener(() {
        activeLayerEvents.add(layerManager.activeLayerNotifier.value);
      });
      bottomLayer.isActiveNotifier.addListener(() {
        bottomActiveEvents.add(bottomLayer.isActiveNotifier.value);
      });
      topLayer.isActiveNotifier.addListener(() {
        topActiveEvents.add(topLayer.isActiveNotifier.value);
      });

      layerManager.runBatch(() {
        layerManager.runBatch(() {
          final temporaryLayer = layerManager.addLayer(name: 'temporary');
          expect(layerManager.activeLayerId, temporaryLayer.id);

          final removed = layerManager.removeLayer(temporaryLayer.id);
          expect(removed, isTrue);
          expect(layerManager.activeLayerId, topLayer.id);
        });

        layerManager.setActiveLayer(bottomLayer.id);
        expect(layerManager.activeLayerId, bottomLayer.id);
        expect(activeLayerEvents, isEmpty);
        expect(bottomActiveEvents, isEmpty);
        expect(topActiveEvents, isEmpty);
        expect(bottomLayer.isActiveNotifier.value, isFalse);
        expect(topLayer.isActiveNotifier.value, isTrue);
      });

      expect(activeLayerEvents, equals([bottomLayer.id]));
      expect(bottomActiveEvents, equals([true]));
      expect(topActiveEvents, equals([false]));
      expect(bottomLayer.isActiveNotifier.value, isTrue);
      expect(topLayer.isActiveNotifier.value, isFalse);

      layerManager.dispose();
    });
  });

  testWidgets(
      'batched rollback can remove a new mask after replacement failure', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layerManager = LayerManager();
      final sourceLayer = await layerManager.addLayerFromImage(
        _buildSolidPng(8, 8, const Color(0xFFAA3322)),
        name: 'source',
      );
      final existingMaskLayer = await layerManager.addLayerFromImage(
        _buildSolidPng(8, 8, const Color(0x6600AAFF)),
        name: 'existing mask',
        index: layerManager.layers.indexOf(sourceLayer!),
      );
      expect(existingMaskLayer, isNotNull);

      var notificationCount = 0;
      layerManager.addListener(() {
        notificationCount++;
      });

      Object? replacementError;
      await layerManager.runBatchAsync(() async {
        final newMaskLayer = await layerManager.addLayerFromImage(
          _buildSolidPng(8, 8, const Color(0x6600FF00)),
          name: 'new mask',
          index: layerManager.layers.indexOf(sourceLayer),
        );
        expect(newMaskLayer, isNotNull);

        try {
          await layerManager.replaceLayerImage(
            sourceLayer.id,
            Uint8List.fromList(const [1, 2, 3, 4]),
          );
        } catch (error) {
          replacementError = error;
          final removed = layerManager.removeLayer(newMaskLayer!.id);
          expect(removed, isTrue);
        }
      });

      expect(replacementError, isNotNull);
      expect(notificationCount, equals(1));
      expect(
        layerManager.layers.map((layer) => layer.id),
        equals([existingMaskLayer!.id, sourceLayer.id]),
      );
      expect(layerManager.activeLayerId, equals(sourceLayer.id));
      expect(sourceLayer.baseImageBytes, isNotNull);

      layerManager.dispose();
    });
  });
}

Uint8List _buildSolidPng(int width, int height, Color color) {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgba8(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      (color.a * 255).round().clamp(0, 255),
    ),
  );
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _buildMaskPng({
  required int width,
  required int height,
  required Rect rect,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 255));
  img.fillRect(
    image,
    x1: rect.left.round(),
    y1: rect.top.round(),
    x2: rect.right.round() - 1,
    y2: rect.bottom.round() - 1,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  return Uint8List.fromList(img.encodePng(image));
}
