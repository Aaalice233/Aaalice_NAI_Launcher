import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart' show VirtualFileStorage;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Keeps preparation lazy and reports failures to the native receiver.
void addCardVirtualFile(
  DragItem item, {
  required FileFormat format,
  required Future<Uint8List> Function() prepare,
  required void Function(Object, StackTrace) reportFailure,
}) {
  item.addVirtualFile(
    format: format,
    storageSuggestion: VirtualFileStorage.temporaryFile,
    provider: (sinkProvider, progress) async {
      var cancelled = false;
      void cancel() => cancelled = true;
      progress.onCancel.addListener(cancel);
      EventSink? sink;
      try {
        final bytes = await prepare();
        if (cancelled) return;
        sink = sinkProvider(fileSize: bytes.length);
        sink.add(bytes);
      } catch (error, stack) {
        reportFailure(error, stack);
        if (!cancelled) {
          sink ??= sinkProvider(fileSize: 0);
          sink.addError(error, stack);
        }
      } finally {
        sink?.close();
        progress.onCancel.removeListener(cancel);
      }
    },
  );
}
