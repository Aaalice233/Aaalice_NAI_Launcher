import 'dart:convert';

import '../../../data/models/image/image_params.dart';
import '../../constants/model_capabilities.dart';
import '../../enums/precise_ref_type.dart';
import '../../utils/nai_api_utils.dart';
import '../../utils/precise_reference_bucketer.dart';

class DirectorReferencePayloadBuilder {
  const DirectorReferencePayloadBuilder(this.references, this.capabilities);

  final List<PreciseReference> references;
  final PreciseReferenceCapabilities capabilities;

  Future<void> build(Map<String, dynamic> parameters) async {
    if (references.isEmpty) return;

    final prepareImage = capabilities.bucketsImages
        ? PreciseReferenceBucketer.prepare
        : NAIApiUtils.ensurePngFormatAsync;
    final images = <String>[];
    for (final reference in references) {
      final bytes = await prepareImage(reference.image);
      images.add(base64Encode(bytes));
    }

    parameters['director_reference_images'] = images;
    parameters['director_reference_descriptions'] = [
      for (final reference in references)
        {
          'caption': {
            'base_caption': preciseReferenceDescription(
              reference.type,
              preferSameOutfit: reference.preferSameOutfit,
              outfitSupported: capabilities.supportsOutfit,
            ),
            'char_captions': [],
          },
          'legacy_uc': false,
        },
    ];
    parameters['director_reference_information_extracted'] = [
      for (final _ in references) 1,
    ];
    parameters['director_reference_strength_values'] = [
      for (final reference in references) reference.strength,
    ];
    parameters['director_reference_secondary_strength_values'] = [
      for (final reference in references)
        capabilities.supportsFidelity ? 1.0 - reference.fidelity : 0.0,
    ];
  }
}
