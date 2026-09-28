import 'dart:async';
import 'dart:typed_data';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';

/// The reference stays lightweight; exporting belongs to the resource owner.
class CardDragResource {
  const CardDragResource({
    required this.id,
    required this.fileName,
    this.reference,
    this.localData,
    this.format,
    this.prepare,
  });

  final String id;
  final String fileName;
  final AgentChatResourceReference? reference;
  final Object? localData;
  final FileFormat? format;
  final Future<Uint8List> Function()? prepare;

  Object? get payload {
    final original = localData;
    return {
      if (original is Map) ...original,
      'cardDragId': id,
      if (reference != null)
        'cardResource': AgentChatResourceReferenceCodec.encodeJson(reference!),
    };
  }
}

/// One failed export fails every reader before any file contents are delivered.
/// The future is memoized only for this native session, never for card hover.
class CardDragPreparation {
  CardDragPreparation(
    Iterable<CardDragResource> resources, {
    this.onStarted,
    this.onFinished,
  }) : resources = List.unmodifiable(resources);

  final List<CardDragResource> resources;
  final void Function()? onStarted;
  final void Function()? onFinished;
  Future<List<Uint8List?>>? _future;

  Future<List<Uint8List?>> prepare() => _future ??= _prepareAll();

  Future<List<Uint8List?>> _prepareAll() async {
    onStarted?.call();
    try {
      final result = <Uint8List?>[];
      for (final resource in resources) {
        result.add(await resource.prepare?.call());
      }
      return List.unmodifiable(result);
    } finally {
      onFinished?.call();
    }
  }

  Future<Uint8List> bytesAt(int index) async {
    final bytes = (await prepare())[index];
    if (bytes == null || bytes.isEmpty) {
      throw StateError(
        'Resource has no exportable contents: ${resources[index].id}',
      );
    }
    return bytes;
  }
}
