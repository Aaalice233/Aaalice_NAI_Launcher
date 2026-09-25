import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/dlss/dlss_parameter_slider.dart';

void main() {
  testWidgets('滑块以参数名朗读，读数与数值框一致', (tester) async {
    await _pumpSlider(
      tester,
      DlssParameterSlider(
        label: 'NR 强度',
        description: '说明',
        value: 0.5,
        onChanged: (_) {},
      ),
    );

    final node = _sliderNode('NR 强度');
    expect(node.value, '0.5');
    expect(node.increasedValue, '0.55');
    expect(_fieldText(tester, 'NR 强度'), '0.5');
    expect(
      SliderTheme.of(tester.element(find.byType(Slider))).showValueIndicator,
      ShowValueIndicator.never,
      reason: '参数名只作读屏名称，不画成数值气泡',
    );
  });

  testWidgets('滑块插值的二进制尾差不进入数值框与读屏', (tester) async {
    await _pumpSlider(
      tester,
      DlssParameterSlider(
        label: '皮肤结构强度',
        description: '说明',
        value: -0.45000000000000007,
        minimum: -1,
        onChanged: (_) {},
      ),
    );

    expect(_fieldText(tester, '皮肤结构强度'), '-0.45');
    expect(_sliderNode('皮肤结构强度').value, '-0.45');
  });

  testWidgets('特殊取值的说明按相邻读数分别给出', (tester) async {
    await _pumpSlider(
      tester,
      DlssParameterSlider(
        label: '皮肤结构强度',
        description: '说明',
        value: 0,
        minimum: -1,
        valueLabel: (skin) => skin < 0 ? '模型默认' : null,
        onChanged: (_) {},
      ),
    );

    final node = _sliderNode('皮肤结构强度');
    expect(node.value, '0.0');
    expect(node.decreasedValue, '模型默认');
    expect(node.increasedValue, '0.05');
    expect(find.text('模型默认'), findsNothing, reason: '当前值不是特殊取值');
  });
}

Future<void> _pumpSlider(WidgetTester tester, Widget slider) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: slider)),
    ),
  );
}

SemanticsNode _sliderNode(String label) {
  final slider = find.semantics.byPredicate(
    (node) => node.flagsCollection.isSlider && node.label == label,
  );
  expect(slider, findsOne, reason: label);
  return slider.evaluate().single;
}

String _fieldText(WidgetTester tester, String label) => tester
    .widget<TextField>(find.byKey(ValueKey('dlss-value-$label')))
    .controller!
    .text;
