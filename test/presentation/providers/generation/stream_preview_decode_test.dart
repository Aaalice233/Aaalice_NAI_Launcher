import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/generation/stream_preview_decode.dart';

import '../../../helpers/controlled_preview_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledPreviewImages images;
  setUp(() {
    images = ControlledPreviewImages();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
  tearDown(() {
    images.dispose();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets(
    'production resolver synchronously reuses the same MemoryImage key',
    (tester) async {
      final bytes = Uint8List.fromList([1]);
      images.resolve(bytes);
      final image = images.complete(0);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final resolve = container.read(streamPreviewImageResolverProvider);
      final decoded = StreamPreviewDecode(
        StreamPreviewFrame(bytes: bytes),
        resolve,
      );
      await decoded.ready;
      final status = PaintingBinding.instance.imageCache.statusForKey(
        MemoryImage(bytes),
      );
      expect(status.pending, isFalse);
      expect(status.live, isTrue);
      var synchronous = false;
      final stream = resolve(bytes);
      final listener = ImageStreamListener((info, sync) {
        synchronous = sync;
        expect(info.image.isCloneOf(image), isTrue);
        info.dispose();
      });
      stream.addListener(listener);
      expect(synchronous, isTrue);
      stream.removeListener(listener);
      decoded.dispose();
    },
  );

  testWidgets('repeated image callbacks settle decoding only once', (
    tester,
  ) async {
    final decoded = StreamPreviewDecode(
      StreamPreviewFrame(bytes: Uint8List.fromList([1])),
      images.resolve,
    );
    var completed = 0;
    final ready = decoded.ready.then((_) => completed++);
    images.complete(0);
    images.complete(0);
    await ready;
    expect(completed, 1);
    decoded.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid placement resolves only the visible preview', (
    tester,
  ) async {
    final decoded = StreamPreviewDecode(
      StreamPreviewFrame(
        bytes: Uint8List.fromList([1]),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: Uint8List.fromList([2]),
          maskImage: Uint8List.fromList([3]),
          xPercent: 0,
          yPercent: 0,
          widthPercent: 0,
          heightPercent: 1,
        ),
      ),
      images.resolve,
    );
    expect(images.requests, hasLength(1));
    images.complete(0);
    await decoded.ready;
    decoded.dispose();
  });

  testWidgets('focused preview without mask waits for its source', (
    tester,
  ) async {
    final decoded = StreamPreviewDecode(
      StreamPreviewFrame(
        bytes: Uint8List.fromList([1]),
        placement: FocusedStreamPreviewPlacement(
          sourceImage: Uint8List.fromList([2]),
          xPercent: 0,
          yPercent: 0,
          widthPercent: 1,
          heightPercent: 1,
        ),
      ),
      images.resolve,
    );
    expect(images.requests, hasLength(2));
    var ready = false;
    final completion = decoded.ready.then((_) => ready = true);
    images.complete(0);
    await tester.idle();
    expect(ready, isFalse);
    images.fail(1);
    await completion;
    expect(ready, isTrue);
    decoded.dispose();
  });
}
