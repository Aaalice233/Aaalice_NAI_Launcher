import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/fill_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _canvas = Rect.fromLTWH(0, 0, 64, 64);
const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _blue = Color(0xFF0000FF);

void main() {
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a second tap samples the result of the first fill', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _canvasWith(_splitImage);
      final tool = FillTool()..setTolerance(120);

      state.setForegroundColor(_red);
      _tap(tool, state, const Offset(48, 32));
      state.setForegroundColor(_green);
      _tap(tool, state, const Offset(16, 32));
      await _settle(state);

      expect(state.historyManager.undoStackSize, 2);
      expect(layer.strokes[0].points, hasLength(64 * 32));
      expect(
        layer.strokes[1].points.length,
        greaterThan(64 * 32),
        reason: '右半边已被第一次填成红色，与左半边连成一片',
      );
    });
  });

  testWidgets('changes made while sampling are included before writing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _canvasWith(null);
      final tool = FillTool()..setTolerance(0);
      state.setForegroundColor(_blue);

      _tap(tool, state, const Offset(10, 32));
      // 让排队的填充先开始回读，再在回读期间画一道隔墙
      await Future<void>.value();
      state.historyManager.execute(
        AddStrokeAction(layerId: layer.id, stroke: _wall()),
        state,
      );
      await _settle(state);

      expect(state.historyManager.undoStackSize, 2);
      final fill = layer.strokes.last;
      expect(fill.color, _blue);
      expect(fill.points.length, inExclusiveRange(0, 64 * 32));
      final pixels = await LayerPixels.of(layer, _canvas);
      expect(pixels.alphaAt(48, 32), 0, reason: '隔墙右侧不被填充');
    });
  });

  testWidgets('undo while a fill is pending undoes that fill', (tester) async {
    await tester.runAsync(() async {
      final (state, layer) = await _canvasWith(null);
      state.historyManager.execute(
        AddStrokeAction(layerId: layer.id, stroke: _wall()),
        state,
      );
      final tool = FillTool()..setTolerance(0);
      state.setForegroundColor(_blue);

      _tap(tool, state, const Offset(10, 32));
      expect(state.undo(), isTrue);
      await _settle(state);

      expect(layer.strokes, hasLength(1), reason: '先画的隔墙保留');
      expect(layer.strokes.single.color, _red);
      expect(state.historyManager.canRedo, isTrue);
      state.redo();
      await _settle(state);
      expect(layer.strokes.last.color, _blue);
    });
  });

  testWidgets('the layer and colour are fixed at the moment of the tap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, first) = await _canvasWith(null);
      final second = state.layerManager.addLayer(name: 'second', index: 0);
      state.layerManager.setActiveLayer(first.id);
      final tool = FillTool()..setTolerance(0);
      state.setForegroundColor(_blue);

      _tap(tool, state, const Offset(10, 32));
      state.setForegroundColor(_green);
      state.layerManager.setActiveLayer(second.id);
      await _settle(state);

      expect(second.strokes, isEmpty);
      expect(first.strokes.single.color, _blue);
    });
  });
}

typedef _Paint = void Function(Canvas canvas);

Future<(EditorState, Layer)> _canvasWith(_Paint? paint) async {
  final state = EditorState()..setCanvasSize(_canvas.size);
  addTearDown(state.dispose);
  final layer = state.layerManager.addLayer(name: 'layer');
  if (paint != null) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    picture.dispose();
    state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
  }
  return (state, layer);
}

void _splitImage(Canvas canvas) {
  canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 64), Paint()..color = _red);
  canvas.drawRect(const Rect.fromLTWH(32, 0, 32, 64), Paint()..color = _blue);
}

/// 竖在画布中线上的红色隔墙
StrokeData _wall() => StrokeData(
  points: const [Offset(32, -4), Offset(32, 68)],
  size: 4,
  color: _red,
  opacity: 1,
  hardness: 1,
);

void _tap(FillTool tool, EditorState state, Offset position) {
  tool.onPointerDown(PointerDownEvent(position: position), state);
  tool.onPointerUp(PointerUpEvent(position: position), state);
}

Future<void> _settle(EditorState state) =>
    state.pixelReadbacks.idle.timeout(const Duration(seconds: 10));
