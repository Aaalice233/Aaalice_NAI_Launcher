import 'dart:typed_data';

import 'image_metadata_container_codec.dart';
import 'image_metadata_parser_service.dart';
import 'metadata_parse_result.dart';

export 'metadata_parse_result.dart';
export 'metadata_text_decoder.dart'
    show
        MetadataParser,
        NovelAiParser,
        WebUiParser,
        ComfyUiParser,
        InvokeAiParser,
        JsonGenericParser;

/// Backward-compatible facade for the metadata parsing subsystem.
class UnifiedMetadataParser {
  static final ImageMetadataParserService _service =
      ImageMetadataParserService();

  static bool isPngHeader(Uint8List bytes) =>
      ImageMetadataContainerCodec.isPngHeader(bytes);

  static Map<String, String> extractPngTextData(Uint8List bytes) =>
      ImageMetadataContainerCodec.extractPngTextData(bytes);

  static MetadataParseResult parseFromFile(
    String filePath, {
    int? maxBytes,
    bool useGradualRead = true,
  }) => _service.parseFromFile(
    filePath,
    maxBytes: maxBytes,
    useGradualRead: useGradualRead,
  );

  static MetadataParseResult parseFromImage(
    Uint8List bytes, {
    String? filePathForLog,
  }) => _service.parseFromImage(bytes, filePathForLog: filePathForLog);

  static MetadataParseResult parseFromPng(
    Uint8List bytes, {
    String? filePathForLog,
  }) => _service.parseFromPng(bytes, filePathForLog: filePathForLog);

  /// Null means the answer needs the stealth pixel decode; run [parseFromImage]
  /// off the UI isolate in that case.
  static MetadataParseResult? parseFromImageWithoutPixelDecode(
    Uint8List bytes,
  ) => _service.parseFromImageWithoutPixelDecode(bytes);

  static MetadataParseResult? parseFromPngWithoutPixelDecode(Uint8List bytes) =>
      _service.parseFromPngWithoutPixelDecode(bytes);

  static MetadataParseResult parseFromWebp(
    Uint8List bytes, {
    String? filePathForLog,
  }) => _service.parseFromWebp(bytes, filePathForLog: filePathForLog);

  static MetadataParseResult parseFromTextData(Map<String, String> textData) =>
      _service.parseFromTextData(textData);

  static MetadataParseResult parseStealthFromImageBytes(Uint8List bytes) =>
      _service.parseStealthFromImageBytes(bytes);

  static Future<Uint8List> embedMetadata(
    Uint8List imageBytes,
    String metadataJson, {
    bool useStealth = false,
  }) => ImageMetadataContainerCodec.embedMetadata(
    imageBytes,
    metadataJson,
    useStealth: useStealth,
  );

  static Uint8List embedTextChunkOnly(
    Uint8List originalPng,
    String keyword,
    String text,
  ) => ImageMetadataContainerCodec.embedTextChunkOnly(
    originalPng,
    keyword,
    text,
  );

  static Uint8List embedTextChunks(
    Uint8List originalPng,
    Map<String, String> replacements,
  ) => ImageMetadataContainerCodec.embedTextChunks(originalPng, replacements);

  static Uint8List copySupportedMetadata({
    required Uint8List source,
    required Uint8List targetPng,
    bool orientationApplied = false,
  }) => ImageMetadataContainerCodec.copySupportedMetadata(
    source: source,
    targetPng: targetPng,
    orientationApplied: orientationApplied,
  );

  static ParseStatistics get statistics => _service.statistics;

  static void resetStatistics() => _service.resetStatistics();
}
