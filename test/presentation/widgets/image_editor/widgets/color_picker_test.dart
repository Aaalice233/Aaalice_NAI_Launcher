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
}
