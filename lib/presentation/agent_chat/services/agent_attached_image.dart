import 'dart:typed_data';

import '../../../core/agent/llm_types.dart';
import '../models/agent_chat_prompt_envelope.dart';

/// Uses the latest user turn, including restored prompt envelopes. Never falls
/// back to an older turn when the current one has no image at this index.
Uint8List? readAgentAttachedImage(List<Message> messages, int index) {
  if (index < 1) return null;
  for (final message in messages.reversed) {
    final user = visibleUserMessage(message);
    if (user == null) continue;
    final images = user.content.whereType<UserImageContent>().toList();
    if (index > images.length) return null;
    return images[index - 1].image.source.bytes;
  }
  return null;
}
