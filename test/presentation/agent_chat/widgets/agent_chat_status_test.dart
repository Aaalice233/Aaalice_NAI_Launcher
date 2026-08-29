import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_approval.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_status.dart';

void main() {
  Widget app({
    required double width,
    required Widget child,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true, textScaler: textScaler),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('running work status is static and bounded at narrow width', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0, 600.0, 840.0]) {
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(2),
          child: const AgentChatWorkStatus(
            phase: AgentChatWorkPhase.usingTools,
            routeLabel: 'provider/very-long-production-model-route-name',
            touchOptimized: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-chat-work-status')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('approval stays actionable and bounded on a narrow phone', (
    tester,
  ) async {
    final decisions = <bool>[];
    await tester.pumpWidget(
      app(
        width: 240,
        child: AgentChatApprovalCard(
          toolName: 'submit_generation',
          args: {
            'prompt': List.filled(30, 'long production prompt').join(' '),
            'model': 'nai-diffusion-4-full',
          },
          estimatedAnlas: 12,
          touchOptimized: true,
          onResolve: decisions.add,
        ),
      ),
    );

    expect(find.textContaining('12 Anlas'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final detailsToggle = find.byKey(
      const ValueKey('agent-chat-approval-details'),
    );
    await tester.tap(detailsToggle);
    await tester.pump();

    final details = find.descendant(
      of: detailsToggle,
      matching: find.byType(AgentToolDetailSurface),
    );
    expect(details, findsOneWidget);
    expect(tester.getSize(details).height, lessThanOrEqualTo(132));
    expect(
      find.descendant(of: details, matching: find.byType(SelectableText)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FilledButton));
    expect(decisions, [isTrue]);
  });
}
