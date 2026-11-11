import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/snapshot_cache.dart';

import '../../../../helpers/live_image_counter.dart';
import 'layer_pixel_test_helpers.dart';

const _region = Rect.fromLTWH(0, 0, 64, 64);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LiveImageCounter live;
  setUp(() => live = LiveImageCounter()..install());
  tearDown(() => live.restore());

  testWidgets('a decoded base image is owned until the layer is disposed', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await solidPng(8, 8, Colors.red);
      final layer = Layer(name: 'imported');
      try {
        expect(await layer.setBaseImage(bytes), isTrue);
        expect(layer.baseImage, isNotNull);
        expect(live.count, 1);
      } finally {
        layer.dispose();
      }
      expect(live.count, 0);
    });
  });

  testWidgets('a base image decoded after layer disposal is released', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await solidPng(8, 8, Colors.red);
      final layer = Layer(name: 'imported');
      final created = live.created;
      final pending = layer.setBaseImage(bytes);
      layer.dispose();

      expect(await pending, isFalse);
      expect(layer.baseImage, isNull);
      expect(live.created, greaterThan(created));
      expect(live.count, 0);
    });
  });

  testWidgets('an imported layer decoded after manager disposal is released', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await solidPng(8, 8, Colors.red);
      final manager = LayerManager();
      var notifications = 0;
      manager.addListener(() => notifications++);
      final created = live.created;
      final pending = manager.addLayerFromImage(
        bytes,
        offset: const Offset(3, 4),
      );
      manager.dispose();

      expect(await pending, isNull);
      expect(manager.layers, isEmpty);
      expect(notifications, 0);
      expect(live.created, greaterThan(created));
      expect(live.count, 0);
    });
  });

  for (final disposeManager in [false, true]) {
    testWidgets(
      'a replacement decoded after disposal is rejected (manager: $disposeManager)',
      (tester) async {
        await tester.runAsync(() async {
          final bytes = await solidPng(8, 8, Colors.red);
          final manager = LayerManager();
          if (!disposeManager) addTearDown(manager.dispose);
          final layer = manager.addLayer();
          var notifications = 0;
          manager.addListener(() => notifications++);
          final created = live.created;
          final pending = manager.replaceLayerImage(layer.id, bytes);
          if (disposeManager) {
            manager.dispose();
          } else {
            manager.removeLayer(layer.id);
            notifications = 0;
          }

          expect(await pending, isFalse);
          expect(layer.baseImage, isNull);
          expect(notifications, 0);
          expect(live.created, greaterThan(created));
          expect(live.count, 0);
        });
      },
    );

    testWidgets(
      'a base replacement decoded after disposal is rejected (manager: $disposeManager)',
      (tester) async {
        await tester.runAsync(() async {
          final bytes = await solidPng(8, 8, Colors.red);
          final manager = LayerManager();
          if (!disposeManager) addTearDown(manager.dispose);
          final layer = manager.addLayer();
          var notifications = 0;
          manager.addListener(() => notifications++);
          final created = live.created;
          final pending = manager.replaceLayerBaseImage(
            layer.id,
            bytes,
            offset: const Offset(3, 4),
          );
          if (disposeManager) {
            manager.dispose();
          } else {
            manager.removeLayer(layer.id);
            notifications = 0;
          }

          expect(await pending, isNull);
          expect(layer.baseImage, isNull);
          expect(layer.baseImageOffset, Offset.zero);
          expect(notifications, 0);
          expect(live.created, greaterThan(created));
          expect(live.count, 0);
        });
      },
    );
  }

  testWidgets('the shown thumbnail stays usable until its replacement is ready', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layer = _layerWithStroke();
      addTearDown(layer.dispose);
      await layer.updateThumbnail(_region);
      final previous = layer.thumbnail!;

      layer.markNeedsUpdate();
      final pending = layer.updateThumbnail(_region);
      expect(previous.debugDisposed, isFalse);
      expect(layer.thumbnail, same(previous));

      await pending;
      expect(previous.debugDisposed, isTrue);
      expect(layer.thumbnail!.debugDisposed, isFalse);
    });
  });

  testWidgets('a thumbnail render finishing after dispose is released', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layer = _layerWithStroke();
      final recorder = ui.PictureRecorder();
      layer.renderWithCache(Canvas(recorder));
      recorder.endRecording().dispose();
      final thumbnail = layer.updateThumbnail(_region);
      layer.dispose();
      await thumbnail;

      expect(live.count, 0);
    });
  });

  testWidgets('a canvas snapshot finishing after dispose is released', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final manager = CanvasSnapshotManager(
        renderCallback: (canvas) => canvas.drawRect(
          _region,
          Paint()..color = const Color(0xFF336699),
        ),
      );
      final pending = manager.updateSnapshotAsync(_region);
      manager.dispose();

      expect(await pending, isFalse);
      expect(live.count, 0);
    });
  });
}

Layer _layerWithStroke() {
  return Layer(name: 'paint')..addStroke(
    StrokeData(
      points: const [Offset(8, 8), Offset(40, 40)],
      size: 6,
      color: const Color(0xFFFFFFFF),
      opacity: 1,
      hardness: 1,
    ),
  );
}
