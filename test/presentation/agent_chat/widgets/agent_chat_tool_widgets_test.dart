import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_widgets.dart';

void main() {
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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AgentChatToolResultTile(result: result)),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
