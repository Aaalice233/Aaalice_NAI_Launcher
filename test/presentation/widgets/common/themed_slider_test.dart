import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';

void main() {
  testWidgets('hides tick marks without removing discrete divisions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemedSlider(
            value: 20,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    final slider = tester.widget<Slider>(find.byType(Slider));

    expect(sliderTheme.data.tickMarkShape, SliderTickMarkShape.noTickMark);
    expect(slider.divisions, 49);
  });
}
