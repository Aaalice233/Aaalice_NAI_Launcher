import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'agent_chat_resource_reference.dart';
import 'agent_chat_resource_reference_codec.dart';

final agentChatResourceDragFormat = CustomValueFormat<String>(
  applicationId: AgentChatResourceReferenceCodec.mediaType,
  onEncode: (value, _) => value,
  onDecode: (value, _) async => switch (value) {
    String() => value,
    Uint8List() => utf8.decode(value),
    _ => null,
  },
);

void addAgentResourceDragPayload(
  DragItem item,
  AgentChatResourceReference reference,
) {
  item.add(
    agentChatResourceDragFormat(
      AgentChatResourceReferenceCodec.encodeJson(reference),
    ),
  );
}

bool canReadAgentResourceDropItem(DropItem item) =>
    item.localData is AgentChatResourceReference ||
    item.canProvide(agentChatResourceDragFormat);

Future<AgentChatResourceReference?> readAgentResourceDropItem(
  DropItem item,
) async {
  final local = item.localData;
  if (local is AgentChatResourceReference) return local;
  final reader = item.dataReader;
  if (reader == null || !item.canProvide(agentChatResourceDragFormat)) {
    return null;
  }
  final completer = Completer<String?>();
  reader.getValue<String>(
    agentChatResourceDragFormat,
    completer.complete,
    onError: completer.completeError,
  );
  final payload = await completer.future;
  return payload == null
      ? null
      : AgentChatResourceReferenceCodec.decodeJson(payload);
}
