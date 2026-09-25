import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/clone_stamp_tool.dart';

void main() {
  group('选取源点', () {
    testWidgets('选中工具即处于取源点状态，松开时才提交源点', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      expect(tool.isPickingSource, isTrue);

      _press(tool, state, const Offset(10, 12));
      expect(tool.sourcePoint, isNull, reason: '按下只瞄准，不提交');
      expect(tool.sourceMarker.value, const Offset(10, 12));

      _drag(tool, state, const Offset(14, 16));
      expect(tool.sourceMarker.value, const Offset(14, 16));

      _release(tool, state, const Offset(14, 16));
      expect(tool.sourcePoint, const Offset(14, 16));
      expect(tool.isPickingSource, isFalse);
      expect(tool.canvasSnapshot, isNotNull);
      expect(tool.sourceOffset, isNull);
      expect(tool.sourceMarker.value, const Offset(14, 16));
      expect(state.isDrawing, isFalse, reason: '瞄准不产生笔画');
    });

    testWidgets('瞄准被取消（第二根手指落下或系统取消）时不设源点', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();

      _press(tool, state, const Offset(10, 10));
      tool.onPointerCancel(state);

      expect(tool.sourcePoint, isNull);
      expect(tool.isPickingSource, isTrue);
      expect(tool.sourceMarker.value, isNull);
      expect(tool.canvasSnapshot, isNull);
    });

    testWidgets('已有源点时重新瞄准被取消，保留原源点与准星', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));
      tool.setPickingSource(true);

      _press(tool, state, const Offset(30, 30));
      tool.onPointerCancel(state);

      expect(tool.sourcePoint, const Offset(10, 10));
      expect(tool.sourceMarker.value, const Offset(10, 10));
      expect(tool.isPickingSource, isTrue, reason: '取消后仍可再点一次');
    });

    testWidgets('以松开位置为准，松开在取景框外不接受并保持取源点状态', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();

      _press(tool, state, const Offset(10, 10));
      _drag(tool, state, const Offset(80, 10));
      _release(tool, state, const Offset(80, 10));
      expect(tool.sourcePoint, isNull);
      expect(tool.isPickingSource, isTrue);
      expect(tool.sourceMarker.value, isNull);

      _press(tool, state, const Offset(80, 10));
      _drag(tool, state, const Offset(20, 10));
      _release(tool, state, const Offset(20, 10));
      expect(tool.sourcePoint, const Offset(20, 10));
    });

    testWidgets('未开启取源点时 Alt+点击仍可设源点', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool()..setPickingSource(false);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      _tap(tool, state, const Offset(20, 24));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(tool.sourcePoint, const Offset(20, 24));
      expect(tool.isPickingSource, isFalse);
      expect(state.isDrawing, isFalse);
    });

    testWidgets('手动关闭取源点且没有源点时，点按不设源点也不起笔', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool()..setPickingSource(false);

      _tap(tool, state, const Offset(20, 24));

      expect(tool.sourcePoint, isNull);
      expect(tool.sourceMarker.value, isNull);
      expect(state.isDrawing, isFalse);
    });

    testWidgets('重新开启取源点后提交新源点，对齐随之重置', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));
      _stroke(tool, state, const [Offset(40, 20)]);
      expect(tool.sourceOffset, const Offset(30, 10));

      tool.setPickingSource(true);
      _tap(tool, state, const Offset(5, 50));

      expect(tool.sourcePoint, const Offset(5, 50));
      expect(tool.sourceOffset, isNull);
      expect(tool.isPickingSource, isFalse);
      await tester.pump();
    });

    testWidgets('切换工具清空源点并恢复取源点状态', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      tool.onDeactivateFast(state);

      expect(tool.sourcePoint, isNull);
      expect(tool.isPickingSource, isTrue);
      expect(tool.sourceMarker.value, isNull);
      expect(tool.canvasSnapshot, isNull);
      expect(tool.sourceOffset, isNull);
    });

    testWidgets('面板监听只随源点与取源点状态通知，准星移动不触发', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      var notifications = 0;
      tool.sourceListenable.addListener(() => notifications++);

      _press(tool, state, const Offset(10, 10));
      _drag(tool, state, const Offset(12, 12));
      expect(notifications, 0);

      _release(tool, state, const Offset(12, 12));
      expect(notifications, greaterThan(0));

      notifications = 0;
      _stroke(tool, state, const [Offset(40, 20), Offset(44, 24)]);
      expect(notifications, 0, reason: '涂抹只移动准星');
      await tester.pump();
    });
  });

  group('涂抹对齐', () {
    testWidgets('首笔按源点对齐，准星跟随取样位置并停在最后取样处', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      _press(tool, state, const Offset(40, 20));
      expect(tool.sourceOffset, const Offset(30, 10));
      expect(tool.sourceMarker.value, const Offset(10, 10));

      _drag(tool, state, const Offset(46, 24));
      expect(tool.sourceMarker.value, const Offset(16, 14));

      _release(tool, state, const Offset(46, 24));
      expect(state.isDrawing, isFalse);
      expect(tool.sourceMarker.value, const Offset(16, 14));

      _press(tool, state, const Offset(50, 50));
      expect(tool.sourceOffset, const Offset(30, 10), reason: '后续笔画沿用对齐');
      expect(tool.sourceMarker.value, const Offset(20, 40));
      _release(tool, state, const Offset(50, 50));
      await tester.pump();
    });

    testWidgets('首笔被双指缩放取消时不锁定对齐，下一笔仍从源点起', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      _press(tool, state, const Offset(40, 20));
      tool.onPointerCancel(state);

      expect(state.isDrawing, isFalse);
      expect(tool.sourceOffset, isNull);
      expect(tool.sourceMarker.value, const Offset(10, 10));

      _press(tool, state, const Offset(50, 30));
      expect(tool.sourceOffset, const Offset(40, 20));
      expect(tool.sourceMarker.value, const Offset(10, 10));
      tool.onPointerCancel(state);
    });

    testWidgets('被 Esc 取消的首笔同样作废对齐', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      _press(tool, state, const Offset(40, 20));
      state.cancelStroke();
      _release(tool, state, const Offset(40, 20));

      expect(tool.sourceOffset, isNull);
      expect(tool.sourceMarker.value, const Offset(10, 10));
      await tester.pump();
    });

    testWidgets('已有对齐时笔画被取消，保留原对齐与准星', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));
      _stroke(tool, state, const [Offset(40, 20), Offset(42, 20)]);

      _press(tool, state, const Offset(60, 60));
      _drag(tool, state, const Offset(62, 60));
      tool.onPointerCancel(state);

      expect(tool.sourceOffset, const Offset(30, 10));
      expect(tool.sourceMarker.value, const Offset(12, 10));
      await tester.pump();
    });

    testWidgets('起笔落在取景框外时按裁进框内的点对齐', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      _press(tool, state, const Offset(-20, 20));

      expect(state.currentStrokePoints.first, const Offset(0, 20));
      expect(tool.sourceOffset, const Offset(-10, 10));
      expect(
        tool.sourceMarker.value,
        const Offset(10, 10),
        reason: '首个取样点仍是源点',
      );
      tool.onPointerCancel(state);
    });

    testWidgets('涂抹中按下 Alt 不会卡住笔画', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool();
      _tap(tool, state, const Offset(10, 10));

      _press(tool, state, const Offset(40, 20));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      _drag(tool, state, const Offset(44, 20));
      expect(state.currentStrokePoints, hasLength(2));
      _release(tool, state, const Offset(44, 20));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(state.isDrawing, isFalse);
      expect(tool.sourcePoint, const Offset(10, 10), reason: 'Alt 不把这一笔变成瞄准');
      await tester.pump();
    });
  });

  group('应用仿制', () {
    testWidgets('松开后把源点像素仿制到活动图层', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool()..setSize(8);

      final bytes = await tester.runAsync(() async {
        final layer = await state.layerManager.addLayerFromImage(_splitPng());
        _tap(tool, state, const Offset(16, 32));
        final applied = _nextHistoryChange(state);
        _stroke(tool, state, const [Offset(48, 32)]);
        await applied.timeout(const Duration(seconds: 10));
        return layer!.baseImageBytes!;
      });
      await tester.pump();

      final result = img.decodePng(bytes!)!;
      _expectRed(result.getPixel(48, 32), reason: '笔刷中心取自源点');
      _expectBlue(result.getPixel(48, 20), reason: '笔刷外保持原样');
      _expectRed(result.getPixel(16, 32), reason: '源点本身不受影响');
    });

    testWidgets('应用等待期间重设源点，本次合成仍用原取样参数', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool()..setSize(8);

      final bytes = await tester.runAsync(() async {
        final layer = await state.layerManager.addLayerFromImage(_splitPng());
        _tap(tool, state, const Offset(16, 32));
        final applied = _nextHistoryChange(state);
        _stroke(tool, state, const [Offset(48, 32)]);

        // 合成挂起在图层渲染上时重新取源点：旧快照被释放、对齐被清空
        tool.setPickingSource(true);
        _tap(tool, state, const Offset(56, 8));

        await applied.timeout(const Duration(seconds: 10));
        return layer!.baseImageBytes!;
      });
      await tester.pump();

      expect(tool.sourcePoint, const Offset(56, 8));
      _expectRed(img.decodePng(bytes!)!.getPixel(48, 32));
    });

    testWidgets('应用等待期间切换工具，本次合成仍完成', (tester) async {
      final state = _editorState();
      final tool = CloneStampTool()..setSize(8);

      final bytes = await tester.runAsync(() async {
        final layer = await state.layerManager.addLayerFromImage(_splitPng());
        _tap(tool, state, const Offset(16, 32));
        final applied = _nextHistoryChange(state);
        _stroke(tool, state, const [Offset(48, 32)]);

        tool.onDeactivateFast(state);

        await applied.timeout(const Duration(seconds: 10));
        return layer!.baseImageBytes!;
      });
      await tester.pump();

      expect(tool.canvasSnapshot, isNull);
      _expectRed(img.decodePng(bytes!)!.getPixel(48, 32));
    });
  });
}

