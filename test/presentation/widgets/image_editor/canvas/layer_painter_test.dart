import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/checkerboard_pattern.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/layer_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/mask_paint_style.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_raster.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';

Future<Color> _paintCanvasPixel({
  required bool showTransparentCanvasBackground,
}) async {
  final state = EditorState()..setCanvasSize(const Size(32, 32));
  addTearDown(state.dispose);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  LayerPainter(
    state: state,
    showTransparentCanvasBackground: showTransparentCanvasBackground,
  ).paint(canvas, const Size(32, 32));

  final picture = recorder.endRecording();
  addTearDown(picture.dispose);
  final image = await picture.toImage(32, 32);
  addTearDown(image.dispose);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);

  final bytes = byteData!.buffer.asUint8List();
  return Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]);
}

void _paintLayer(EditorState state) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  LayerPainter(
    state: state,
    showTransparentCanvasBackground: true,
  ).paint(canvas, state.canvasSize);

  recorder.endRecording().dispose();
}

Color _pixelAt(ByteData byteData, int width, int x, int y) {
  final bytes = byteData.buffer.asUint8List();
  final index = (y * width + x) * 4;
  return Color.fromARGB(
    bytes[index + 3],
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
  );
}

/// 画笔在蒙版层上提交的笔画：蒙版色、蒙版透明度、硬边
StrokeData _maskStroke(List<Offset> points) {
  return StrokeData(
    points: points,
    size: 10,
    color: MaskPaintStyle.color,
    opacity: MaskPaintStyle.opacity,
    hardness: MaskPaintStyle.hardness,
  );
}

/// 白底上绘制整幅画布并取回像素
Future<ByteData> _paintOpaque(EditorState state, Size size) async {
  final recorder = ui.PictureRecorder();
  LayerPainter(state: state).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  addTearDown(picture.dispose);
  final image = await picture.toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  addTearDown(image.dispose);
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

void _expectSameColor(Color actual, Color expected, String reason) {
  for (final (a, e) in [
    (actual.r, expected.r),
    (actual.g, expected.g),
    (actual.b, expected.b),
  ]) {
    expect((a - e).abs() * 255, lessThanOrEqualTo(2), reason: reason);
  }
}

/// 用着色器填充的矩形（棋盘格）在文档坐标中的范围
List<Rect> _shadedRects(TestRecordingCanvas canvas) {
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawRect &&
          (call.invocation.positionalArguments[1] as Paint).shader != null)
        call.invocation.positionalArguments[0] as Rect,
  ];
}

int _alphaByte(Color color) {
  return (color.a * 255).round().clamp(0, 255);
}

int _redByte(Color color) {
  return (color.r * 255).round().clamp(0, 255);
}

Future<ByteData> _paintFramePixels(
  EditorState state, {
  required bool revealOutsideFrame,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  LayerPainter(
    state: state,
    showTransparentCanvasBackground: true,
    revealOutsideFrame: revealOutsideFrame,
  ).paint(canvas, const Size(32, 32));

  final picture = recorder.endRecording();
  addTearDown(picture.dispose);
  final image = await picture.toImage(32, 32);
  addTearDown(image.dispose);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);
  return byteData!;
}

