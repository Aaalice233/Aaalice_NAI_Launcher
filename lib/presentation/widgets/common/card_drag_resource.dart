import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/async_work_pool.dart';
import '../../../core/utils/isolate_pool.dart';

/// The reference stays lightweight; exporting belongs to the resource owner.
class CardDragResource {
  const CardDragResource({
    required this.id,
    required this.fileName,
    this.reference,
    this.localData,
    this.format,
    this.prepare,
    this.readyFile,
  });

  static const _payloadIdKey = 'cardDragId';

  final String id;
  final String fileName;
  final AgentChatResourceReference? reference;
  final Object? localData;
  final FileFormat? format;
  final Future<Uint8List> Function()? prepare;

  /// An existing file whose bytes equal what [prepare] would produce; handing
  /// out its path skips preparation entirely.
  final Future<File?> Function()? readyFile;

  /// Whether a drop item's local data came from a card drag of this app.
  static bool isPayload(Object? localData) =>
      localData is Map && localData.containsKey(_payloadIdKey);

  Object? get payload {
    final original = localData;
    return {
      if (original is Map) ...original,
      _payloadIdKey: id,
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
      // Isolate work is gated anyway; more admissions only hold more originals.
      final pool = AsyncWorkPool(ComputeGate().maxConcurrentTasks);
      final result = await Future.wait([
        for (final resource in resources)
          pool.run<Uint8List>(() async => resource.prepare?.call()),
      ], eagerError: true);
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
