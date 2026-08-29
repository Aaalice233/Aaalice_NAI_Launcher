import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';

void main() {
  testWidgets(
    'context indicator stays visible before and after usage arrives',
    (tester) async {
      Widget build({int? used, int? window, bool compacting = false}) =>
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: AgentChatContextIndicator(
                  usedTokens: used,
                  contextWindow: window,
                  usageLabel: used == null ? 'Unavailable' : '$used / $window',
                  unavailableLabel: 'Unavailable',
                  compactingLabel: 'Compacting',
                  compacting: compacting,
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      expect(
        find.byKey(const ValueKey('agent-chat-context-indicator')),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);

      await tester.pumpWidget(build(used: 96000, window: 128000));
      expect(find.text('96000 / 128000'), findsOneWidget);

      await tester.pumpWidget(
        build(used: 128000, window: 128000, compacting: true),
      );
      expect(find.text('Compacting'), findsOneWidget);
    },
  );

  testWidgets('approval surface keeps both actions usable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var resolved = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentChatApprovalSurface(
              title: 'Generate image',
              description: 'This action changes data.',
              details: '{"prompt":"a long prompt"}',
              costLabel: 'Estimated cost: 3 Anlas',
              denyLabel: 'Deny',
              allowLabel: 'Allow once',
              touchOptimized: true,
              onDeny: () => resolved = 'deny',
              onAllow: () => resolved = 'allow',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final deny = find.widgetWithText(OutlinedButton, 'Deny');
    final allow = find.widgetWithText(FilledButton, 'Allow once');
    expect(tester.getSize(deny).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(allow).height, greaterThanOrEqualTo(48));
    await tester.tap(allow);
    expect(resolved, 'allow');
  });
}