EditorState _editorState() {
  final state = EditorState()..setCanvasSize(const Size(64, 64));
  addTearDown(state.dispose);
  return state;
}

void _press(CloneStampTool tool, EditorState state, Offset position) =>
    tool.onPointerDown(PointerDownEvent(position: position), state);

void _drag(CloneStampTool tool, EditorState state, Offset position) =>
    tool.onPointerMove(PointerMoveEvent(position: position), state);

void _release(CloneStampTool tool, EditorState state, Offset position) =>
    tool.onPointerUp(PointerUpEvent(position: position), state);

void _tap(CloneStampTool tool, EditorState state, Offset position) {
  _press(tool, state, position);
  _release(tool, state, position);
}

void _stroke(CloneStampTool tool, EditorState state, List<Offset> points) {
  _press(tool, state, points.first);
  for (final point in points.skip(1)) {
    _drag(tool, state, point);
  }
  _release(tool, state, points.last);
}

Future<void> _nextHistoryChange(EditorState state) {
  final completer = Completer<void>();
  void listener() {
    state.historyManager.removeListener(listener);
    completer.complete();
  }

  state.historyManager.addListener(listener);
  return completer.future;
}

// 左半红、右半蓝，源点与落笔处颜色可区分
Uint8List _splitPng() {
  final image = img.Image(width: 64, height: 64, numChannels: 4);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      if (x < 32) {
        image.setPixelRgba(x, y, 255, 0, 0, 255);
      } else {
        image.setPixelRgba(x, y, 0, 0, 255, 255);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void _expectRed(img.Pixel pixel, {String? reason}) {
  expect(
    (pixel.r, pixel.g, pixel.b, pixel.a),
    (255, 0, 0, 255),
    reason: reason,
  );
}

void _expectBlue(img.Pixel pixel, {String? reason}) {
  expect(
    (pixel.r, pixel.g, pixel.b, pixel.a),
    (0, 0, 255, 255),
    reason: reason,
  );
}
