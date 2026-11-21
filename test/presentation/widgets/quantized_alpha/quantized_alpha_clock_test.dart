import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/quantized_alpha/quantized_alpha_pulse.dart';
import 'package:nai_launcher/presentation/widgets/quantized_alpha/quantized_alpha_schedule.dart';

void main() {
  testWidgets('late frames reschedule against the absolute phase', (
    tester,
  ) async {
    final schedule = _glowSchedule();
    final clock = QuantizedAlphaClock(schedule: schedule);
    final pulse = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      pulse.repeat();
      await tester.pump();
      var elapsed = Duration.zero;
      for (final delay in [470, 711, 1234, 519]) {
        elapsed += Duration(milliseconds: delay);
        await tester.pump(Duration(milliseconds: delay));
        final alpha = schedule.alphaAt(elapsed);
        expect(pulse.value, alpha);
        expect(tester.binding.hasScheduledFrame, isFalse);

        final next = schedule.nextChangeAfter(elapsed)!;
        await tester.pump(next - elapsed - const Duration(microseconds: 1));
        expect(pulse.value, alpha);
        await tester.pump(const Duration(microseconds: 1));
        expect(pulse.value, schedule.alphaAt(next));
        expect(pulse.value, isNot(alpha));
        expect(tester.binding.hasScheduledFrame, isFalse);
        elapsed = next;
      }
    } finally {
      pulse.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('multiple ticker callbacks sample the schedule once per frame', (
    tester,
  ) async {
    var samples = 0;
    final curve = _CountingCurve(() => samples++);
    final clock = QuantizedAlphaClock(schedule: _glowSchedule(curve: curve));
    final first = QuantizedAlphaPulse(vsync: tester, clock: clock);
    final second = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      first.repeat();
      second.repeat();
      samples = 0;
      await tester.pump();
      expect(samples, 1);

      samples = 0;
      await tester.pump(const Duration(milliseconds: 700));
      expect(samples, 1);
      expect(first.value, second.value);
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      first.dispose();
      second.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('a constant schedule leaves no timer after sampling', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(
      schedule: QuantizedAlphaSchedule(
        begin: 0.3,
        end: 0.3,
        halfPeriod: const Duration(milliseconds: 2000),
      ),
    );
    final pulse = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      pulse.repeat();
      await tester.pump();
      expect(clock.hasPendingWake, isFalse);
      await tester.pump(const Duration(milliseconds: 4000));
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      pulse.dispose();
    }
  });
}

QuantizedAlphaSchedule _glowSchedule({Curve curve = Curves.easeInOut}) =>
    QuantizedAlphaSchedule(
      begin: 0.04,
      end: 0.1,
      halfPeriod: const Duration(milliseconds: 2000),
      initialProgress: 1 / 3,
      curve: curve,
    );

class _CountingCurve extends Curve {
  const _CountingCurve(this.onSample);

  final void Function() onSample;

  @override
  double transformInternal(double t) {
    onSample();
    return Curves.easeInOut.transform(t);
  }
}
