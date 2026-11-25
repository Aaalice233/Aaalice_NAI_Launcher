import '../../../data/models/image/image_params.dart';

List<PreciseReference> resolveSendablePreciseReferences(ImageParams params) {
  final capabilities = params.requestPreciseReferenceCapabilities;
  if (!capabilities.supported ||
      params.action == ImageGenerationAction.infill &&
          !capabilities.availableInInpainting) {
    return const [];
  }

  return params.enabledPreciseReferences;
}
