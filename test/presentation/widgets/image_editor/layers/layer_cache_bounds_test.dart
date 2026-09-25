import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';

const _region = Rect.fromLTWH(-80, -20, 100, 100);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'raster and composite caches cover negative coordinates and soft halos',
    (tester) async {
      await tester.runAsync(() async {
        final layer = Layer(name: 'mask');
        addTearDown(layer.dispose);
        layer.addStroke(
          _stroke(const [Offset(-30, -10), Offset(-10, -10)], size: 6),
        );
        layer.addStroke(
          _stroke(const [Offset(-60, 40)], size: 20, hardness: 0),
        );

        final direct = await _rgba(await layer.renderToImage(_region));
        await layer.rasterize();
        await layer.updateCompositeCache();
        expect(layer.rasterizedImage, isNotNull);
        expect(layer.compositedCache, isNotNull);
        final cached = await _rgba(await layer.renderToImage(_region));

        // 硬笔画中心 (-20, -10) 与软笔刷光晕 (-45, 40) 都位于负坐标区
        expect(_alpha(cached, 60, 10), 255);
        expect(_alpha(direct, 35, 60), greaterThan(0));
        for (var i = 3; i < direct.length; i += 4) {
          expect(
            (cached[i] - direct[i]).abs(),
            lessThanOrEqualTo(1),
            reason: 'alpha mismatch at pixel ${i ~/ 4}',
          );
        }
      });
    },
  );

  testWidgets('incremental rasterize grows the cache for new strokes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final layer = Layer(name: 'mask');
      addTearDown(layer.dispose);
      layer.addStroke(_stroke(const [Offset(-70, 0), Offset(-60, 0)]));
      await layer.rasterize();

      // 第二笔远在第一笔缓存范围之外，增量光栅化必须扩展缓存区域
      layer.addStroke(_stroke(const [Offset(0, 60), Offset(10, 60)]));
      await layer.rasterize();
      await layer.updateCompositeCache();

      final cached = await _rgba(await layer.renderToImage(_region));
      expect(_alpha(cached, 15, 20), 255, reason: 'first stroke');
      expect(_alpha(cached, 85, 80), 255, reason: 'second stroke');
    });
  });
}

StrokeData _stroke(
  List<Offset> points, {
  double size = 8,
  double hardness = 1,
}) {
  return StrokeData(
    points: points,
    size: size,
    color: const Color(0xFFFFFFFF),
    opacity: 1,
    hardness: hardness,
  );
}

Future<Uint8List> _rgba(ui.Image image) async {
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

int _alpha(Uint8List rgba, int x, int y) {
  return rgba[(y * _region.width.toInt() + x) * 4 + 3];
}
