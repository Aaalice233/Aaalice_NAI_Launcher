import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/llm_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_messages.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_chat_prompt_envelope.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_attached_image.dart';

UserImageContent image(int value) => UserImageContent(
  ImageContent(
    source: ImageSource.base64(
      mimeType: 'image/png',
      base64Data: base64Encode([value]),
    ),
  ),
);

void main() {
  test(
    'inline attachment selection uses message order without filesystem paths',
    () {
      final messages = [
        UserMessage(
          content: [image(1), const UserTextContent('compare'), image(2)],
        ),
      ];
      expect(readAgentAttachedImage(messages, 1), [1]);
      expect(readAgentAttachedImage(messages, 2), [2]);
      expect(readAgentAttachedImage(messages, 0), isNull);
      expect(readAgentAttachedImage(messages, 3), isNull);
    },
  );

  test('restored skill/resource envelope keeps the same attachment lookup', () {
    final envelope = HarnessCustomMessage(
      customType: agentPromptEnvelopeType,
      timestamp: 1,
      display: true,
      blockContent: [const UserTextContent('resource prefix'), image(3)],
      details: const {'visibleContentOffset': 1},
    );
    expect(readAgentAttachedImage([envelope], 1), [3]);
  });

  test('new user turn without images does not select a stale attachment', () {
    final messages = [
      UserMessage(content: [image(1)]),
      UserMessage.text('new task'),
    ];
    expect(readAgentAttachedImage(messages, 1), isNull);
  });
}