Future<ui.Image> _createSolidImage(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _createTwoToneImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 4),
    Paint()..color = Colors.black,
  );
  canvas.drawRect(
    const Rect.fromLTWH(2, 0, 2, 4),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(4, 4);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(CheckerboardPattern.debugReset);
  tearDown(CheckerboardPattern.debugReset);

  test('default canvas background remains white', () async {
    final color = await _paintCanvasPixel(
      showTransparentCanvasBackground: false,
    );

    expect(color, Colors.white);
  });

  test('transparent canvas background shows checkerboard', () async {
    final color = await _paintCanvasPixel(
      showTransparentCanvasBackground: true,
    );

    expect(color, isNot(Colors.white));
  });

  test('opaque canvas skips the checkerboard under its white base', () {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    final recorder = ui.PictureRecorder();
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: false,
    ).paint(Canvas(recorder), state.canvasSize);
    recorder.endRecording().dispose();

    expect(CheckerboardPattern.debugTileBuildCount, 0);
  });

  test('checkerboard texture is reused across repaints and canvas sizes', () {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    _paintLayer(state);
    _paintLayer(state);
    state.setCanvasSize(const Size(4096, 4096));
    _paintLayer(state);

    expect(CheckerboardPattern.debugTileBuildCount, 1);
  });

  test('zoomed-in checkerboard only covers the visible part of the frame', () {
    const viewport = Size(200, 100);
    const scale = 8.0;
    final state = EditorState()..setCanvasSize(const Size(1024, 1536));
    addTearDown(state.dispose);
    state.canvasController
      ..setViewportSize(viewport)
      ..setScale(scale)
      ..setOffset(const Offset(-4000, -6000));

    final canvas = TestRecordingCanvas();
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: true,
    ).paint(canvas, viewport);

    final shaded = _shadedRects(canvas);
    expect(shaded, hasLength(1));
    // 整框放大后约 8192×12288 像素；只铺可见部分时不超过视口加 1 像素余量
    expect(shaded.single.width * scale, lessThanOrEqualTo(viewport.width + 16));
    expect(
      shaded.single.height * scale,
      lessThanOrEqualTo(viewport.height + 16),
    );
    expect(state.frame.contains(shaded.single.center), isTrue);
  });

  test('checkerboard keeps its cell alignment when panned and zoomed', () async {
    const viewport = Size(32, 32);
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    // 视口显示文档 (10, 10)–(26, 26)，跨过第一格与第二格的分界 16
    state.canvasController
      ..setViewportSize(viewport)
      ..setScale(2)
      ..setOffset(const Offset(-20, -20));

    final recorder = ui.PictureRecorder();
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: true,
    ).paint(Canvas(recorder), viewport);
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    final image = await picture.toImage(32, 32);
    addTearDown(image.dispose);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(_pixelAt(pixels!, 32, 4, 4), Colors.grey.shade300);
    expect(_pixelAt(pixels, 32, 20, 4), Colors.grey.shade100);
    expect(_pixelAt(pixels, 32, 20, 20), Colors.grey.shade300);
  });

  test('zoomed-in layer strokes reach the screen as a cached image', () {
    const viewport = Size(100, 100);
    final state = EditorState()..setCanvasSize(const Size(400, 400));
    addTearDown(state.dispose);
    final layer = state.layerManager.addLayer(name: 'paint');
    for (var i = 0; i < 25; i++) {
      layer.addStroke(
        StrokeData(
          points: [Offset(100.0 + i * 4, 150), Offset(120.0 + i * 4, 250)],
          size: 30,
          color: const Color(0xFF000000),
          opacity: 1,
          hardness: 0.5,
        ),
      );
    }
    state.canvasController
      ..setViewportSize(viewport)
      ..setScale(16)
      ..setOffset(const Offset(-2350, -3150));

    final canvas = TestRecordingCanvas();
    LayerPainter(state: state).paint(canvas, viewport);

    final calls = canvas.invocations.map((c) => c.invocation.memberName);
    expect(calls, contains(#drawImage));
    expect(calls, isNot(contains(#drawPath)));
    expect(layer.debugFlattenedStrokeCount, 25);
  });

  test('repainting reuses the baked layer instead of rebaking', () {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    state.canvasController.setViewportSize(const Size(64, 64));
    state.layerManager
        .addLayer(name: 'paint')
        .addStroke(
          StrokeData(
            points: const [Offset(8, 8), Offset(56, 56)],
            size: 6,
            color: const Color(0xFF000000),
            opacity: 1,
            hardness: 1,
          ),
        );
    var created = 0;
    final previousCreate = ui.Image.onCreate;
    ui.Image.onCreate = (_) => created++;
    addTearDown(() => ui.Image.onCreate = previousCreate);
    void paintOpaque() {
      final recorder = ui.PictureRecorder();
      LayerPainter(state: state).paint(Canvas(recorder), state.canvasSize);
      recorder.endRecording().dispose();
    }

    paintOpaque();
    final afterFirstPaint = created;
    paintOpaque();
    paintOpaque();

    expect(afterFirstPaint, 1);
    expect(created, afterFirstPaint);
  });

  test('checkerboard starts its 16px cells at the frame corner', () async {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    final pixels = await _paintFramePixels(state, revealOutsideFrame: false);

    expect(_pixelAt(pixels, 32, 4, 4), Colors.grey.shade300);
    expect(_pixelAt(pixels, 32, 20, 4), Colors.grey.shade100);
    expect(_pixelAt(pixels, 32, 20, 20), Colors.grey.shade300);
  });

  test('checkerboard paint stays clipped to non-multiple canvas size',
      () async {
    final state = EditorState()..setCanvasSize(const Size(33, 33));
    addTearDown(state.dispose);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    LayerPainter(
      state: state,
      showTransparentCanvasBackground: true,
    ).paint(canvas, const Size(48, 48));

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);

    final image = await picture.toImage(48, 48);
    addTearDown(image.dispose);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);

    final insidePixel = _pixelAt(byteData!, 48, 1, 1);
    final outsidePixel = _pixelAt(byteData, 48, 34, 16);

    expect(_alphaByte(insidePixel), greaterThan(0));
    expect(_alphaByte(outsidePixel), 0);
  });

  test('layer painter does not draw live current stroke preview', () async {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    state.startStroke(const Offset(16, 16));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: false,
    ).paint(canvas, const Size(32, 32));

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);

    final image = await picture.toImage(32, 32);
    addTearDown(image.dispose);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);

    expect(_pixelAt(byteData!, 32, 16, 16), Colors.white);
  });

  test(
    'layer painter filters bitmap layers at fractional sample positions',
    () async {
      final state = EditorState()..setCanvasSize(const Size(4, 4));
      addTearDown(state.dispose);

      final sourceImage = await _createTwoToneImage();
      state.layerManager.addLayerFromUiImage(sourceImage, name: 'two-tone');
      state.canvasController.setViewportSize(const Size(3, 3));
      state.canvasController.setScale(0.75);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      LayerPainter(
        state: state,
        showTransparentCanvasBackground: false,
      ).paint(canvas, const Size(3, 3));

      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = await picture.toImage(3, 3);
      addTearDown(image.dispose);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(byteData, isNotNull);

      final boundaryRed = _redByte(_pixelAt(byteData!, 3, 1, 1));
      expect(boundaryRed, greaterThan(0));
      expect(boundaryRed, lessThan(255));
    },
  );

  test('rotated view keeps layers that rotate into the viewport', () async {
    const red = Color(0xFFFF0000);
    const viewport = Size(128, 32);
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    // 未旋转时这块内容在视口下方，旋转 90° 后落到视口左侧 (4..24, 0..20)
    state.layerManager
        .addLayerFromUiImage(await _createSolidImage(20, 20, red), name: 'red')
        .translateContent(const Offset(0, 40));
    state.canvasController
      ..setViewportSize(viewport)
      ..rotateRight(degrees: 90);

    final recorder = ui.PictureRecorder();
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: true,
    ).paint(Canvas(recorder), viewport);
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    final image = await picture.toImage(128, 32);
    addTearDown(image.dispose);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(_pixelAt(pixels!, 128, 14, 10), red);
  });

  group('mask overlay', () {
    const viewport = Size(48, 48);

    // 横贯 y=24 的一笔已提交蒙版，活动图层是蒙版层、画笔与它同尺寸
    EditorState createState() {
      final state = EditorState()..setCanvasSize(viewport);
      addTearDown(state.dispose);
      final image = state.layerManager.addLayer(name: 'image');
      final mask = state.layerManager.addLayer(
        name: 'mask',
        index: 0,
        role: LayerRole.mask,
      );
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: image.id));
      state.layerManager.setActiveLayer(mask.id);
      state.setBrushSize(10);
      mask.addStroke(_maskStroke(const [Offset(4, 24), Offset(44, 24)]));
      state.canvasController.setViewportSize(viewport);
      return state;
    }

    test('a stroke being painted matches the mask it overlaps', () async {
      final state = createState();
      state.startStroke(const Offset(24, 6));
      state.updateStroke(const Offset(24, 42));

      final pixels = await _paintOpaque(state, viewport);
      final overlap = _pixelAt(pixels, 48, 24, 24);

      expect(overlap, isNot(Colors.white));
      expect(overlap.b, greaterThan(overlap.r));
      _expectSameColor(overlap, _pixelAt(pixels, 48, 24, 12), 'live only');
      _expectSameColor(overlap, _pixelAt(pixels, 48, 10, 24), 'committed only');
    });

    test('magnified mask strokes stay uniform while painting', () async {
      final state = createState();
      // 放大 2 倍，文档 (24, 24) 落在视口中央；视口显示文档 12–36
      state.canvasController
        ..setScale(2)
        ..setOffset(const Offset(-24, -24));
      state.startStroke(const Offset(24, 6));
      state.updateStroke(const Offset(24, 42));

      final pixels = await _paintOpaque(state, viewport);
      final overlap = _pixelAt(pixels, 48, 24, 24);

      expect(overlap, isNot(Colors.white));
      // 文档 (24, 14) 只有正在画的竖笔，(14, 24) 只有已提交的横笔
      _expectSameColor(overlap, _pixelAt(pixels, 48, 24, 4), 'live only');
      _expectSameColor(overlap, _pixelAt(pixels, 48, 4, 24), 'committed only');
    });

    test('magnified mask edges show whole pixels instead of a blur', () async {
      final state = createState();
      // 上方再画一笔，让缓存图向上延伸，被测边缘落在缓存内部而不是图像边界上
      state.layerManager.activeLayer!.addStroke(
        _maskStroke(const [Offset(4, 4), Offset(44, 4)]),
      );
      // 放大 8 倍，视口竖向跨过横笔的上边缘 y=19
      state.canvasController
        ..setScale(8)
        ..setOffset(const Offset(24 - 24 * 8, 24 - 19 * 8));

      final pixels = await _paintOpaque(state, viewport);
      final column = [for (var y = 0; y < 48; y++) _pixelAt(pixels, 48, 24, y)];
      final covered = _pixelAt(pixels, 48, 24, 47);

      expect(column.first, Colors.white);
      expect(covered, isNot(Colors.white));
      for (final color in column) {
        expect(color == Colors.white || color == covered, isTrue,
            reason: 'edge must not blend into $color');
      }
    });

    test('overlapping strokes and a reloaded mask show one overlay', () async {
      final state = createState();
      final mask = state.layerManager.activeLayer!;
      // 载入的旧蒙版是 140 透明度的蒙版色位图
      mask.setBaseRaster(
        LayerRaster(
          await _createSolidImage(
            16,
            16,
            MaskPaintStyle.color.withValues(alpha: 140 / 255),
          ),
        ),
        offset: const Offset(16, 16),
      );
      mask.addStroke(_maskStroke(const [Offset(24, 4), Offset(24, 44)]));

      final pixels = await _paintOpaque(state, viewport);
      final stacked = _pixelAt(pixels, 48, 24, 24);

      _expectSameColor(stacked, _pixelAt(pixels, 48, 24, 8), 'one stroke');
      _expectSameColor(stacked, _pixelAt(pixels, 48, 18, 18), 'reloaded only');
    });

    // 在已有横笔的蒙版层上方再加一个蒙版层，画一道竖笔与横笔相交于 (24, 24)
    Layer addCrossingMaskLayer(EditorState state) {
      final layer = state.layerManager.addLayer(
        name: 'mask 2',
        index: 0,
        role: LayerRole.mask,
      );
      layer.addStroke(_maskStroke(const [Offset(24, 4), Offset(24, 44)]));
      return layer;
    }

    for (final scale in [1.0, 2.0]) {
      test('overlapping mask layers show one overlay at ${scale}x', () async {
        final state = createState();
        addCrossingMaskLayer(state);
        // 文档 (24, 24) 落在视口中央；放大时视口显示文档 12–36
        state.canvasController
          ..setScale(scale)
          ..setOffset(Offset(24 - 24 * scale, 24 - 24 * scale));

        final pixels = await _paintOpaque(state, viewport);
        final overlap = _pixelAt(pixels, 48, 24, 24);
        // 文档 (24, 16) 只有上层的竖笔，(16, 24) 只有下层的横笔
        Color docPixel(int x, int y) => _pixelAt(
          pixels,
          48,
          (24 + (x - 24) * scale).round(),
          (24 + (y - 24) * scale).round(),
        );

        expect(overlap, isNot(Colors.white));
        _expectSameColor(overlap, docPixel(24, 16), 'upper layer only');
        _expectSameColor(overlap, docPixel(16, 24), 'lower layer only');
      });
    }

    test('a faded mask layer stays faint only where it is alone', () async {
      final state = createState();
      final faded = addCrossingMaskLayer(state);
      state.layerManager.setLayerOpacity(faded.id, 0.5);

      final pixels = await _paintOpaque(state, viewport);
      final overlap = _pixelAt(pixels, 48, 24, 24);
      final full = _pixelAt(pixels, 48, 10, 24);
      final fadedOnly = _pixelAt(pixels, 48, 24, 10);

      _expectSameColor(overlap, full, 'covered by a full layer');
      expect(fadedOnly, isNot(Colors.white));
      expect(_redByte(fadedOnly), greaterThan(_redByte(full)));
    });

    test('an image layer between mask layers keeps its stacking', () async {
      final state = EditorState()..setCanvasSize(viewport);
      addTearDown(state.dispose);
      final lower = state.layerManager.addLayer(
        name: 'lower mask',
        role: LayerRole.mask,
      );
      lower.addStroke(_maskStroke(const [Offset(4, 24), Offset(44, 24)]));
      final cover = state.layerManager.addLayer(name: 'cover', index: 0);
      cover.setBaseRaster(
        LayerRaster(await _createSolidImage(16, 48, const Color(0xFFFF0000))),
        offset: const Offset(16, 0),
      );
      final upper = state.layerManager.addLayer(
        name: 'upper mask',
        index: 0,
        role: LayerRole.mask,
      );
      upper.addStroke(_maskStroke(const [Offset(24, 4), Offset(24, 12)]));
      state.canvasController.setViewportSize(viewport);

      final pixels = await _paintOpaque(state, viewport);

      // 下层蒙版被红色图层盖住，上层蒙版叠在红色之上
      expect(_pixelAt(pixels, 48, 20, 24), const Color(0xFFFF0000));
      expect(_pixelAt(pixels, 48, 24, 8), isNot(const Color(0xFFFF0000)));
      expect(_pixelAt(pixels, 48, 8, 24), isNot(Colors.white));
    });
  });

  group('detached frame', () {
    const red = Color(0xFFFF0000);

    Future<EditorState> createState() async {
      final state = EditorState()
        ..allowsDetachedFrame = true
        ..setFrame(const Rect.fromLTWH(16, 0, 16, 32));
      addTearDown(state.dispose);
      state.canvasController.setViewportSize(const Size(32, 32));
      state.layerManager.addLayerFromUiImage(
        await _createSolidImage(32, 32, red),
        name: 'source',
      );
      return state;
    }

    test('reveal mode keeps outside content visible but dimmed', () async {
      final state = await createState();

      final pixels = await _paintFramePixels(state, revealOutsideFrame: true);

      expect(_pixelAt(pixels, 32, 24, 16), red);
      final outside = _pixelAt(pixels, 32, 8, 16);
      expect(_alphaByte(outside), 255);
      expect(outside, isNot(red));
      expect(_redByte(outside), lessThan(255));
    });

    test('clip mode hides everything outside the frame', () async {
      final state = await createState();

      final pixels = await _paintFramePixels(state, revealOutsideFrame: false);

      expect(_pixelAt(pixels, 32, 24, 16), red);
      expect(_alphaByte(_pixelAt(pixels, 32, 8, 16)), 0);
    });

    test('checkerboard follows the frame origin', () async {
      final state = EditorState()
        ..allowsDetachedFrame = true
        ..setFrame(const Rect.fromLTWH(16, 0, 16, 32));
      addTearDown(state.dispose);

      final pixels = await _paintFramePixels(state, revealOutsideFrame: false);

      expect(_alphaByte(_pixelAt(pixels, 32, 4, 4)), 0);
      expect(_alphaByte(_pixelAt(pixels, 32, 20, 4)), greaterThan(0));
    });
  });
}
