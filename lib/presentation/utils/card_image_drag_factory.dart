import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../core/utils/image_share_sanitizer.dart';
import '../widgets/common/card_drag_resource.dart';

CardDragResource imageCardDragResource({
  required String id,
  required String fileName,
  required bool stripMetadata,
  ShareImageTransform? transform,
  Uint8List? bytes,
  String? filePath,
  Object? localData,
  AgentChatResourceReference? reference,
}) {
  final extension = p.extension(fileName).toLowerCase();
  final outputName =
      stripMetadata ||
          transform != null ||
          !const {
            '.png',
            '.jpg',
            '.jpeg',
            '.webp',
            '.gif',
            '.bmp',
            '.tiff',
          }.contains(extension)
      ? p.setExtension(fileName, '.png')
      : fileName;
  return CardDragResource(
    id: id,
    fileName: outputName,
    reference: reference,
    localData: localData,
    format: imageDragFileFormat(outputName),
    prepare: () async {
      final original = filePath != null && filePath.isNotEmpty
          ? await File(filePath).readAsBytes()
          : bytes;
      if (original == null || original.isEmpty) {
        throw StateError('Original image is unavailable: $id');
      }
      final image = await ImageShareSanitizer.prepareForCopyOrDragInBackground(
        original,
        fileName: fileName,
        stripMetadata: stripMetadata,
        transform: transform,
      );
      return image.bytes;
    },
  );
}

FileFormat imageDragFileFormat(String name) =>
    switch (p.extension(name).toLowerCase()) {
      '.jpg' || '.jpeg' => Formats.jpeg,
      '.webp' => Formats.webp,
      '.gif' => Formats.gif,
      '.bmp' => Formats.bmp,
      '.tiff' => Formats.tiff,
      _ => Formats.png,
    };
