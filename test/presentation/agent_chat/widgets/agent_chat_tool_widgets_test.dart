import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_widgets.dart';

void main() {
  Future<void> pumpResult(WidgetTester tester, ToolResultMessage result) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AgentChatToolResultTile(result: result)),
      ),
    );
  }

  testWidgets('successful result is a collapsed human readable summary', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'success-1',
      toolName: 'search_tags',
      content: const [
        ToolResultTextContent(
          '{"ok":true,"message":"Found 3 matching tags","items":[1,2,3]}',
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.textContaining('Found 3 matching tags'), findsOneWidget);
    expect(find.textContaining('Success'), findsOneWidget);
    expect(find.textContaining('{"ok":true,"message"'), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-tool-result-details-success-1')),
      findsNothing,
    );
  });

  testWidgets('error summary stays visible and details can be expanded', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'error-1',
      toolName: 'web_search',
      isError: true,
      content: const [
        ToolResultTextContent(
          '{"error":"Network request failed","status":503}',
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.textContaining('Network request failed'), findsOneWidget);
    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.textContaining('"status": 503'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-tool-result-error-1')));
    await tester.pump();

    expect(find.textContaining('"status": 503'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-tool-result-details-error-1')),
      findsOneWidget,
    );
  });

  testWidgets('expanded detail is bounded scrollable selectable and copyable', (
    tester,
  ) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final values = List<String>.generate(80, (index) => 'value-$index');
    final rawJson = jsonEncode({'values': values});
    final result = ToolResultMessage(
      toolCallId: 'detail-1',
      toolName: 'read',
      content: [ToolResultTextContent(rawJson)],
    );

    await pumpResult(tester, result);
    await tester.tap(find.byKey(const ValueKey('agent-tool-result-detail-1')));
    await tester.pump();

    final panel = find.byKey(
      const ValueKey('agent-tool-result-details-detail-1'),
    );
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.byType(SelectableText)),
      findsOneWidget,
    );
    expect(tester.getSize(panel).height, lessThanOrEqualTo(252));

    await tester.tap(
      find.descendant(
        of: panel,
        matching: find.byKey(const ValueKey('agent-tool-detail-copy')),
      ),
    );
    await tester.pump();
    expect(copiedText, contains('"value-79"'));
    expect(copiedText, contains('\n'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('renders explicit ToolResultImageContent previews', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'preview-1',
      toolName: 'preview_generated_image',
      content: [
        ToolResultImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: 'image/png',
              base64Data: base64Encode(_onePixelPng),
            ),
          ),
        ),
      ],
    );

    await pumpResult(tester, result);

    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-tool-result-preview-1')));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders persisted generation files without a display tool', (
    tester,
  ) async {
    final result = ToolResultMessage(
      toolCallId: 'generate-1',
      toolName: 'generate_image',
      content: const [ToolResultTextContent('{"ok":true}')],
      details: const {
        'files': ['missing-generated-result.png'],
      },
    );

    await pumpResult(tester, result);
    await tester.pump();

    expect(find.textContaining('missing-generated-result.png'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('agent-tool-result-generate-1')),
    );
    await tester.pump();
    expect(find.textContaining('missing-generated-result.png'), findsWidgets);
  });

  testWidgets('tool group keeps a concrete failure summary visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentChatToolResultGroup(
            results: [
              ToolResultMessage(
                toolCallId: 'ok',
                toolName: 'read',
                content: const [ToolResultTextContent('{"ok":true}')],
              ),
              ToolResultMessage(
                toolCallId: 'failed',
                toolName: 'web_search',
                isError: true,
                content: const [
                  ToolResultTextContent(
                    '{"error":"Upstream search timed out","status":504}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('Upstream search timed out'), findsOneWidget);
    expect(find.textContaining('"status"'), findsNothing);
  });
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6qv0YAAAAASUVORK5CYII=',
);
