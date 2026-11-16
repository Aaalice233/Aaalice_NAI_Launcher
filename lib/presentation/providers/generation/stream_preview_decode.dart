import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/image/image_stream_chunk.dart';

typedef StreamPreviewImageResolver = ImageStream Function(Uint8List bytes);

final streamPreviewImageResolverProvider = Provider<StreamPreviewImageResolver>(
  (ref) =>
      (bytes) => MemoryImage(bytes).resolve(ImageConfiguration.empty),
);

class StreamPreviewDecode {
  StreamPreviewDecode(
    StreamPreviewFrame frame,
    StreamPreviewImageResolver resolve,
  ) {
    final placement = frame.placement;
    _images.add(_DecodedImage(resolve(frame.bytes)));
    if (placement != null && placement.isValid) {
      _images.add(_DecodedImage(resolve(placement.sourceImage)));
      final mask = placement.maskImage;
      if (mask != null) _images.add(_DecodedImage(resolve(mask)));
    }
  }

  final _images = <_DecodedImage>[];

  Future<void> get ready => Future.wait(_images.map((image) => image.ready));

  void dispose() {
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }
}

class _DecodedImage {
  _DecodedImage(this._stream) {
    _listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!_ready.isCompleted) _ready.complete();
      },
      // 坏帧仍发布进度和原字节，由持帧层继续显示上一帧。
      onError: (Object error, StackTrace? stack) {
        if (!_ready.isCompleted) _ready.complete();
      },
    );
    _stream.addListener(_listener);
  }

  final ImageStream _stream;
  final _ready = Completer<void>();
  late final ImageStreamListener _listener;

  Future<void> get ready => _ready.future;

  void dispose() {
    _stream.removeListener(_listener);
    if (!_ready.isCompleted) _ready.complete();
  }
}
