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
    final clock = QuantizedAlphaClock(schedule: schedule);
    final pulse = QuantizedAlphaPulse(vsync: tester, clock: clock);

    try {
      pulse.repeat();
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
    } finally {
      pulse.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('a pulse joining after 700ms shares all 30 change times', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final first = QuantizedAlphaPulse(vsync: tester, clock: clock);
    final second = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      first.repeat();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      second.repeat();
      second.repeat();
      expect(second.value, first.value);
      expect(tester.binding.hasScheduledFrame, isFalse);

      var changes = 0;
      var alpha = first.value;
      for (var ms = 1; ms <= cycle.inMilliseconds; ms++) {
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(first.value, schedule.alphaAt(Duration(milliseconds: 700 + ms)));
        expect(second.value, first.value);
        if (first.value != alpha) changes++;
        alpha = first.value;
      }
      expect(changes, 30);
    } finally {
      first.dispose();
      second.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('a late host paints the published alpha on its first build', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    final firstBuilds = <double>[];
    Widget build({required bool showSecond}) => _hosts(
      clock: clock,
      firstKey: firstKey,
      secondKey: secondKey,
      showSecond: showSecond,
      onSecondBuild: firstBuilds.add,
    );

    await tester.pumpWidget(build(showSecond: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final alpha = firstKey.currentState!.pulse.value;
    expect(alpha, isNot(schedule.alphaAt(Duration.zero)));

    await tester.pumpWidget(build(showSecond: true));
    expect(firstBuilds, [alpha]);
    expect(secondKey.currentState!.pulse.value, alpha);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('one muted pulse receives no notifications across 30 steps', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    Widget build({required bool secondEnabled}) => _hosts(
      clock: clock,
      firstKey: firstKey,
      secondKey: secondKey,
      secondEnabled: secondEnabled,
    );

    await tester.pumpWidget(build(secondEnabled: true));
    await tester.pump();
    await tester.pumpWidget(build(secondEnabled: false));
    final first = firstKey.currentState!.pulse;
    final second = secondKey.currentState!.pulse;
    final mutedAlpha = second.value;
    var firstNotifications = 0;
    var secondNotifications = 0;
    first.addListener(() => firstNotifications++);
    second.addListener(() => secondNotifications++);

    var changes = 0;
    var alpha = first.value;
    for (var ms = 1; ms <= cycle.inMilliseconds; ms++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(first.value, schedule.alphaAt(Duration(milliseconds: ms)));
      expect(second.value, mutedAlpha);
      if (first.value != alpha) changes++;
      alpha = first.value;
    }
    expect(changes, 30);
    expect(firstNotifications, 30);
    expect(secondNotifications, 0);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(build(secondEnabled: true));
    await tester.pump();
    expect(second.value, schedule.alphaAt(const Duration(milliseconds: 4700)));
    expect(second.value, first.value);
    expect(secondNotifications, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('all muted pulses exhaust one wake without renewing the timer', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    Widget build({required bool enabled}) => _hosts(
      clock: clock,
      firstKey: firstKey,
      secondKey: secondKey,
      firstEnabled: enabled,
      secondEnabled: enabled,
    );

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    final origin = tester.binding.clock.now();
    var notifications = 0;
    firstKey.currentState!.pulse.addListener(() => notifications++);
    secondKey.currentState!.pulse.addListener(() => notifications++);
    await tester.pumpWidget(build(enabled: false));
    expect(clock.hasPendingWake, isTrue);

    await tester.pump(schedule.nextChangeAfter(Duration.zero));
    expect(clock.hasPendingWake, isFalse);
    for (var ms = 0; ms < cycle.inMilliseconds; ms++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(clock.hasPendingWake, isFalse);
    }
    expect(notifications, 0);

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    final elapsed = tester.binding.clock.now().difference(origin);
    expect(firstKey.currentState!.pulse.value, schedule.alphaAt(elapsed));
    expect(
      secondKey.currentState!.pulse.value,
      firstKey.currentState!.pulse.value,
    );
    expect(clock.hasPendingWake, isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('joining a clock dormant from muting restarts sampling', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    Widget build({required bool showSecond, bool firstEnabled = false}) =>
        _hosts(
          clock: clock,
          firstKey: firstKey,
          secondKey: secondKey,
          firstEnabled: firstEnabled,
          showSecond: showSecond,
        );

    await tester.pumpWidget(build(showSecond: false, firstEnabled: true));
    await tester.pump();
    await tester.pumpWidget(build(showSecond: false));
    await tester.pump(const Duration(milliseconds: 700));
    expect(clock.hasPendingWake, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(build(showSecond: true));
    await tester.pump();
    expect(
      secondKey.currentState!.pulse.value,
      schedule.alphaAt(const Duration(milliseconds: 700)),
    );
    expect(clock.hasPendingWake, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      secondKey.currentState!.pulse.value,
      schedule.alphaAt(const Duration(milliseconds: 1400)),
    );
  });

  testWidgets('an initially muted clock starts at its first sampled frame', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    Widget build({required bool enabled}) => _hosts(
      clock: clock,
      firstKey: firstKey,
      secondKey: secondKey,
      firstEnabled: enabled,
      showSecond: false,
    );
    await tester.pumpWidget(build(enabled: false));
    await tester.pump(const Duration(milliseconds: 700));
    expect(clock.hasPendingWake, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    expect(firstKey.currentState!.pulse.value, schedule.alphaAt(Duration.zero));
    expect(clock.hasPendingWake, isTrue);
  });

  testWidgets('reset returns the only subscriber and its clock to idle', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final pulse = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      pulse.repeat();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(pulse.value, isNot(schedule.alphaAt(Duration.zero)));

      pulse.reset();
      expect(pulse.value, schedule.initialAlpha);
      expect(clock.hasPendingWake, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      var notifications = 0;
      pulse.addListener(() => notifications++);
      await tester.pump(cycle);
      expect(notifications, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      pulse.repeat();
      await tester.pump();
      expect(pulse.value, schedule.alphaAt(Duration.zero));
      expect(clock.hasPendingWake, isTrue);
    } finally {
      pulse.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('reattaching joins the shared phase instead of resuming', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final first = QuantizedAlphaPulse(vsync: tester, clock: clock);
    final second = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      first.repeat();
      second.repeat();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      second.reset();
      expect(clock.hasPendingWake, isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(second.value, schedule.initialAlpha);

      second.repeat();
      expect(second.value, first.value);
      expect(
        second.value,
        schedule.alphaAt(const Duration(milliseconds: 2200)),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      first.dispose();
      second.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });

  testWidgets('a muted reattachment adopts the published alpha silently', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final firstKey = GlobalKey<_PulseHostState>();
    final secondKey = GlobalKey<_PulseHostState>();
    await tester.pumpWidget(
      _hosts(
        clock: clock,
        firstKey: firstKey,
        secondKey: secondKey,
        secondEnabled: false,
      ),
    );
    await tester.pump();
    final first = firstKey.currentState!.pulse;
    final second = secondKey.currentState!.pulse;
    second.reset();
    await tester.pump(const Duration(milliseconds: 700));
    var notifications = 0;
    second.addListener(() => notifications++);

    second.repeat();
    expect(second.value, first.value);
    expect(notifications, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disposing every subscriber clears the timer and phase', (
    tester,
  ) async {
    final clock = QuantizedAlphaClock(schedule: schedule);
    final first = QuantizedAlphaPulse(vsync: tester, clock: clock);
    final second = QuantizedAlphaPulse(vsync: tester, clock: clock);
    first.repeat();
    second.repeat();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    first.dispose();
    expect(clock.hasPendingWake, isTrue);
    second.dispose();
    expect(clock.hasPendingWake, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(cycle);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final next = QuantizedAlphaPulse(vsync: tester, clock: clock);
    try {
      expect(next.value, schedule.initialAlpha);
      next.repeat();
      await tester.pump();
      expect(next.value, schedule.alphaAt(Duration.zero));
      await tester.pump(const Duration(milliseconds: 700));
      expect(next.value, schedule.alphaAt(const Duration(milliseconds: 700)));
    } finally {
      next.dispose();
    }
    expect(clock.hasPendingWake, isFalse);
  });
}

Widget _hosts({
  required QuantizedAlphaClock clock,
  required GlobalKey<_PulseHostState> firstKey,
  required GlobalKey<_PulseHostState> secondKey,
  bool showSecond = true,
  bool firstEnabled = true,
  bool secondEnabled = true,
  ValueChanged<double>? onSecondBuild,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Row(
    children: [
      TickerMode(
        enabled: firstEnabled,
        child: _PulseHost(key: firstKey, clock: clock),
      ),
      if (showSecond)
        TickerMode(
          enabled: secondEnabled,
          child: _PulseHost(
            key: secondKey,
            clock: clock,
            onBuild: onSecondBuild,
          ),
        ),
    ],
  ),
);

class _PulseHost extends StatefulWidget {
  const _PulseHost({super.key, required this.clock, this.onBuild});

  final QuantizedAlphaClock clock;
  final ValueChanged<double>? onBuild;

  @override
  State<_PulseHost> createState() => _PulseHostState();
}

class _PulseHostState extends State<_PulseHost>
    with SingleTickerProviderStateMixin {
  late final pulse = QuantizedAlphaPulse(vsync: this, clock: widget.clock)
    ..repeat();

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: pulse,
    builder: (context, alpha, _) {
      widget.onBuild?.call(alpha);
      return SizedBox.square(
        dimension: 40,
        child: ColoredBox(color: Colors.blue.withValues(alpha: alpha)),
      );
    },
  );
}
