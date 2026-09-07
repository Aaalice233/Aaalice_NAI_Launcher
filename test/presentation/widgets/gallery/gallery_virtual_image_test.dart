import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_virtual_image.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_native_extensions/raw_clipboard.dart' as raw;

class _Item extends DragItem {
  @override
  bool get virtualFileSupported => true;
}

class _Progress extends raw.WriteProgress {
  final cancelled = ChangeNotifier();
  @override
  Listenable get onCancel => cancelled;
  @override
  void updateProgress(double fraction) {}
}

void main() {
  test(
    'drag advertises only an async file before preparation completes',
    () async {
      final pending = Completer<SanitizedShareImage>();
      final item = _Item();
      addGalleryVirtualImage(item, pending.future);
      final representations = (await item.data.single).representations;
      final virtual =
          representations.single as raw.DataRepresentationVirtualFile;
      expect(virtual.storageSuggestion, raw.VirtualFileStorage.temporaryFile);
      final progress = _Progress();
      addTearDown(progress.cancelled.dispose);
      final contents = StreamController<Object?>();
      final delivered = contents.stream.toList();
      var sinkCreated = false;
      virtual.virtualFileProvider(({required fileSize}) {
        sinkCreated = true;
        expect(fileSize, 3);
        return contents.sink;
      }, progress);
      expect(sinkCreated, isFalse);
      final bytes = Uint8List.fromList([1, 2, 3]);
      pending.complete(
        SanitizedShareImage(
          bytes: bytes,
          fileName: 'image.png',
          mimeType: 'image/png',
        ),
      );
      expect(await delivered, [bytes]);
    },
  );

  test(
    'cancelled receiver is not written after preparation finishes',
    () async {
      final pending = Completer<SanitizedShareImage>();
      final item = _Item();
      addGalleryVirtualImage(item, pending.future);
      final virtual =
          (await item.data.single).representations.single
              as raw.DataRepresentationVirtualFile;
      final progress = _Progress();
      addTearDown(progress.cancelled.dispose);
      virtual.virtualFileProvider(
        ({required fileSize}) =>
            throw StateError('Cancelled receiver requested a sink'),
        progress,
      );
      progress.cancelled.notifyListeners();
      pending.complete(
        SanitizedShareImage(
          bytes: Uint8List(1),
          fileName: 'image.png',
          mimeType: 'image/png',
        ),
      );
      await pending.future;
      await Future<void>.value();
    },
  );

  test(
    'preparation failure reaches the receiver instead of original pixels',
    () async {
      final pending = Completer<SanitizedShareImage>();
      final item = _Item();
      addGalleryVirtualImage(item, pending.future);
      final virtual =
          (await item.data.single).representations.single
              as raw.DataRepresentationVirtualFile;
      final progress = _Progress();
      addTearDown(progress.cancelled.dispose);
      final contents = StreamController<Object?>();
      final failure = expectLater(
        contents.stream,
        emitsError(isA<ImageSanitizeException>()),
      );
      virtual.virtualFileProvider(({required fileSize}) {
        expect(fileSize, 0);
        return contents.sink;
      }, progress);
      pending.completeError(const ImageSanitizeException('Invalid source PNG'));
      await failure;
    },
  );
}
