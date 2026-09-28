import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../core/utils/file_name_sanitizer.dart';
import '../../core/utils/image_share_sanitizer.dart';
import '../../core/utils/vibe_export_utils.dart';
import '../../data/services/precise_ref_library_archive_service.dart';
import '../../data/services/precise_ref_library_storage_service.dart';
import '../agent_chat/services/agent_resource_resolver.dart';
import '../providers/copy_drag_watermark_provider.dart';
import '../providers/share_image_settings_provider.dart';
import '../providers/vibe_library_provider.dart';
import '../providers/online_gallery_provider.dart';
import '../widgets/common/card_drag_resource.dart';
import 'card_image_drag_factory.dart';

final cardResourceDragFactoryProvider = Provider(CardResourceDragFactory.new);

/// Adapts business resources to portable files; the card shell never loads them.
class CardResourceDragFactory {
  CardResourceDragFactory(this._ref) : _resolver = AgentResourceResolver(_ref);
  final Ref _ref;
  final AgentResourceResolver _resolver;

  CardDragResource create(AgentChatResourceReference reference, {String? id}) {
    final transform = _ref.read(copyDragWatermarkProvider);
    final stripMetadata = _ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final name = FileNameSanitizer.sanitize(
      reference.display['name'] ??
          reference.display['title'] ??
          reference.resourceId,
      fallback: 'resource',
      maxLength: 80,
    );
    var extension = 'png';
    FileFormat format = Formats.png;
    Future<Uint8List> Function() prepare;
    switch (reference.kind) {
      case AgentChatResourceKind.vibeLibraryEntry:
        final owner = _ref.read(vibeLibraryNotifierProvider.notifier);
        final entry = owner.getEntryById(reference.resourceId);
        if (entry == null) {
          throw StateError('Vibe is unavailable: ${reference.resourceId}');
        }
        extension = entry.isBundle ? 'naiv4vibebundle' : 'naiv4vibe';
        format = _portableFormat(extension);
        prepare = () async {
          final entries = await owner.resolveEntriesByIds([
            reference.resourceId,
          ]);
          if (entries.length != 1) {
            throw StateError('Vibe is unavailable: ${reference.resourceId}');
          }
          return VibeExportUtils.portableEntryBytes(entries.single);
        };
      case AgentChatResourceKind.preciseRefLibraryEntry:
        extension = PreciseRefLibraryArchiveService.extension;
        format = _portableFormat(extension);
        final storage = _ref.read(preciseRefLibraryStorageServiceProvider);
        prepare = () async {
          final entry = (await storage.getAllEntries())
              .where((entry) => entry.id == reference.resourceId)
              .single;
          final root = await getTemporaryDirectory();
          final directory = await Directory(
            '${root.path}/card-drag',
          ).createTemp();
          final file = File('${directory.path}/$name.$extension');
          try {
            await PreciseRefLibraryArchiveService(
              storage,
            ).exportToPath(entries: [entry], outputPath: file.path);
            return await file.readAsBytes();
          } finally {
            await directory.delete(recursive: true);
          }
        };
      case AgentChatResourceKind.tagLibraryEntry:
      case AgentChatResourceKind.fixedTag:
        extension = 'txt';
        format = _portableFormat('txt');
        prepare = () async {
          final resolved = await _resolver.resolve(reference);
          final text = resolved?.text;
          if (text == null) {
            throw StateError(
              'Tag resource is unavailable: ${reference.resourceId}',
            );
          }
          return Uint8List.fromList(utf8.encode(text));
        };
      default:
        String? originalExtension;
        if (reference.kind == AgentChatResourceKind.onlineGalleryMedia) {
          final item = _ref
              .read(onlineGalleryNotifierProvider)
              .posts
              .where(
                (item) =>
                    item.sourceId.key == reference.source &&
                    item.sourceWorkId == reference.resourceId,
              )
              .firstOrNull;
          originalExtension = item?.cover.extension ?? item?.fileExt;
        } else {
          originalExtension = 'png';
        }
        final rawExtension = originalExtension
            ?.replaceFirst(RegExp(r'^\.'), '')
            .toLowerCase();
        if (!stripMetadata &&
            transform == null &&
            const {
              'png',
              'jpg',
              'jpeg',
              'webp',
              'gif',
              'bmp',
              'tiff',
            }.contains(rawExtension)) {
          extension = rawExtension!;
          format = imageDragFileFormat('image.$extension');
        }
        final preparationName = '$name.${rawExtension ?? 'image'}';
        prepare = () async {
          final resolved = await _resolver.resolve(reference);
          final bytes = resolved?.bytes;
          if (bytes == null) {
            throw StateError(
              'Image resource is unavailable: ${reference.resourceId}',
            );
          }
          final image =
              await ImageShareSanitizer.prepareForCopyOrDragInBackground(
                bytes,
                fileName: preparationName,
                stripMetadata: stripMetadata,
                transform: transform,
              );
          return image.bytes;
        };
    }
    return CardDragResource(
      id: id ?? reference.resourceId,
      fileName: '$name.$extension',
      reference: reference,
      format: format,
      prepare: prepare,
    );
  }

  static FileFormat _portableFormat(String extension) => SimpleFileFormat(
    uniformTypeIdentifiers: ['public.data'],
    mimeTypes: ['application/x-$extension'],
  );
}
