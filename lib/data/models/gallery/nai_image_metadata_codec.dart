import 'nai_image_metadata.dart';
import 'nai_image_metadata_raw_decoder.dart';

/// Compatibility facade for callers that decode NovelAI comment metadata.
///
/// Raw decoding lives in [NaiImageMetadataRawDecoder], which has no dependency
/// on the persisted entity. This facade keeps the existing public API without
/// creating a model-to-codec import cycle.
class NaiImageMetadataCodec {
  const NaiImageMetadataCodec();

  static NaiImageMetadata decode(
    Map<String, dynamic> json, {
    String? rawJson,
  }) => NaiImageMetadata.fromNaiComment(json, rawJson: rawJson);

  NaiImageMetadata upgradeFromRawJsonIfNeeded(NaiImageMetadata metadata) =>
      metadata.upgradeFromRawJsonIfNeeded();

  static String? modelIdFromSource(String? source) =>
      NaiImageMetadataRawDecoder.modelIdFromSource(source);
}
