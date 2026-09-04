import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_approval.dart';

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
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
  }

  AgentChatApprovalCard approval({
    Key? key,
    String requestId = 'request-1',
    Map<String, dynamic>? args,
    int? estimatedAnlas = 12,
    ValueChanged<bool>? onResolve,
  }) {
    return AgentChatApprovalCard(
      key: key ?? ValueKey(requestId),
      toolName: 'submit_generation',
      args:
          args ??
          {
            'prompt': 'A detailed three-day weather chart',
            'model': 'nai-diffusion-4-full',
            'images': 1,
          },
      estimatedAnlas: estimatedAnlas,
      onResolve: onResolve ?? (_) {},
    );
  }

  testWidgets('is bounded at required widths with TextScaler 2', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0, 600.0, 840.0]) {
      await tester.pumpWidget(
        app(
          width: width,
          textScaler: const TextScaler.linear(2),
          child: approval(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('agent-chat-approval-surface')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'width $width');

      final buttonFinder = find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
      );
      expect(buttonFinder, findsNWidgets(2));
      for (final element in buttonFinder.evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    }
  });

  testWidgets('shows an estimate only when authoritative estimate exists', (
    tester,
  ) async {
    await tester.pumpWidget(app(width: 360, child: approval()));
    expect(find.textContaining('12 Anlas'), findsOneWidget);

    await tester.pumpWidget(
      app(width: 360, child: approval(estimatedAnlas: null)),
    );
    expect(find.textContaining('Anlas'), findsNothing);
  });

  testWidgets('expands sanitized parameters without credentials or paths', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        width: 360,
        child: approval(
          args: {
            'api_token': 'pst-super-secret-token-value',
            'password': 'hunter2',
            'output_path': r'C:\Users\Alice\private\result.png',
            'image': Uint8List.fromList([1, 2, 3]),
            'prompt': 'safe prompt',
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('agent-chat-approval-details')));
    await tester.pumpAndSettle();

    expect(find.textContaining('[redacted]'), findsWidgets);
    expect(find.textContaining('[local path]'), findsWidgets);
    expect(find.textContaining('[binary omitted]'), findsWidgets);
    expect(find.textContaining('safe prompt'), findsWidgets);
    expect(find.textContaining('pst-super-secret-token-value'), findsNothing);
    expect(find.textContaining(r'C:\Users\Alice'), findsNothing);
  });

  testWidgets(
    'same tool and arguments become actionable for a new request id',
    (tester) async {
      final decisions = <bool>[];
      await tester.pumpWidget(
        app(width: 360, child: approval(onResolve: decisions.add)),
      );

      final allow = find.byType(FilledButton);
      await tester.tap(allow);
      await tester.tap(allow);
      await tester.pump();
      expect(decisions, [isTrue]);

      await tester.pumpWidget(
        app(
          width: 360,
          child: approval(requestId: 'request-2', onResolve: decisions.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      expect(decisions, [isTrue, isFalse]);
    },
  );

  testWidgets('delete approvals retain irreversible-risk wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        width: 360,
        child: AgentChatApprovalCard(
          toolName: 'delete_tag_library_entry',
          args: const {'id': 'entry-1'},
          estimatedAnlas: null,
          onResolve: (_) {},
        ),
      ),
    );

    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(find.textContaining('Anlas'), findsNothing);
  });
}
