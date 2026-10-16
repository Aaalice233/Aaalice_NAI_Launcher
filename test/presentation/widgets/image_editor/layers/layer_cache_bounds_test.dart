import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/stroke_rendering.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_raster.dart';

import '../../../../helpers/live_image_counter.dart';
import 'layer_pixel_test_helpers.dart';

const _region = Rect.fromLTWH(-80, -20, 100, 100);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LiveImageCounter live;
  setUp(() => live = LiveImageCounter()..install());
  tearDown(() => live.restore());

  test(
    'cached pixels match direct rendering at negative coordinates and soft halos',
    () async {
      final layer = Layer(name: 'mask');
      addTearDown(layer.dispose);
      final strokes = [
        _stroke(const [Offset(-30, -10), Offset(-10, -10)], size: 6),
        _stroke(const [Offset(-60, 40)], size: 20, hardness: 0),
      ];
      strokes.forEach(layer.addStroke);

      final cached = await _rgba(await layer.renderToImage(_region));
      final direct = await _directRgba(strokes, _region);

      expect(layer.debugFlattenedStrokeCount, 2);
      // 硬笔画中心 (-20, -10) 与软笔刷光晕 (-45, 40) 都位于负坐标区
      expect(_alpha(cached, 60, 10), 255);
      expect(_alpha(direct, 35, 60), greaterThan(0));
      _expectSameAlpha(cached, direct);
    },
  );

  test('later strokes are baked incrementally and grow the cache', () async {
    final layer = Layer(name: 'mask');
    addTearDown(layer.dispose);
    layer.addStroke(_stroke(const [Offset(-70, 0), Offset(-60, 0)]));
    _paint(layer);
    final firstBounds = layer.debugFlattenedBounds!;

    // 第二笔远在第一笔缓存范围之外，增量烘焙必须扩展缓存区域
    layer.addStroke(_stroke(const [Offset(0, 60), Offset(10, 60)]));
    final created = live.created;
    _paint(layer);

    expect(live.created - created, 1, reason: 'one bake per paint');
    expect(layer.debugFlattenedStrokeCount, 2);
    expect(layer.debugFlattenedBounds!.contains(firstBounds.topLeft), isTrue);
    final cached = await _rgba(await layer.renderToImage(_region));
    expect(_alpha(cached, 15, 20), 255, reason: 'first stroke');
    expect(_alpha(cached, 85, 80), 255, reason: 'second stroke');
  });

  test('repainting an unchanged layer reuses the cache', () {
    final layer = Layer(name: 'mask');
    addTearDown(layer.dispose);
    layer.addStroke(_stroke(const [Offset(-40, 0), Offset(-20, 0)]));
    _paint(layer);

    final created = live.created;
    _paint(layer);
    _paint(layer);

    expect(live.created, created);
  });

  test(
    'erasers clear the base image and earlier strokes when baked incrementally',
    () async {
      final layer = Layer(name: 'paint');
      addTearDown(layer.dispose);
      const baseOffset = Offset(-70, -10);
      final base = await solidImage(60, 60, const Color(0xFFFF0000));
      layer.setBaseRaster(LayerRaster(base), offset: baseOffset);
      final brush = _stroke(const [Offset(-60, 30), Offset(0, 30)], size: 8);
      layer.addStroke(brush);
      _paint(layer);

      final eraser = _stroke(
        const [Offset(-40, -10), Offset(-40, 60)],
        size: 10,
        isEraser: true,
      );
      layer.addStroke(eraser);
      final cached = await _rgba(await layer.renderToImage(_region));
      final direct = await _directRgba(
        [brush, eraser],
        _region,
        base: (base, baseOffset),
      );

      expect(layer.debugFlattenedStrokeCount, 2);
      expect(_alpha(cached, 40, 30), 0, reason: 'eraser crosses base');
      expect(_alpha(cached, 40, 50), 0, reason: 'eraser crosses brush');
      expect(_alpha(cached, 75, 50), 255, reason: 'brush beyond the base');
      expect(_alpha(cached, 20, 20), 255, reason: 'base beside the eraser');
      _expectSameAlpha(cached, direct);
    },
  );

  test('undoing a baked stroke rebuilds the cache without it', () async {
    final layer = Layer(name: 'mask');
    addTearDown(layer.dispose);
    layer.addStroke(_stroke(const [Offset(-70, 0), Offset(-60, 0)]));
    layer.addStroke(_stroke(const [Offset(0, 60), Offset(10, 60)]));
    _paint(layer);

    layer.removeLastStroke();
    final cached = await _rgba(await layer.renderToImage(_region));

    expect(layer.debugFlattenedStrokeCount, 1);
    expect(_alpha(cached, 15, 20), 255, reason: 'remaining stroke');
    expect(_alpha(cached, 85, 80), 0, reason: 'undone stroke');
  });

  test('undoing a stroke that was never baked keeps the cache', () {
    final layer = Layer(name: 'mask');
    addTearDown(layer.dispose);
    layer.addStroke(_stroke(const [Offset(-70, 0), Offset(-60, 0)]));
    _paint(layer);
    final bounds = layer.debugFlattenedBounds;

    layer.addStroke(_stroke(const [Offset(0, 60), Offset(10, 60)]));
    layer.removeLastStroke();
    final created = live.created;
    _paint(layer);

    expect(live.created, created);
    expect(layer.debugFlattenedStrokeCount, 1);
    expect(layer.debugFlattenedBounds, bounds);
  });

  test('restored strokes are baked together on the first paint', () {
    final source = Layer(name: 'mask');
    addTearDown(source.dispose);
    for (var i = 0; i < 30; i++) {
      source.addStroke(
        _stroke([Offset(-70.0 + i, 0), Offset(-60.0 + i, 10)]),
      );
    }
    final snapshot = source.captureContent();
    addTearDown(snapshot.dispose);
    final restored = Layer(name: 'mask')..restoreContent(snapshot);
    addTearDown(restored.dispose);

    final created = live.created;
    _paint(restored);

    expect(restored.debugFlattenedStrokeCount, 30);
    expect(live.created - created, 1);
  });

  test('a layer with only a base image draws it without a cache copy', () async {
    final layer = Layer(name: 'source');
    addTearDown(layer.dispose);
    final base = await solidImage(20, 20, const Color(0xFF00FF00));
    layer.setBaseRaster(LayerRaster(base));

    final created = live.created;
    _paint(layer);

    expect(live.created, created);
    expect(layer.debugFlattenedBounds, isNull);
  });

  test('whole-pixel moves shift the cache, fractional moves rebake it', () {
    final layer = Layer(name: 'mask');
    addTearDown(layer.dispose);
    layer.addStroke(_stroke(const [Offset(-40, 0), Offset(-20, 0)]));
    _paint(layer);
    final bounds = layer.debugFlattenedBounds!;

    layer.translateContent(const Offset(3, 4));
    final created = live.created;
    _paint(layer);
    expect(live.created, created);
    expect(layer.debugFlattenedBounds, bounds.shift(const Offset(3, 4)));

    layer.translateContent(const Offset(0.5, 0));
    _paint(layer);
    expect(live.created - created, 1);
  });

  test('disposing releases the cache and every replaced bake', () {
    final layer = Layer(name: 'mask');
    layer.addStroke(_stroke(const [Offset(-40, 0), Offset(-20, 0)]));
    _paint(layer);
    layer.addStroke(_stroke(const [Offset(0, 40), Offset(10, 40)]));
    _paint(layer);
    layer.removeLastStroke();
    _paint(layer);

    layer.dispose();

    expect(live.count, 0);
  });
}

