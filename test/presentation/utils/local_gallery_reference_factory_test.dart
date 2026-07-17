import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/utils/local_gallery_reference_factory.dart';

void main() {
  test(
    'creates exactly one enabled raw style reference with agreed defaults',
    () {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);

      final reference = LocalGalleryReferenceFactory.createRawStyleReference(
        fileName: 'embedded-vibe.png',
        imageBytes: imageBytes,
      );

      expect(reference.displayName, 'embedded-vibe.png');
      expect(reference.vibeEncoding, isEmpty);
      expect(reference.rawImageData, same(imageBytes));
      expect(reference.thumbnail, same(imageBytes));
      expect(reference.sourceType, VibeSourceType.rawImage);
      expect(reference.strength, 0.6);
      expect(reference.infoExtracted, 0.7);
      expect(reference.enabled, isTrue);
    },
  );
}
