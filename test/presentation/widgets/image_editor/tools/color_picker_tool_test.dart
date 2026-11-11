import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/color_picker_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('关闭编辑器取消悬停取色的防抖定时器', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(() {
      if (!state.isDisposed) state.dispose();
    });
    final tool =
        state.toolManager.getToolById('color_picker')! as ColorPickerTool;
    state.setTool(tool);
    tool.onPointerHover(
      const PointerHoverEvent(position: Offset(10, 10)),
      state,
    );
    expect(tool.previewPosition, const Offset(10, 10));

    state.dispose();

    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭编辑器后不再处理在途的点击取色', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(() {
      if (!state.isDisposed) state.dispose();
    });
    final tool =
        state.toolManager.getToolById('color_picker')! as ColorPickerTool;
    state.setTool(tool);
    tool.onPointerUp(const PointerUpEvent(position: Offset(-1, -1)), state);
    state.dispose();
    await tester.pump();

    expect(state.currentTool, same(tool));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击采到颜色前关闭编辑器不回写前景色或切换工具', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(() {
      if (!state.isDisposed) state.dispose();
    });
    final tool =
        state.toolManager.getToolById('color_picker')! as ColorPickerTool;
    state.setTool(tool);
    final originalColor = state.foregroundColor;
    expect(originalColor, isNot(Colors.white));

    late List<List<Color>>? pixelsAtClose;
    await _waitForSamplingReadbacks(tester, () {
      tool.onPointerUp(const PointerUpEvent(position: Offset(10, 10)), state);
      state.dispose();
      pixelsAtClose = tool.magnifierPixels;
    });

    expect(tool.magnifierPixels, same(pixelsAtClose));
    expect(state.foregroundColor, originalColor);
    expect(state.currentTool, same(tool));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击取色回读期间切到橡皮擦后保留前景色和橡皮擦', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    state.setToolById('color_picker');
    final tool = state.currentTool! as ColorPickerTool;
    final originalColor = state.foregroundColor;
    expect(originalColor, isNot(Colors.white));

    await _waitForSamplingReadbacks(tester, () {
      tool.onPointerUp(const PointerUpEvent(position: Offset(10, 10)), state);
      state.setToolById('eraser');
    });

    expect(state.foregroundColor, originalColor);
    expect(state.currentTool?.id, 'eraser');
    expect(tool.magnifierPixels, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('橡皮擦退出临时取色后丢弃在途的点击结果', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    state.setToolById('eraser');
    state.enterTemporaryColorPicker();
    final tool = state.currentTool! as ColorPickerTool;
    final originalColor = state.foregroundColor;

    await _waitForSamplingReadbacks(tester, () {
      tool.onPointerUp(const PointerUpEvent(position: Offset(10, 10)), state);
      state.exitTemporaryColorPicker();
    });

    expect(state.foregroundColor, originalColor);
    expect(state.currentTool?.id, 'eraser');
    expect(tool.magnifierPixels, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('当前取色请求更新前景色并切回上一个工具', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(state.dispose);
    final previousTool = state.currentTool;
    state.setToolById('color_picker');
    final tool = state.currentTool! as ColorPickerTool;
    tool.setSampleMode(ColorPickerSampleMode.area);
    expect(state.foregroundColor, isNot(Colors.white));

    await _waitForSamplingReadbacks(tester, () {
      tool.onPointerUp(const PointerUpEvent(position: Offset(10, 10)), state);
    });

    expect(state.foregroundColor, Colors.white);
    expect(state.currentTool, same(previousTool));
    expect(tester.takeException(), isNull);
  });

  testWidgets('悬停防抖已启动采样后关闭编辑器不更新预览', (tester) async {
    final state = EditorState()..setCanvasSize(const Size(64, 64));
    addTearDown(() {
      if (!state.isDisposed) state.dispose();
    });
    final tool =
        state.toolManager.getToolById('color_picker')! as ColorPickerTool;
    state.setTool(tool);

    late List<List<Color>>? pixelsAtClose;
    await _waitForSamplingReadbacks(tester, () {
      late Timer debounceTimer;
      late void Function() expireDebounce;
      runZoned(
        () => tool.onPointerHover(
          const PointerHoverEvent(position: Offset(10, 10)),
          state,
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            expect(duration, const Duration(milliseconds: 8));
            expireDebounce = callback;
            return debounceTimer = parent.createTimer(zone, duration, callback);
          },
        ),
      );
      expect(tool.previewColor, isNull);
      expect(tool.magnifierPixels, isNull);
      // 同步触发到期回调，保证采样启动后、像素返回前关闭。
      debounceTimer.cancel();
      expireDebounce();
      state.dispose();
      pixelsAtClose = tool.magnifierPixels;
    }, imageCount: 2);

    expect(tool.magnifierPixels, same(pixelsAtClose));
    expect(tool.previewColor, isNull);
    expect(tool.previewPosition, const Offset(10, 10));
    expect(tester.takeException(), isNull);
  });

  for (final (description, switchTools, updated) in [
    ('失败的预热可以重试', false, false),
    ('切走再切回取色器后可以重试上一次预热', true, true),
  ]) {
    testWidgets(description, (tester) async {
      final state = _SnapshotEditorState();
      addTearDown(state.dispose);
      state.setToolById('color_picker');
      final tool = state.currentTool! as ColorPickerTool;
      tool.onActivateDeferred(state);

      if (switchTools) {
        state.setToolById('eraser');
        state.setTool(tool);
      }
      state.snapshotUpdates.single.complete(updated);
      await tester.idle();

      tool.onActivateDeferred(state);
      expect(state.snapshotUpdates, hasLength(2));
      state.snapshotUpdates.last.complete(true);
      await tester.idle();

      tool.onActivateDeferred(state);
      expect(state.snapshotUpdates, hasLength(2));
    });
  }

  for (final viewSize in editorPanelViewSizes) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$viewSize ${scale}x 文字下取色设置的标签与分段选项完整可选', (tester) async {
        await pumpEditorWorkspace(
          tester,
          viewSize: viewSize,
          textScale: scale,
          toolId: 'color_picker',
        );
        await _expectColorPickerSettingsUsable(
          tester,
          locale: 'en',
          scenario: '$viewSize x$scale',
        );
      });
    }
  }

  for (final locale in const ['zh', 'ja']) {
    testWidgets('$locale 1x 侧栏里每组分段选项并排可见', (tester) async {
      await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1180, 760),
        locale: locale,
        toolId: 'color_picker',
      );
      final l10n = lookupAppLocalizations(Locale(locale));
      final panelRight = tester.getRect(find.byType(ToolSettingRows)).right;
      for (final label in [
        l10n.editor_samplePoint,
        l10n.editor_sampleArea,
        l10n.editor_sourceCurrentLayer,
        l10n.editor_sourceAllLayers,
      ]) {
        expect(
          tester.getRect(find.text(label)).right,
          lessThanOrEqualTo(panelRight),
          reason: '$label $locale',
        );
      }
    });
  }

  testWidgets('中文 1x 侧栏中分段选项不被挤断', (tester) async {
    await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1180, 760),
      locale: 'zh',
      toolId: 'color_picker',
    );
    await _expectColorPickerSettingsUsable(
      tester,
      locale: 'zh',
      scenario: 'zh 1180 x1',
    );
  });
}

