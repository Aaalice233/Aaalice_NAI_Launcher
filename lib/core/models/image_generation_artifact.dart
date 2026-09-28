import 'dart:typed_data';

class ImageGenerationArtifact {
  const ImageGenerationArtifact({
    required this.displayImageBytes,
    this.transparentPatchBytes,
  });

  final Uint8List displayImageBytes;
  final Uint8List? transparentPatchBytes;
}
