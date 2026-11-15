import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/quantized_alpha/quantized_alpha_pulse.dart';
import 'package:nai_launcher/presentation/widgets/quantized_alpha/quantized_alpha_schedule.dart';

void main() {
  final schedule = QuantizedAlphaSchedule(
    begin: 0.04,
    end: 0.1,
    halfPeriod: const Duration(milliseconds: 2000),
    initialProgress: 1 / 3,
  );
  const cycle = Duration(milliseconds: 4000);

  testWidgets('requests a frame only at each alpha step', (tester) async {
    final pulse = QuantizedAlphaPulse(vsync: tester, schedule: schedule);
    addTearDown(pulse.dispose);

    pulse.repeat();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    var notifications = 0;
    pulse.addListener(() => notifications++);
    for (var ms = 1; ms <= cycle.inMilliseconds; ms++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(pulse.value, schedule.alphaAt(Duration(milliseconds: ms)));
    }
    expect(notifications, 30);
    pulse.stop();
  });

  testWidgets('a muted ticker keeps the page from waking', (tester) async {
    final hostKey = GlobalKey<_PulseHostState>();
    Widget build({required bool enabled}) => TickerMode(
      enabled: enabled,
      child: _PulseHost(key: hostKey, schedule: schedule),
    );

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    final pulse = hostKey.currentState!.pulse;
    var notifications = 0;
    pulse.addListener(() => notifications++);

    await tester.pumpWidget(build(enabled: false));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    expect(notifications, 0);

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    expect(pulse.value, schedule.alphaAt(const Duration(milliseconds: 4000)));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reset returns to the starting alpha and stops waking', (
    tester,
  ) async {
    final pulse = QuantizedAlphaPulse(vsync: tester, schedule: schedule);
    addTearDown(pulse.dispose);

    pulse.repeat();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(pulse.value, isNot(schedule.alphaAt(Duration.zero)));

    pulse.reset();
    expect(pulse.isRunning, isFalse);
    expect(pulse.value, schedule.initialAlpha);
    var notifications = 0;
    pulse.addListener(() => notifications++);
    await tester.pump(cycle);
    expect(notifications, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('resuming continues from where it stopped', (tester) async {
    final pulse = QuantizedAlphaPulse(vsync: tester, schedule: schedule);
    addTearDown(pulse.dispose);

    pulse.repeat();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    pulse.stop();
    final stoppedAt = pulse.value;
    await tester.pump(const Duration(milliseconds: 1500));
    expect(pulse.value, stoppedAt);

    pulse.repeat();
    await tester.pump();
    expect(pulse.value, schedule.alphaAt(const Duration(milliseconds: 700)));
    pulse.stop();
  });

  testWidgets('disposing a running pulse leaves no wake pending', (
    tester,
  ) async {
    final pulse = QuantizedAlphaPulse(vsync: tester, schedule: schedule);
    pulse.repeat();
    await tester.pump();
    pulse.dispose();
    await tester.pump(cycle);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

class _PulseHost extends StatefulWidget {
  const _PulseHost({super.key, required this.schedule});

  final QuantizedAlphaSchedule schedule;

  @override
  State<_PulseHost> createState() => _PulseHostState();
}

class _PulseHostState extends State<_PulseHost>
    with SingleTickerProviderStateMixin {
  late final pulse = QuantizedAlphaPulse(vsync: this, schedule: widget.schedule)
    ..repeat();

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: pulse,
    builder: (context, alpha, _) =>
        ColoredBox(color: Colors.blue.withValues(alpha: alpha)),
  );
}
