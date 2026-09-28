import 'dart:typed_data';

import '../../../data/models/image/image_params.dart';
import '../../../data/models/vibe/vibe_reference.dart';

typedef Img2ImgPanelViewData = ({
  Uint8List? sourceImage,
  Uint8List? maskImage,
  double strength,
  double noise,
  double inpaintStrength,
});

Img2ImgPanelViewData selectImg2ImgPanelViewData(ImageParams params) => (
      sourceImage: params.sourceImage,
      maskImage: params.maskImage,
      strength: params.strength,
      noise: params.noise,
      inpaintStrength: params.inpaintStrength,
    );

typedef VibePanelViewData = ({
  List<VibeReference> vibes,
  bool normalizeVibeStrength,
});

VibePanelViewData selectVibePanelViewData(ImageParams params) => (
      vibes: params.vibeReferencesV4,
      normalizeVibeStrength: params.normalizeVibeStrength,
    );

typedef PreviewDimensionsViewData = ({
  int width,
  int height,
});

PreviewDimensionsViewData selectPreviewDimensionsViewData(ImageParams params) =>
    (
      width: params.width,
      height: params.height,
    );

typedef CharacterPanelViewData = ({
  bool isV4Model,
  List<CharacterPrompt> characters,
});

CharacterPanelViewData selectCharacterPanelViewData(ImageParams params) => (
      isV4Model: params.isV4Model,
      characters: params.characters,
    );
