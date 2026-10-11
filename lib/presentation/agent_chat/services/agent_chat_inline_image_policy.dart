import 'dart:typed_data';

import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

/// Admission rule shared by every way an image enters the composer inline:
/// file picker, clipboard paste, drag and drop, and keyboard insertion.
abstract final class AgentChatInlineImagePolicy {
  static const int maxMegabytes = 20;
  static const int maxBytes = maxMegabytes * 1024 * 1024;

  /// Formats [detectImageMime] recognises, offered to IMEs that insert images.
  static const List<String> mimeTypes = [
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  ];

  static AgentChatInlineImageCheck check(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      return const AgentChatInlineImageRejected(
        AgentChatInlineImageRejection.tooLarge,
      );
    }
    final mimeType = detectImageMime(bytes);
    if (mimeType == null) {
      return const AgentChatInlineImageRejected(
        AgentChatInlineImageRejection.unsupportedFormat,
      );
    }
    return AgentChatInlineImageAccepted(mimeType);
  }
}

enum AgentChatInlineImageRejection { tooLarge, unsupportedFormat }

sealed class AgentChatInlineImageCheck {
  const AgentChatInlineImageCheck();
}

final class AgentChatInlineImageAccepted extends AgentChatInlineImageCheck {
  const AgentChatInlineImageAccepted(this.mimeType);

  final String mimeType;
}

final class AgentChatInlineImageRejected extends AgentChatInlineImageCheck {
  const AgentChatInlineImageRejected(this.reason);

  final AgentChatInlineImageRejection reason;
}
