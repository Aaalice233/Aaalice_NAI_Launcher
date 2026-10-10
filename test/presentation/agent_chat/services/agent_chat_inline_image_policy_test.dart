import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_inline_image_policy.dart';

void main() {
  test('accepts every format offered to keyboard image insertion', () {
    final samples = {
      'image/png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      'image/jpeg': [0xFF, 0xD8, 0xFF, 0xE0],
      'image/webp': ascii.encode('RIFF\x00\x00\x00\x00WEBP'),
      'image/gif': [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
    };

    expect(samples.keys, unorderedEquals(AgentChatInlineImagePolicy.mimeTypes));
    for (final MapEntry(key: mimeType, value: header) in samples.entries) {
      final check = AgentChatInlineImagePolicy.check(
        Uint8List.fromList(header),
      );
      expect(
        check,
        isA<AgentChatInlineImageAccepted>().having(
          (accepted) => accepted.mimeType,
          'mimeType',
          mimeType,
        ),
      );
    }
  });

  test('rejects images the model cannot read, including empty data', () {
    final bmp = Uint8List.fromList([0x42, 0x4D, 0, 0, 0, 0]);

    for (final bytes in [bmp, Uint8List(0)]) {
      expect(
        AgentChatInlineImagePolicy.check(bytes),
        isA<AgentChatInlineImageRejected>().having(
          (rejected) => rejected.reason,
          'reason',
          AgentChatInlineImageRejection.unsupportedFormat,
        ),
      );
    }
  });

  test('the size limit is inclusive and checked before the format', () {
    final atLimit = Uint8List(AgentChatInlineImagePolicy.maxBytes)
      ..setAll(0, [0x89, 0x50, 0x4E, 0x47]);
    final overLimit = Uint8List(AgentChatInlineImagePolicy.maxBytes + 1);

    expect(
      AgentChatInlineImagePolicy.check(atLimit),
      isA<AgentChatInlineImageAccepted>(),
    );
    expect(
      AgentChatInlineImagePolicy.check(overLimit),
      isA<AgentChatInlineImageRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        AgentChatInlineImageRejection.tooLarge,
      ),
    );
  });
}