class _SnapshotEditorState extends EditorState {
  final snapshotUpdates = <Completer<bool>>[];

  @override
  bool get hasValidCanvasSnapshot => true;

  @override
  Future<bool> updateCanvasSnapshot() {
    final update = Completer<bool>();
    snapshotUpdates.add(update);
    return update.future;
  }
}

Future<void> _waitForSamplingReadbacks(
  WidgetTester tester,
  VoidCallback startSampling, {
  int imageCount = 1,
}) async {
  await tester.runAsync(() async {
    final completed = Completer<void>();
    final previousDispose = ui.Image.onDispose;
    var remaining = imageCount;
    ui.Image.onDispose = (image) {
      previousDispose?.call(image);
      if (--remaining == 0) completed.complete();
    };
    try {
      startSampling();
      await completed.future.timeout(const Duration(seconds: 5));
      // 回读图像释放后，让采样和写回的 Future 续体全部完成。
      await Future<void>(() {});
    } finally {
      ui.Image.onDispose = previousDispose;
    }
  });
}

Future<void> _expectColorPickerSettingsUsable(
  WidgetTester tester, {
  required String locale,
  required String scenario,
}) async {
  final l10n = lookupAppLocalizations(Locale(locale));
  final rows = find.byType(ToolSettingRows);
  expect(tester.takeException(), isNull, reason: scenario);
  for (final label in [l10n.editor_sample, l10n.editor_source]) {
    expectSingleLineUntruncated(
      tester,
      find.descendant(of: rows, matching: find.text(label)),
      reason: '$label $scenario',
    );
  }

  Future<void> tapSegment(String label) async {
    final segment = find.descendant(of: rows, matching: find.text(label));
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    expectSingleLineUntruncated(tester, segment, reason: '$label $scenario');
    expect(segment.hitTestable(), findsOneWidget, reason: '$label $scenario');
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  for (final (label, mode) in [
    (l10n.editor_sampleArea, ColorPickerSampleMode.area),
    (l10n.editor_samplePoint, ColorPickerSampleMode.point),
  ]) {
    await tapSegment(label);
    expect(
      tester
          .widget<SegmentedButton<ColorPickerSampleMode>>(
            find.byType(SegmentedButton<ColorPickerSampleMode>),
          )
          .selected,
      {mode},
      reason: '$label $scenario',
    );
  }
  for (final (label, source) in [
    (l10n.editor_sourceAllLayers, ColorPickerSource.allLayers),
    (l10n.editor_sourceCurrentLayer, ColorPickerSource.currentLayer),
  ]) {
    await tapSegment(label);
    expect(
      tester
          .widget<SegmentedButton<ColorPickerSource>>(
            find.byType(SegmentedButton<ColorPickerSource>),
          )
          .selected,
      {source},
      reason: '$label $scenario',
    );
  }
  expect(tester.takeException(), isNull, reason: scenario);
}
