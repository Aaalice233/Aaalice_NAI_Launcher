import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/gallery_drop_reader.dart';

typedef AgentChatExternalImageReader =
    Future<DroppedFileData?> Function(DropItem item);
typedef AgentChatGalleryImageIdLookup = Future<int?> Function(String path);

/// Splits a drop on the Agent panel into application resources, which stay
/// references the Agent can act on, and outside images, which travel inline.
class AgentChatDropReader {
  AgentChatDropReader({
    required AgentChatGalleryImageIdLookup galleryImageIdForPath,
    AgentChatExternalImageReader readExternalImage = readExternalDropImage,
  }) : _galleryImageIdForPath = galleryImageIdForPath,
       _readExternalImage = readExternalImage;

  final AgentChatGalleryImageIdLookup _galleryImageIdForPath;
  final AgentChatExternalImageReader _readExternalImage;

  static final List<DataFormat> _externalImageFormats = [
    Formats.fileUri,
    Formats.uri,
    ...DroppedFileReader.imageFormats,
  ];

  static bool isInternal(DropItem item) =>
      canReadAgentResourceDropItem(item) ||
      galleryInternalDragPathFromLocalData(item.localData) != null;

  static bool accepts(Iterable<DropItem> items) =>
      items.isNotEmpty &&
      items.every(
        (item) =>
            isInternal(item) || _externalImageFormats.any(item.canProvide),
      );

  /// Callers must await this inside the perform callback: the native readers
  /// die with the drop session. One unreadable item never hides the others;
  /// it comes back as an [AgentChatDropFailure].
  Future<List<AgentChatDropPayload>> read(List<DropItem> items) {
    return Future.wait([
      for (final (index, item) in items.indexed) _readSafely(item, index + 1),
    ]);
  }

  Future<AgentChatDropPayload> _readSafely(DropItem item, int position) async {
    try {
      return isInternal(item)
          ? await _readInternal(item, position)
          : await _readExternal(item);
    } catch (error, stackTrace) {
      return AgentChatDropFailure(error, stackTrace);
    }
  }

  Future<AgentChatDropPayload> _readInternal(
    DropItem item,
    int position,
  ) async {
    final reference = await readAgentResourceDropItem(item);
    if (reference != null) return AgentChatDroppedResource(reference);
    final path = galleryInternalDragPathFromLocalData(item.localData);
    final id = path == null ? null : await _galleryImageIdForPath(path);
    if (id == null) {
      throw StateError(
        'Unsupported or unavailable Agent resource at $position',
      );
    }
    return AgentChatDroppedResource(
      AgentChatResourceReference(
        kind: AgentChatResourceKind.localGalleryImage,
        source: 'local_gallery',
        resourceId: id.toString(),
      ),
    );
  }

  Future<AgentChatDropPayload> _readExternal(DropItem item) async {
    final file = await _readExternalImage(item);
    if (file == null || file.bytes.isEmpty) {
      throw const AgentChatUnreadableDropImage();
    }
    return AgentChatDroppedImage(file);
  }
}

Future<DroppedFileData?> readExternalDropImage(DropItem item) async {
  final reader = item.dataReader;
  if (reader == null) return null;
  return DroppedFileReader.read(reader, logTag: 'AgentChatDrop');
}

sealed class AgentChatDropPayload {
  const AgentChatDropPayload();
}

final class AgentChatDroppedResource extends AgentChatDropPayload {
  const AgentChatDroppedResource(this.reference);

  final AgentChatResourceReference reference;
}

final class AgentChatDroppedImage extends AgentChatDropPayload {
  const AgentChatDroppedImage(this.file);

  final DroppedFileData file;
}

final class AgentChatDropFailure extends AgentChatDropPayload {
  const AgentChatDropFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// The source offered neither a readable image file nor an image URL.
final class AgentChatUnreadableDropImage implements Exception {
  const AgentChatUnreadableDropImage();
}
