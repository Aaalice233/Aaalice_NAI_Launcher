import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../../../../helpers/text_layout_expectations.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  testWidgets('拖动画笔大小滑块时滑块值应实时更新', (tester) async {
    final tool = BrushTool();
    final state = EditorState();

    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => Material(
              child: tool.buildSettingsPanel(context, state),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sliderFinder = find.byType(Slider).first;
    final before = tester.widget<Slider>(sliderFinder);
    expect(before.value, equals(20));

    await tester.drag(sliderFinder, const Offset(160, 0));
    await tester.pump();

    final after = tester.widget<Slider>(sliderFinder);
    expect(after.value, greaterThan(20));
  });

  for (final viewSize in editorPanelViewSizes) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$viewSize ${scale}x 文字下笔刷预设完整可点且不溢出', (tester) async {
        await pumpEditorWorkspace(tester, viewSize: viewSize, textScale: scale);
        final scenario = '$viewSize x$scale';
        expect(tester.takeException(), isNull, reason: scenario);

        final tileHeights = <double>{};
        for (final (index, preset) in defaultBrushPresets.indexed) {
          final reason = '${preset.name} $scenario';
          final tile = find.byKey(ValueKey('brush-preset-$index'));
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          expect(tile.hitTestable(), findsOneWidget, reason: reason);

          final tileRect = tester.getRect(tile);
          tileHeights.add(tileRect.height);
          expect(tileRect.width, greaterThanOrEqualTo(56), reason: reason);
          expect(
            tileRect.height,
            scale == 1 ? 70 : greaterThan(70),
            reason: '1x 保持原高度，放大后随文字长高 $reason',
          );
          final stripRect = tester.getRect(
            find.ancestor(
              of: tile,
              matching: find.byType(HorizontalActionStrip),
            ),
          );
          expect(tileRect.top, greaterThanOrEqualTo(stripRect.top));
          expect(tileRect.bottom, lessThanOrEqualTo(stripRect.bottom));

          expect(
            find.descendant(of: tile, matching: find.text(preset.name)),
            findsWidgets,
            reason: reason,
          );
          final labels = find.descendant(of: tile, matching: find.byType(Text));
          for (var i = 0; i < labels.evaluate().length; i++) {
            expectSingleLineUntruncated(tester, labels.at(i), reason: reason);
            expect(
              tileRect.expandToInclude(tester.getRect(labels.at(i))),
              tileRect,
              reason: reason,
            );
          }

          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(
            _sizeFieldText(tester),
            '${preset.size.round()}',
            reason: reason,
          );
        }
        expect(tileHeights, hasLength(1), reason: '预设同行等高 $scenario');

        for (final label in const ['Size', 'Opacity', 'Hardness']) {
          expectSingleLineUntruncated(
            tester,
            find.descendant(
              of: find.byType(ToolSettingRows),
              matching: find.text(label),
            ),
            reason: '$label $scenario',
          );
        }
        expect(tester.takeException(), isNull, reason: scenario);
      });
    }
  }

  testWidgets('预设磁贴的悬停与按压反馈画在磁贴底色之上', (tester) async {
    await _pumpBrushPanel(tester);
    final theme = Theme.of(tester.element(_presetTile(0)));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    for (final index in const [0, 2]) {
      await mouse.moveTo(tester.getCenter(_presetTile(index)));
      await tester.pumpAndSettle();
      _expectInkOnPresetTile(
        tester,
        index,
        selected: index == 2,
        ink: theme.hoverColor,
        reason: '悬停预设 $index',
      );
    }

    final press = await tester.startGesture(tester.getCenter(_presetTile(1)));
    await tester.pump(kPressTimeout);
    await tester.pump(const Duration(milliseconds: 200));
    _expectInkOnPresetTile(
      tester,
      1,
      selected: false,
      ink: theme.highlightColor,
      reason: '按下即显示按压高亮',
    );
    await press.up();
    await tester.pumpAndSettle();
    expect(_sizeFieldText(tester), '${defaultBrushPresets[1].size.round()}');
  });

  testWidgets(
    'Tab 聚焦的预设磁贴显示焦点高亮',
    (tester) async {
      await _pumpBrushPanel(tester);
      final theme = Theme.of(tester.element(_presetTile(0)));

      for (final index in const [0, 1, 2]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        _expectInkOnPresetTile(
          tester,
          index,
          selected: index == 2,
          ink: theme.focusColor,
          reason: 'Tab 聚焦预设 $index',
        );
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('预设磁贴语义带名称与选中态，读屏点击可切换预设', (tester) async {
    await _pumpBrushPanel(tester);
    final hint = AppLocalizations.of(
      tester.element(_presetTile(0)),
    )!.brushPreset_selectHint;

    for (final (index, preset) in defaultBrushPresets.indexed) {
      expect(
        tester.getSemantics(_presetTile(index)),
        isSemantics(
          label: preset.name,
          hint: hint,
          isButton: true,
          hasSelectedState: true,
          isSelected: index == 2,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: preset.name,
      );
    }

    tester.semantics.tap(find.semantics.byLabel(defaultBrushPresets[1].name));
    await tester.pumpAndSettle();
    expect(_sizeFieldText(tester), '${defaultBrushPresets[1].size.round()}');
    expect(tester.getSemantics(_presetTile(1)), isSemantics(isSelected: true));
    expect(tester.getSemantics(_presetTile(2)), isSemantics(isSelected: false));
  });

  testWidgets('笔刷面板滑块以行标签朗读并读出界面上的数值', (tester) async {
    final tool = await _pumpBrushPanel(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ToolSettingRows)),
    )!;
    final settings = tool.settings;

    for (final (label, value) in [
      (l10n.editor_size, '${settings.size.round()}'),
      (l10n.editor_opacity, '${(settings.opacity * 100).round()}%'),
      (l10n.editor_hardness, '${(settings.hardness * 100).round()}%'),
    ]) {
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.flagsCollection.isSlider &&
              node.label == label &&
              node.value == value,
        ),
        findsOne,
        reason: '$label $value',
      );
    }
  });
}

