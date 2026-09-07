import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/core/windowing/agent_chat_code_block.dart';
import 'package:nai_launcher/core/windowing/agent_chat_shared_widgets.dart';

void main() {
  testWidgets('code blocks copy whitespace and update while streaming', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    for (final code in ['  first\n', '  first\n\nsecond\n']) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentChatMarkdownContent(
              text: '```dart\n$code```',
              touchOptimized: true,
            ),
          ),
        ),
      );
      expect(find.byType(AgentChatCodeBlock), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();
      expect(copied, code);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

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
