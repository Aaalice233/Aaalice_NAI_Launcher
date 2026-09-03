import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_reading_preferences.dart';

void main() {
  testWidgets('Agent reading scale composes with inherited global scaling', (
    tester,
  ) async {
    late double effectiveScale;
    late VisualDensity visualDensity;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: AgentChatReadingPreferences(
          config: const AgentChatConfig(
            readingTextScale: 1.15,
            density: AgentChatDensity.compact,
          ),
          desktop: false,
          child: Builder(
            builder: (context) {
              effectiveScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              visualDensity = Theme.of(context).visualDensity;
              return const Text('Agent content');
            },
          ),
        ),
      ),
    );

    expect(effectiveScale, moreOrLessEquals(1.38));
    expect(visualDensity, const VisualDensity(horizontal: -1, vertical: -1));
  });

  testWidgets('Agent reading scale preserves nonlinear inherited scaling', (
    tester,
  ) async {
    late double scaledSmall;
    late double scaledLarge;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const _NonlinearTestScaler()),
          child: child!,
        ),
        home: AgentChatReadingPreferences(
          config: const AgentChatConfig(readingTextScale: 1.3),
          desktop: false,
          child: Builder(
            builder: (context) {
              final scaler = MediaQuery.textScalerOf(context);
              scaledSmall = scaler.scale(10);
              scaledLarge = scaler.scale(20);
              return const Text('Agent content');
            },
          ),
        ),
      ),
    );

    expect(scaledSmall, moreOrLessEquals(15.6));
    expect(scaledLarge, moreOrLessEquals(33.8));
    expect(scaledSmall / 10, isNot(moreOrLessEquals(scaledLarge / 20)));
  });

  testWidgets('mobile defaults stay comfortable without reducing text', (
    tester,
  ) async {
    late double effectiveScale;
    late VisualDensity visualDensity;

    await tester.pumpWidget(
      MaterialApp(
        home: AgentChatReadingPreferences(
          config: const AgentChatConfig(),
          desktop: false,
          child: Builder(
            builder: (context) {
              effectiveScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              visualDensity = Theme.of(context).visualDensity;
              return const SizedBox(width: 360, child: Text('Agent content'));
            },
          ),
        ),
      ),
    );

    expect(effectiveScale, 1);
    expect(visualDensity, VisualDensity.standard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop applies a larger baseline to the entire chat surface', (
    tester,
  ) async {
    late double effectiveScale;

    await tester.pumpWidget(
      MaterialApp(
        home: AgentChatReadingPreferences(
          config: const AgentChatConfig(),
          desktop: true,
          child: Builder(
            builder: (context) {
              effectiveScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              return const Text('Agent content');
            },
          ),
        ),
      ),
    );

    expect(
      effectiveScale,
      moreOrLessEquals(AgentChatReadingPreferences.desktopBaselineScale),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop baseline does not multiply accessibility scaling', (
    tester,
  ) async {
    late double effectiveScale;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AgentChatReadingPreferences(
          config: const AgentChatConfig(),
          desktop: true,
          child: Builder(
            builder: (context) {
              effectiveScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              return const Text('Agent content');
            },
          ),
        ),
      ),
    );

    expect(effectiveScale, 2);
    expect(tester.takeException(), isNull);
  });
}

final class _NonlinearTestScaler extends TextScaler {
  const _NonlinearTestScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 12 ? fontSize * 1.2 : fontSize * 1.3;

  @override
  double get textScaleFactor => 1.2;
}
