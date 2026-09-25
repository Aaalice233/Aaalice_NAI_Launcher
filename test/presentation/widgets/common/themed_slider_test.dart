import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';

void main() {
  testWidgets('hides tick marks without removing discrete divisions', (
    tester,
  ) async {
    await _pumpSlider(
      tester,
      ThemedSlider(
        label: 'Steps',
        valueText: _wholeNumber,
        value: 20,
        min: 1,
        max: 50,
        divisions: 49,
        onChanged: (_) {},
      ),
    );

    final slider = find.byType(Slider);
    expect(
      SliderTheme.of(tester.element(slider)).tickMarkShape,
      SliderTickMarkShape.noTickMark,
    );
    expect(tester.widget<Slider>(slider).divisions, 49);
  });

  testWidgets('speaks the name on its own node with the displayed value', (
    tester,
  ) async {
    await _pumpSlider(
      tester,
      NamedSlider(
        label: 'Steps',
        valueText: _wholeNumber,
        value: 20,
        min: 1,
        max: 50,
        divisions: 49,
        onChanged: (_) {},
      ),
    );

    final node = _sliderNode('Steps');
    expect(node.value, '20');
    expect(node.increasedValue, '21');
    expect(node.decreasedValue, '19');
    expect(node.isMergedIntoParent, isFalse);
  });

  testWidgets('never draws the name as a value bubble', (tester) async {
    await _pumpSlider(
      tester,
      SliderTheme(
        data: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.alwaysVisible,
        ),
        child: NamedSlider(
          label: 'Defry',
          valueText: _wholeNumber,
          value: 2,
          max: 5,
          divisions: 5,
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      SliderTheme.of(tester.element(find.byType(Slider))).showValueIndicator,
      ShowValueIndicator.never,
    );
  });

  testWidgets('keeps the surrounding slider theme for its look', (
    tester,
  ) async {
    await _pumpSlider(
      tester,
      SliderTheme(
        data: const SliderThemeData(
          trackHeight: 2,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: NamedSlider(
          label: 'Size',
          valueText: _wholeNumber,
          value: 20,
          min: 1,
          max: 500,
          onChanged: (_) {},
        ),
      ),
    );

    final slider = find.byType(Slider);
    expect(SliderTheme.of(tester.element(slider)).trackHeight, 2);
    expect(tester.getSize(slider).height, 24);
  });

  testWidgets('semantic increase moves exactly one division', (tester) async {
    final changes = <double>[];
    await _pumpSlider(
      tester,
      NamedSlider(
        label: 'Tolerance',
        valueText: _wholeNumber,
        value: 32,
        max: 255,
        divisions: 255,
        onChanged: changes.add,
      ),
    );

    tester.semantics.increase(
      find.semantics.byPredicate(
        (node) => node.flagsCollection.isSlider && node.label == 'Tolerance',
      ),
    );

    expect(changes.single, moreOrLessEquals(33));
  });

  testWidgets('clamps out-of-range values for display and speech', (
    tester,
  ) async {
    await _pumpSlider(
      tester,
      NamedSlider(
        label: 'Size',
        valueText: _wholeNumber,
        value: 900,
        min: 1,
        max: 500,
        onChanged: (_) {},
      ),
    );

    expect(tester.widget<Slider>(find.byType(Slider)).value, 500);
    expect(_sliderNode('Size').value, '500');
  });

  testWidgets('forwards padding to the slider', (tester) async {
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    await _pumpSlider(
      tester,
      NamedSlider(
        label: 'Strength',
        valueText: (value) => value.toStringAsFixed(2),
        value: 0.5,
        padding: padding,
        onChanged: (_) {},
      ),
    );

    expect(tester.widget<Slider>(find.byType(Slider)).padding, padding);
  });

  testWidgets('disabled ThemedSlider drops every callback', (tester) async {
    await _pumpSlider(
      tester,
      ThemedSlider(
        label: 'Strength',
        valueText: (value) => value.toStringAsFixed(2),
        value: 0.5,
        enabled: false,
        onChanged: (_) {},
        onChangeStart: (_) {},
        onChangeEnd: (_) {},
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
    expect(slider.onChangeStart, isNull);
    expect(slider.onChangeEnd, isNull);
    expect(_sliderNode('Strength').value, '0.50');
  });
}

String _wholeNumber(double value) => '${value.round()}';

Future<void> _pumpSlider(WidgetTester tester, Widget slider) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(children: [SizedBox(width: 300, child: slider)]),
      ),
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
