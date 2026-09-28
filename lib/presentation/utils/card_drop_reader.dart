import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../data/models/vibe/vibe_library_entry.dart';
import '../../data/services/precise_ref_library_storage_service.dart';
import '../agent_chat/services/agent_resource_resolver.dart';
import '../providers/vibe_library_provider.dart';
import 'card_drag_format.dart';
import 'dropped_file_reader.dart';
import 'gallery_drop_reader.dart' show galleryInternalDragPathFromLocalData;
import '../../core/utils/localization_extension.dart';

export 'dropped_file_reader.dart' show DroppedFileData;

final cardDropFormats = [
  cardDragFormat,
  agentChatResourceDragFormat,
  ...Formats.standardFormats,
];

class CardDropPolicy {
  const CardDropPolicy({
    this.allowMultiple = true,
    this.allowVibes = false,
    this.allowPreciseReferences = true,
    this.allowPreciseReferenceFiles = false,
  });
  final bool allowMultiple;
  final bool allowVibes;
  final bool allowPreciseReferences;
  final bool allowPreciseReferenceFiles;

  bool accepts(Iterable<DropItem> items) {
    if (items.isEmpty || (!allowMultiple && items.length != 1)) return false;
    return items.every((item) {
      final reference = decodeLocalAgentResource(item.localData);
      if (reference != null) {
        return switch (reference.kind) {
          AgentChatResourceKind.vibeLibraryEntry => allowVibes,
          AgentChatResourceKind.preciseRefLibraryEntry =>
            allowPreciseReferences,
          AgentChatResourceKind.tagLibraryEntry ||
          AgentChatResourceKind.fixedTag => false,
          _ => true,
        };
      }
      if (galleryInternalDragPathFromLocalData(item.localData) != null) {
        return true;
      }
      return Formats.standardFormats.any(item.canProvide);
    });
  }
}

class CardDroppedResource {
  const CardDroppedResource({this.file, this.vibe, this.preciseReference});
  final DroppedFileData? file;
  final VibeLibraryEntry? vibe;
  final PreciseRefLibraryEntry? preciseReference;

  DroppedFileData get image {
    final value = file;
    if (value == null || vibe != null) {
      throw StateError('This target requires an image');
    }
    return value;
  }
}

final cardDropReaderProvider = Provider(CardDropReader.new);

class CardDropReader {
  CardDropReader(this._ref) : _resolver = AgentResourceResolver(_ref);
  final Ref _ref;
  final AgentResourceResolver _resolver;

  Future<CardDroppedResource> read(DropItem item) async {
    final reference = decodeLocalAgentResource(item.localData);
    if (reference?.kind == AgentChatResourceKind.vibeLibraryEntry) {
      final owner = _ref.read(vibeLibraryNotifierProvider.notifier);
      final entry = (await owner.resolveEntriesByIds([
        reference!.resourceId,
      ])).singleOrNull;
      if (entry == null) {
        throw StateError('Vibe is unavailable: ${reference.resourceId}');
      }
      return CardDroppedResource(vibe: entry);
    }
    if (reference?.kind == AgentChatResourceKind.preciseRefLibraryEntry) {
      final storage = _ref.read(preciseRefLibraryStorageServiceProvider);
      final entry = (await storage.getAllEntries())
          .where((entry) => entry.id == reference!.resourceId)
          .singleOrNull;
      if (entry == null) {
        throw StateError(
          'Precise reference is unavailable: ${reference!.resourceId}',
        );
      }
      return CardDroppedResource(
        preciseReference: entry,
        file: DroppedFileData(
          bytes: await File(entry.imagePath).readAsBytes(),
          fileName: p.basename(entry.imagePath),
          sourcePath: entry.imagePath,
        ),
      );
    }
    final path = galleryInternalDragPathFromLocalData(item.localData);
    if (path != null) {
      return CardDroppedResource(
        file: DroppedFileData(
          bytes: await File(path).readAsBytes(),
          fileName: p.basename(path),
          sourcePath: path,
        ),
      );
    }
    if (reference != null) {
      final resolved = await _resolver.resolve(reference);
      final bytes = resolved?.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Image is unavailable: ${reference.resourceId}');
      }
      final extension = PreciseRefLibraryStorageService.detectImageExtension(
        bytes,
      );
      return CardDroppedResource(
        file: DroppedFileData(
          bytes: bytes,
          fileName: '${reference.resourceId}$extension',
          sourcePath: resolved?.filePath,
        ),
      );
    }
    throw StateError('This item is not an internal card resource');
  }
}

/// Capture all native readers before awaiting; a drop cannot outlive its callback.
/// Every member must resolve before the caller starts any business mutation.
Future<List<CardDroppedResource>> readCardDrop(
  BuildContext context,
  Iterable<DropItem> items, {
  CardDropPolicy policy = const CardDropPolicy(),
}) {
  final snapshot = List<DropItem>.unmodifiable(items);
  if (!policy.accepts(snapshot)) {
    throw StateError(context.l10n.cardDrop_unsupported);
  }
  CardDropReader? internalReader;
  Future<CardDroppedResource> readInternal(DropItem item) {
    final CardDropReader reader =
        internalReader ??
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(cardDropReaderProvider);
    internalReader = reader;
    return reader.read(item);
  }

  return Future.wait([
    for (final item in snapshot)
      if (decodeLocalAgentResource(item.localData) != null ||
          galleryInternalDragPathFromLocalData(item.localData) != null)
        readInternal(item)
      else
        _readExternal(item, policy),
  ]);
}

Future<CardDroppedResource> _readExternal(
  DropItem item,
  CardDropPolicy policy,
) async {
  final reader = item.dataReader;
  if (reader == null) throw StateError('Drop reader is unavailable');
  final file = await DroppedFileReader.read(
    reader,
    allowVibeFiles: policy.allowVibes,
    allowPreciseReferenceFiles: policy.allowPreciseReferenceFiles,
    logTag: 'CardDrop',
  );
  if (file == null || file.bytes.isEmpty) {
    throw StateError('Drop item has no readable contents');
  }
  return CardDroppedResource(file: file);
}
