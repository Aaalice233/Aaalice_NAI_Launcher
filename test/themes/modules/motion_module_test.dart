/// Motion Module Tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/motion_module.dart';

void main() {
  group('Motion Modules', () {
    final modules = [
      const ZenMotion(),
      const MaterialMotion(),
      const JitterMotion(),
      const SnappyMotion(),
    ];

    for (final module in modules) {
      group('${module.runtimeType}', () {
        test('should have positive durations', () {
          expect(module.fastDuration.inMilliseconds, greaterThan(0));
          expect(module.normalDuration.inMilliseconds, greaterThan(0));
          expect(module.slowDuration.inMilliseconds, greaterThan(0));
        });

        test('duration order: fast < normal < slow', () {
          expect(
            module.fastDuration.inMilliseconds,
            lessThan(module.normalDuration.inMilliseconds),
          );
          expect(
            module.normalDuration.inMilliseconds,
            lessThan(module.slowDuration.inMilliseconds),
          );
        });

        test('should have valid curves', () {
          expect(module.enterCurve, isA<Curve>());
          expect(module.exitCurve, isA<Curve>());
          expect(module.standardCurve, isA<Curve>());
        });
      });
    }
  });

  group('Specific motion characteristics', () {
    test('ZenMotion should have longer durations', () {
      const motion = ZenMotion();
      expect(motion.normalDuration.inMilliseconds, greaterThanOrEqualTo(300));
    });

    test('SnappyMotion should have short durations', () {
      const motion = SnappyMotion();
      expect(motion.normalDuration.inMilliseconds, lessThanOrEqualTo(200));
    });

    test('JitterMotion should use elastic curve', () {
      const motion = JitterMotion();
      expect(motion.enterCurve, Curves.elasticOut);
    });

    test('MaterialMotion should use MD3 curves', () {
      const motion = MaterialMotion();
      expect(motion.standardCurve, isA<Cubic>());
    });
  });
}