Future<BrushTool> _pumpBrushPanel(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.reset);
  final tool = BrushTool();
  final state = EditorState();
  addTearDown(state.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              Material(child: tool.buildSettingsPanel(context, state)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tool;
}

Finder _presetTile(int index) => find.byKey(ValueKey('brush-preset-$index'));

// 绘制顺序即叠放层级：磁贴底色 → 墨水 → 选中描边，墨水之后不能再有不透明填充
void _expectInkOnPresetTile(
  WidgetTester tester,
  int index, {
  required bool selected,
  required Color ink,
  required String reason,
}) {
  final tile = _presetTile(index);
  final colors = Theme.of(tester.element(tile)).colorScheme;
  // 按压水波同样调用 drawRect；墨水透明度经 8 位量化，按 ARGB32 比较
  bool isInk(Symbol method, List<dynamic> arguments) =>
      method == #drawRect &&
      (arguments[1] as Paint).color.toARGB32() == ink.toARGB32();

  expect(
    tester.renderObject(tile),
    paints
      ..path(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surfaceContainer,
      )
      ..something(isInk)
      ..everything(_isNotOpaqueFill),
    reason: reason,
  );
  if (selected) {
    expect(
      tester.renderObject(tile),
      paints
        ..something(isInk)
        ..drrect(color: colors.primary),
      reason: reason,
    );
  }
}

bool _isNotOpaqueFill(Symbol method, List<dynamic> arguments) {
  if (!const {#drawRect, #drawRRect, #drawPath, #drawPaint}.contains(method)) {
    return true;
  }
  final paint = arguments.last as Paint;
  return paint.style == PaintingStyle.stroke ||
      paint.shader != null ||
      paint.color.a < 1;
}

String _sizeFieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(ToolSettingRows),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;
