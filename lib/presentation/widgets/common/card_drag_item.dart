import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/drag_export_file_store.dart';
import '../../utils/card_drag_format.dart';
import 'card_drag_resource.dart';
import 'card_on_demand_file.dart';
import 'card_virtual_file.dart';

/// Whether a card must generate file contents because no ready file exists.
bool cardDragNeedsExport(CardDragResource resource, File? readyFile) =>
    readyFile == null && resource.format != null && resource.prepare != null;

/// One native drag item: in-app payloads plus a file for other applications.
///
/// A [readyFile] is offered by path; otherwise [bytes] is exported in the way
/// the platform's drag protocol tolerates.
Future<DragItem> buildCardDragItem(
  CardDragResource resource, {
  required File? readyFile,
  required Future<Uint8List> Function()? bytes,
  required void Function(Object, StackTrace) reportFailure,
  required DragFileExportMode exportMode,
  DragExportFileStore? store,
}) async {
  final item = DragItem(
    suggestedName: resource.fileName,
    localData: resource.payload,
  );
  item.add(cardDragFormat(jsonEncode(resource.payload)));
  final reference = resource.reference;
  if (reference != null) addAgentResourceDragPayload(item, reference);
  if (readyFile != null) {
    item.add(Formats.fileUri(readyFile.uri));
    return item;
  }
  final format = resource.format;
  if (format == null || bytes == null) return item;
  final files = store ?? DragExportFileStore.instance;
  switch (exportMode) {
    case DragFileExportMode.virtualFile:
      addCardVirtualFile(
        item,
        format: format,
        prepare: bytes,
        reportFailure: reportFailure,
      );
    case DragFileExportMode.onDemandFile:
      addCardOnDemandFile(
        item,
        export: () async => files.write(resource.fileName, await bytes()),
        reportFailure: reportFailure,
      );
    case DragFileExportMode.preparedFile:
      final contents = await bytes();
      item.add(format(contents));
      item.add(
        Formats.fileUri((await files.write(resource.fileName, contents)).uri),
      );
  }
  return item;
}
