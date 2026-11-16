import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

class ControlledPreviewImages {
  final requests = <Uint8List>[];
  final _completers = <Uint8List, _Completer>{};
  final _images = <ui.Image>[];

  ImageStream resolve(Uint8List bytes) {
    requests.add(bytes);
    final completer = PaintingBinding.instance.imageCache.putIfAbsent(
      MemoryImage(bytes),
      () => _completers.putIfAbsent(bytes, _Completer.new),
    )!;
    return ImageStream()..setCompleter(completer);
  }

  ui.Image complete(int index) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(8 + index, 8 + index);
    picture.dispose();
    _images.add(image);
    _completers[requests[index]]!.publish(image.clone());
    return image;
  }

  void fail(int index) {
    _completers[requests[index]]!.reportError(
      exception: StateError('invalid preview'),
      stack: StackTrace.current,
      silent: true,
    );
  }

  void dispose() {
    for (final image in _images) {
      image.dispose();
    }
  }
}

class _Completer extends ImageStreamCompleter {
  void publish(ui.Image image) => setImage(ImageInfo(image: image));
}

ImageStream resolvedPreviewImage(Uint8List bytes) {
  final picture = ui.PictureRecorder();
  ui.Canvas(picture).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final drawing = picture.endRecording();
  final image = drawing.toImageSync(1, 1);
  drawing.dispose();
  return ImageStream()..setCompleter(_Completer()..publish(image));
}