StrokeData _stroke(
  List<Offset> points, {
  double size = 8,
  double hardness = 1,
  bool isEraser = false,
}) {
  return StrokeData(
    points: points,
    size: size,
    color: const Color(0xFFFFFFFF),
    opacity: 1,
    hardness: hardness,
    isEraser: isEraser,
  );
}

/// 按屏幕绘制路径画一次，触发缓存烘焙
void _paint(Layer layer) {
  final recorder = ui.PictureRecorder();
  layer.renderWithCache(Canvas(recorder));
  recorder.endRecording().dispose();
}

/// 不经图层缓存，直接按笔画规则把底图与笔画画进独立图层
Future<Uint8List> _directRgba(
  List<StrokeData> strokes,
  Rect region, {
  (ui.Image, Offset)? base,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(-region.left, -region.top);
  canvas.saveLayer(region, Paint());
  if (base != null) {
    canvas.drawImage(base.$1, base.$2, Paint());
  }
  for (final stroke in strokes) {
    final paint = Paint()..color = stroke.color;
    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
    }
    StrokeRendering.draw(
      canvas,
      stroke.points,
      paint,
      size: stroke.size,
      hardness: stroke.hardness,
    );
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final ui.Image image;
  try {
    image = await picture.toImage(region.width.toInt(), region.height.toInt());
  } finally {
    picture.dispose();
  }
  return _rgba(image);
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

void _expectSameAlpha(Uint8List actual, Uint8List expected) {
  for (var i = 3; i < expected.length; i += 4) {
    expect(
      (actual[i] - expected[i]).abs(),
      lessThanOrEqualTo(1),
      reason: 'alpha mismatch at pixel ${i ~/ 4}',
    );
  }
}
