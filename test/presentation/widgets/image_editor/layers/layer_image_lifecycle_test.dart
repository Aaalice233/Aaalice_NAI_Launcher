import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/snapshot_cache.dart';

const _region = Rect.fromLTWH(0, 0, 64, 64);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _LiveImages live;
  setUp(() => live = _LiveImages()..install());
  tearDown(() => live.restore());

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

// 只统计安装之后创建的图像：创建加一、释放减一
class _LiveImages {
  int count = 0;
  ui.ImageEventCallback? _previousCreate;
  ui.ImageEventCallback? _previousDispose;

  void install() {
    _previousCreate = ui.Image.onCreate;
    _previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (_) => count++;
    ui.Image.onDispose = (_) => count--;
  }

  void restore() {
    ui.Image.onCreate = _previousCreate;
    ui.Image.onDispose = _previousDispose;
  }
}
