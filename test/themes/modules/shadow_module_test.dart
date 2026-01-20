/// Shadow Module Tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

void main() {
  group('Shadow Modules', () {
    final modules = [
      const NoneShadow(),
      const SoftShadow(),
      const HardOffsetShadow(),
      const GlowShadow(),
    ];

    for (final module in modules) {
      group('${module.runtimeType}', () {
        test('should have valid elevation1', () {
          expect(module.elevation1, isA<List<BoxShadow>>());
        });

        test('should have valid elevation2', () {
          expect(module.elevation2, isA<List<BoxShadow>>());
        });

        test('should have valid elevation3', () {
          expect(module.elevation3, isA<List<BoxShadow>>());
        });

        test('should have valid cardShadow', () {
          expect(module.cardShadow, isA<List<BoxShadow>>());
        });
      });
    }
  });

  group('NoneShadow', () {
    test('should have empty shadow lists', () {
      const shadow = NoneShadow();
      expect(shadow.elevation1, isEmpty);
      expect(shadow.elevation2, isEmpty);
      expect(shadow.elevation3, isEmpty);
      expect(shadow.cardShadow, isEmpty);
    });
  });

  group('HardOffsetShadow', () {
    test('should have zero blur radius', () {
      const shadow = HardOffsetShadow();
      for (final boxShadow in shadow.elevation2) {
        expect(boxShadow.blurRadius, 0);
      }
    });

    test('should have offset', () {
      const shadow = HardOffsetShadow();
      for (final boxShadow in shadow.elevation2) {
        expect(boxShadow.offset, isNot(Offset.zero));
      }
    });
  });

  group('GlowShadow', () {
    test('should have blur radius for glow effect', () {
      const shadow = GlowShadow();
      for (final boxShadow in shadow.elevation2) {
        expect(boxShadow.blurRadius, greaterThan(0));
      }
    });
  });

  group('SoftShadow', () {
    test('elevation should increase blur radius', () {
      const shadow = SoftShadow();
      final e1Blur = shadow.elevation1.isNotEmpty 
          ? shadow.elevation1.first.blurRadius 
          : 0.0;
      final e3Blur = shadow.elevation3.isNotEmpty 
          ? shadow.elevation3.first.blurRadius 
          : 0.0;
      expect(e3Blur, greaterThan(e1Blur));
    });
  });
}
