import 'dart:typed_data';

import '../../data/models/vibe/vibe_reference.dart';

class LocalGalleryReferenceFactory {
  const LocalGalleryReferenceFactory._();

  static VibeReference createRawStyleReference({
    required String fileName,
    required Uint8List imageBytes,
  }) {
    return VibeReference(
      displayName: fileName,
      vibeEncoding: '',
      thumbnail: imageBytes,
      rawImageData: imageBytes,
      sourceType: VibeSourceType.rawImage,
    );
  }
}
