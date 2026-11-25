import '../../../data/models/image/image_params.dart';
import '../../enums/precise_ref_type.dart';

List<PreciseReference> resolveSendablePreciseReferences(ImageParams params) {
  final capabilities = params.requestPreciseReferenceCapabilities;
  if (!capabilities.supported ||
      params.action == ImageGenerationAction.infill &&
          !capabilities.availableInInpainting) {
    return const [];
  }

  return params.preciseReferences
      .where(
        (reference) =>
            reference.enabled &&
            (capabilities.supportsOutfit ||
                reference.type != PreciseRefType.costume),
      )
      .toList(growable: false);
}
