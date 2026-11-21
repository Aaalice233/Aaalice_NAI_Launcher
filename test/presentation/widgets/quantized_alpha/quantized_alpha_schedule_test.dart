import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/quantized_alpha/quantized_alpha_schedule.dart';

void main() {
  const step = 1 / QuantizedAlphaSchedule.alphaLevels;
  const cycle = Duration(milliseconds: 4000);

  QuantizedAlphaSchedule glowSchedule() => QuantizedAlphaSchedule(
    begin: 0.04,
    end: 0.1,
    halfPeriod: const Duration(milliseconds: 2000),
    initialProgress: 1 / 3,
  );

  testWidgets('tracks the repeating animation it replaces within half a step', (
    tester,
  ) async {
    final schedule = glowSchedule();
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 2000),
      value: 1 / 3,
    );
    addTearDown(controller.dispose);
    final reference = Tween<double>(
      begin: 0.04,
      end: 0.1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    controller.repeat(reverse: true);
    await tester.pump();
    var worst = 0.0;
    for (var ms = 0; ms <= cycle.inMilliseconds; ms++) {
      if (ms > 0) await tester.pump(const Duration(milliseconds: 1));
      final quantized = schedule.alphaAt(Duration(milliseconds: ms));
      final level = quantized * QuantizedAlphaSchedule.alphaLevels;
      expect(level, closeTo(level.roundToDouble(), 1e-9));
      final error = (quantized - reference.value).abs();
      if (error > worst) worst = error;
    }
    expect(worst, lessThanOrEqualTo(step / 2 + 1e-9));
    controller.stop();
  });

  test('wakes exactly when the quantized alpha changes', () {
    final schedule = glowSchedule();
    for (var us = 0; us < cycle.inMicroseconds * 2; us += 997) {
      final now = Duration(microseconds: us);
      final next = schedule.nextChangeAfter(now)!;
      final alpha = schedule.alphaAt(now);

      expect(next, greaterThan(now));
      expect(schedule.alphaAt(next), isNot(alpha));
      expect(schedule.alphaAt(next - const Duration(microseconds: 2)), alpha);
    }
  });

  test('a full cycle steps once per 8-bit level crossed each way', () {
    final schedule = glowSchedule();
    // 0.04×255=10.2 到 0.1×255=25.5 之间的半台阶 10.5…24.5；25.5 在端点只被触到。
    const crossedLevels = 15;

    for (final start in [Duration.zero, const Duration(milliseconds: 1234)]) {
      var changes = 0;
      var now = start;
      var alpha = schedule.alphaAt(now);
      while (true) {
        now = schedule.nextChangeAfter(now)!;
        if (now > start + cycle) break;
        final next = schedule.alphaAt(now);
        expect((next - alpha).abs(), closeTo(step, 1e-9));
        alpha = next;
        changes++;
      }
      expect(changes, crossedLevels * 2);
    }
  });

  test('a falling range steps the same way in reverse', () {
    final schedule = QuantizedAlphaSchedule(
      begin: 0.6,
      end: 0.2,
      halfPeriod: const Duration(milliseconds: 500),
    );
    var now = Duration.zero;
    var alpha = schedule.alphaAt(now);
    expect(alpha, closeTo(0.6, step / 2));
    for (var i = 0; i < 400; i++) {
      final next = schedule.nextChangeAfter(now)!;
      final nextAlpha = schedule.alphaAt(next);
      expect((nextAlpha - alpha).abs(), closeTo(step, 1e-9));
      now = next;
      alpha = nextAlpha;
    }
  });

  test('a constant level never asks to wake', () {
    final schedule = QuantizedAlphaSchedule(
      begin: 0.3,
      end: 0.3,
      halfPeriod: const Duration(milliseconds: 800),
    );
    expect(schedule.nextChangeAfter(Duration.zero), isNull);
    expect(
      schedule.alphaAt(const Duration(milliseconds: 1234)),
      schedule.alphaAt(Duration.zero),
    );
  });
}
