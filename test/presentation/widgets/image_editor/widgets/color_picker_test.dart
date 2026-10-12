import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/color_picker.dart';

void main() {
  testWidgets('颜色选择器在 150 高度内压缩 SV 面板且不溢出', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 212,
              height: 150,
              child: HSVColorPicker(
                color: Colors.blue,
                hexLabel: '颜色值',
                saturationBrightnessLabel: '饱和度与亮度',
                hueLabel: '色相',
                onColorChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final svPanel = find.byKey(const ValueKey('hsv-color-picker-sv-panel'));
    final hueSlider = find.byKey(const ValueKey('hsv-color-picker-hue-slider'));

    expect(tester.getSize(svPanel).height, greaterThan(0));
    expect(tester.getSize(svPanel).height, lessThan(120));
    expect(tester.getSize(hueSlider).height, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('颜色选择器在无界高度下保留标准面板高度', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HSVColorPicker(
                color: Colors.blue,
                hexLabel: '颜色值',
                saturationBrightnessLabel: '饱和度与亮度',
                hueLabel: '色相',
                onColorChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('hsv-color-picker-sv-panel')))
          .height,
      120,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('色面与色相条以滑块朗读，色值框只有一个具名输入节点', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HSVColorPicker(
                color: Colors.blue,
                hexLabel: '颜色值',
                saturationBrightnessLabel: '饱和度与亮度',
                hueLabel: '色相',
                onColorChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    for (final label in const ['饱和度与亮度', '色相']) {
      expect(
        find.semantics.byPredicate(
          (node) => node.flagsCollection.isSlider && node.label == label,
        ),
        findsOne,
        reason: label,
      );
    }
    final fields = find.semantics.byPredicate(
      (node) => node.flagsCollection.isTextField,
    );
    expect(fields, findsOne);
    final hex = fields.evaluate().single;
    expect(hex.label, '颜色值');
    expect(hex.value, isNotEmpty);
  });

  testWidgets('点按 SV 面板与色相条即取色，不需要拖动', (tester) async {
    final changes = <Color>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              HSVColorPicker(
                color: Colors.blue,
                hexLabel: '颜色值',
                saturationBrightnessLabel: '饱和度与亮度',
                hueLabel: '色相',
                onColorChanged: changes.add,
              ),
            ],
          ),
        ),
      ),
    );

    final svPanel = find.byKey(const ValueKey('hsv-color-picker-sv-panel'));
    await tester.tapAt(tester.getTopLeft(svPanel) + const Offset(8, 8));
    await tester.pump();
    expect(changes, hasLength(1));

    final hueSlider = find.byKey(const ValueKey('hsv-color-picker-hue-slider'));
    await tester.tapAt(
      tester.getRect(hueSlider).centerLeft + const Offset(8, 0),
    );
    await tester.pump();
    expect(changes, hasLength(2));
  });
}
