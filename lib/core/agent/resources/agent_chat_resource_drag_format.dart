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
    _decodeLocalReference(item.localData) != null ||
    item.canProvide(agentChatResourceDragFormat);

Future<AgentChatResourceReference?> readAgentResourceDropItem(
  DropItem item,
) async {
  final local = _decodeLocalReference(item.localData);
  if (local != null) return local;
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

AgentChatResourceReference? _decodeLocalReference(Object? value) {
  try {
    return switch (value) {
      AgentChatResourceReference() => value,
      String() => AgentChatResourceReferenceCodec.decodeJson(value),
      Map() => AgentChatResourceReferenceCodec.decodeJsonMap(
        Map<String, dynamic>.from(value),
      ),
      _ => null,
    };
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
