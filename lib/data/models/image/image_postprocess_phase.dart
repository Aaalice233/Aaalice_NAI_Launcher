import 'dart:typed_data';

enum ImagePostprocessPhase { preparing, enhancing, finalizing }

typedef ImagePostprocessor =
    Future<Uint8List> Function(
      Uint8List source,
      Future<void> cancelled,
      void Function(ImagePostprocessPhase) onPhase,
    );
