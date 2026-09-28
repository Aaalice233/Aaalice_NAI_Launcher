import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../widgets/common/app_toast.dart';
import 'card_drag_format.dart';

final galleryDropFormats = <DataFormat>[cardDragFormat, Formats.fileUri];

String? galleryInternalDragPathFromLocalData(Object? localData) {
  if (localData is! Map || localData['source'] != 'gallery_internal') {
    return null;
  }
  final path = localData['path'];
  return path is String && path.isNotEmpty ? path : null;
}

bool canAcceptGalleryDrop(
  Iterable<DropItem> items, {
  bool internalOnly = false,
}) =>
    items.isNotEmpty &&
    items.every((item) {
      if (galleryInternalDragPathFromLocalData(item.localData) != null) {
        return true;
      }
      final local = item.localData;
      if (local is Map && local.containsKey('cardDragId')) return false;
      return !internalOnly && item.canProvide(Formats.fileUri);
    });

Future<List<String>> readGalleryDropPaths(
  Iterable<DropItem> items, {
  bool internalOnly = false,
}) async {
  final snapshot = List<DropItem>.unmodifiable(items);
  if (!canAcceptGalleryDrop(snapshot, internalOnly: internalOnly)) {
    throw StateError(
      'This target requires a complete set of local image paths',
    );
  }
  return Future.wait([
    for (final item in snapshot)
      if (galleryInternalDragPathFromLocalData(item.localData)
          case final String path)
        Future.value(path)
      else
        _readFilePath(item),
  ]);
}

Future<String> _readFilePath(DropItem item) async {
  final reader = item.dataReader;
  if (reader == null) {
    throw StateError('The dropped file reader is unavailable');
  }
  final completer = Completer<Uri?>();
  final progress = reader.getValue(
    Formats.fileUri,
    completer.complete,
    onError: completer.completeError,
  );
  if (progress == null) throw StateError('The dropped file URI is unavailable');
  final uri = await completer.future.timeout(const Duration(seconds: 5));
  if (uri == null || uri.scheme != 'file') {
    throw StateError('A local file URI is required');
  }
  return uri.toFilePath();
}

Future<void> performGalleryDrop(
  BuildContext context,
  PerformDropEvent event,
  Future<void> Function(List<String>) operation, {
  bool internalOnly = false,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final label = context.l10n.common_error;
  void report(Object error, StackTrace stack) {
    AppLogger.e('Gallery drop failed', error, stack, 'CardDrag');
    AppToast.errorOnOverlay(overlay, '$label: $error');
  }

  try {
    final paths = await readGalleryDropPaths(
      event.session.items,
      internalOnly: internalOnly,
    );
    // Moving may require asset-protection confirmation, outside the OS drag loop.
    unawaited(
      Future<void>(() async {
        try {
          await operation(paths);
        } catch (error, stack) {
          report(error, stack);
        }
      }),
    );
  } catch (error, stack) {
    report(error, stack);
  }
}
