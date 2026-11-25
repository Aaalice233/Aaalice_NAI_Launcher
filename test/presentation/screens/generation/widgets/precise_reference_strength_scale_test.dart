import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/precise_reference/precise_reference_strength_scale.dart';

void main() {
  test('V5 places strength 1 in the middle and clamps only the slider', () {
    expect(preciseReferenceStrengthPosition(-2, 5), 0);
    expect(preciseReferenceStrengthPosition(0.5, 5), 0.25);
    expect(preciseReferenceStrengthPosition(1, 5), 0.5);
    expect(preciseReferenceStrengthPosition(3, 5), 0.75);
    expect(preciseReferenceStrengthPosition(5, 5), 1);
    expect(preciseReferenceStrengthPosition(7, 5), 1);
    for (var step = 0; step <= 100; step++) {
      final strength = step / 20;
      expect(
        preciseReferenceStrengthAtPosition(
          preciseReferenceStrengthPosition(strength, 5),
          5,
        ),
        strength,
      );
    }
    expect(preciseReferenceStrengthAtPosition(0.512, 5), 1.1);
    expect(preciseReferenceStrengthAtPosition(0.487, 5), 0.95);
  });

  test('V4.5 keeps a linear slider with twentieths', () {
    expect(preciseReferenceStrengthPosition(0.5, 1), 0.5);
    expect(preciseReferenceStrengthAtPosition(0.53, 1), 0.55);
  });
}
