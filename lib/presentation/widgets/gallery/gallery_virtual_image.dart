import 'dart:async';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_clipboard/super_clipboard.dart'
    show VirtualFileEventSinkProvider, VirtualFileStorage, WriteProgress;

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';

/// Windows CF_HDROP and ordinary lazy image formats block IDataObject.GetData.
/// Virtual files use the plugin's asynchronous file-content stream instead.
void addGalleryVirtualImage(
  DragItem item,
  Future<SanitizedShareImage> preparation,
) {
  // Observe eager preparation even when the drag is cancelled without a reader.
  // The original future still propagates failure to every actual receiver.
  unawaited(
    preparation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        AppLogger.e(
          'Gallery image preparation failed',
          error,
          stack,
          'GalleryDrag',
        );
      },
    ),
  );
  item.addVirtualFile(
    format: Formats.png,
    storageSuggestion: VirtualFileStorage.temporaryFile,
    provider: (sinkProvider, progress) {
      unawaited(_writeImage(preparation, sinkProvider, progress));
    },
  );
}

Future<void> _writeImage(
  Future<SanitizedShareImage> preparation,
  VirtualFileEventSinkProvider sinkProvider,
  WriteProgress progress,
) async {
  var cancelled = false;
  void cancel() => cancelled = true;
  progress.onCancel.addListener(cancel);
  EventSink? sink;
  try {
    final image = await preparation;
    if (cancelled) return;
    sink = sinkProvider(fileSize: image.bytes.length);
    sink.add(image.bytes);
    AppLogger.d(
      'Virtual image delivered: ${image.bytes.length} bytes',
      'GalleryDrag',
    );
  } catch (error, stack) {
    if (!cancelled) {
      sink ??= sinkProvider(fileSize: 0);
      sink.addError(error, stack);
    }
  } finally {
    sink?.close();
    progress.onCancel.removeListener(cancel);
  }
}
