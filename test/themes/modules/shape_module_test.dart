/// Shape Module Tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

void main() {
  group('Shape Modules', () {
    final modules = [
      const StandardShapes(),
      const PillShapes(),
      const SharpShapes(),
      const FluidShapes(),
      const WobblyShapes(),
    ];

    for (final module in modules) {
      group('${module.runtimeType}', () {
        test('should have non-negative radius values', () {
          expect(module.smallRadius, greaterThanOrEqualTo(0));
          expect(module.mediumRadius, greaterThanOrEqualTo(0));
          expect(module.largeRadius, greaterThanOrEqualTo(0));
        });

        test('radius should increase: small < medium < large', () {
          expect(module.smallRadius, lessThanOrEqualTo(module.mediumRadius));
          expect(module.mediumRadius, lessThanOrEqualTo(module.largeRadius));
        });

        test('should have valid card shape', () {
          expect(module.cardShape, isA<ShapeBorder>());
        });

        test('should have valid button shape', () {
          expect(module.buttonShape, isA<ShapeBorder>());
        });

        test('should have valid input shape', () {
          expect(module.inputShape, isA<ShapeBorder>());
        });
      });
    }
  });

  group('Specific shape characteristics', () {
    test('PillShapes should use StadiumBorder for buttons', () {
      const shapes = PillShapes();
      expect(shapes.buttonShape, isA<StadiumBorder>());
    });

    test('SharpShapes should have small radius values', () {
      const shapes = SharpShapes();
      expect(shapes.largeRadius, lessThanOrEqualTo(12));
    });

    test('FluidShapes should have large radius values', () {
      const shapes = FluidShapes();
      expect(shapes.largeRadius, greaterThanOrEqualTo(50));
    });
  });
}
