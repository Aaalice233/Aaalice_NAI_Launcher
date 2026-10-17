import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/exif_container.dart';
import '../../../core/utils/portable_logger.dart';
import 'image_metadata_container_codec.dart';
import 'metadata_file_repository.dart';
import 'metadata_parse_result.dart';
import 'metadata_text_decoder.dart';
import 'webp_exif_metadata_extractor.dart';

/// Coordinates container decoding, text interpretation, files and stats.
class ImageMetadataParserService {
  ImageMetadataParserService({
    MetadataTextDecoder? textDecoder,
    MetadataFileRepository? fileRepository,
  }) : _textDecoder = textDecoder ?? MetadataTextDecoder(),
       _fileRepository = fileRepository ?? const MetadataFileRepository();

  static const String _tag = 'UnifiedMetadataParser';
  static const String _webpExifParser = 'WebP EXIF';
  static const String _stealthParser = 'NovelAI stealth_pngcomp';

  final MetadataTextDecoder _textDecoder;
  final MetadataFileRepository _fileRepository;
  final ParseStatistics statistics = ParseStatistics();

  MetadataParseResult parseFromFile(
    String filePath, {
    int? maxBytes,
    bool useGradualRead = true,
  }) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return MetadataParseResult.failed(
          const [],
          'File not found: $filePath',
          parseTime: stopwatch.elapsed,
        );
      }
      final fileSize = file.lengthSync();
      if (fileSize < 8) {
        return MetadataParseResult.failed(
          const [],
          'File too small: $fileSize bytes',
          parseTime: stopwatch.elapsed,
        );
      }

      final result = _fileRepository.parse(
        filePath,
        maxBytes: maxBytes,
        useGradualRead: useGradualRead,
        statistics: statistics,
        parseBytes: (bytes, path) =>
            parseFromImage(bytes, filePathForLog: path),
      );
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    } on FileSystemException catch (error) {
      return MetadataParseResult.failed(
        const [],
        'File system error: ${error.message}',
        parseTime: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      PortableLogger.e('Unexpected error: $error', error, stackTrace, _tag);
      return MetadataParseResult.failed(
        const [],
        'Unexpected error: $error',
        parseTime: stopwatch.elapsed,
      );
    }
  }

  MetadataParseResult parseFromImage(
    Uint8List bytes, {
    String? filePathForLog,
  }) {
    if (ImageMetadataContainerCodec.isPngHeader(bytes)) {
      return parseFromPng(bytes, filePathForLog: filePathForLog);
    }
    if (ExifContainer.isWebp(bytes)) {
      return parseFromWebp(bytes, filePathForLog: filePathForLog);
    }

    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
    final result = MetadataParseResult.failed(
      const [],
      'Unsupported image container, ${fileInfo}bytes length=${bytes.length}',
      parseTime: stopwatch.elapsed,
      bytesRead: bytes.length,
    );
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  MetadataParseResult parseFromPng(Uint8List bytes, {String? filePathForLog}) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final result = _parsePng(
      bytes,
      stopwatch,
      filePathForLog: filePathForLog,
      includeStealth: true,
    )!;
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  /// Containers whose [parseFromImage] result already covers the stealth
  /// payload, so callers need no separate pixel decode for them.
  static bool readsStealthPayload(Uint8List bytes) =>
      ImageMetadataContainerCodec.isPngHeader(bytes) ||
      ExifContainer.isWebp(bytes);

  /// Returns the same result as [parseFromImage] without any pixel decode, or
  /// null when that result depends on the stealth payload in the pixels.
  MetadataParseResult? parseFromImageWithoutPixelDecode(Uint8List bytes) {
    if (ImageMetadataContainerCodec.isPngHeader(bytes)) {
      return parseFromPngWithoutPixelDecode(bytes);
    }
    if (ExifContainer.isWebp(bytes)) {
      return parseFromWebpWithoutPixelDecode(bytes);
    }
    return parseFromImage(bytes);
  }

  /// PNG-only counterpart of [parseFromImageWithoutPixelDecode].
  MetadataParseResult? parseFromPngWithoutPixelDecode(Uint8List bytes) {
    final stopwatch = Stopwatch()..start();
    return _recordDeferrable(
      _parsePng(bytes, stopwatch, includeStealth: false),
      stopwatch,
    );
  }

  /// WebP-only counterpart of [parseFromImageWithoutPixelDecode].
  MetadataParseResult? parseFromWebpWithoutPixelDecode(Uint8List bytes) {
    final stopwatch = Stopwatch()..start();
    return _recordDeferrable(
      _parseWebp(bytes, stopwatch, includeStealth: false),
      stopwatch,
    );
  }

  /// A deferred (null) result is recorded later by the full parse instead.
  MetadataParseResult? _recordDeferrable(
    MetadataParseResult? result,
    Stopwatch stopwatch,
  ) {
    if (result != null) {
      statistics.totalAttempts++;
      _updateStatistics(result, stopwatch.elapsed);
    }
    return result;
  }

  MetadataParseResult? _parsePng(
    Uint8List bytes,
    Stopwatch stopwatch, {
    String? filePathForLog,
    required bool includeStealth,
  }) {
    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
    try {
      if (!ImageMetadataContainerCodec.isPngHeader(bytes)) {
        return MetadataParseResult.failed(
          const [],
          'Not a valid PNG file header, ${fileInfo}bytes length=${bytes.length}',
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
      }

      final info = img.PngDecoder().startDecode(bytes);
      if (info == null) {
        return MetadataParseResult.failed(
          const [],
          bytes.length < 1024 * 1024
              ? 'Failed to decode PNG (incomplete data?)'
              : 'Failed to decode PNG',
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
      }

      final pngInfo = info as img.PngInfo;
      final result = _parseTextData(
        ImageMetadataContainerCodec.extractPngTextData(
          bytes,
          decoderTextData: pngInfo.textData,
        ),
      );
      if (result.success) return result;
      if (!includeStealth) return null;
      return _preferStealth(bytes, stopwatch, fallback: result);
    } catch (error, stackTrace) {
      final message =
          'Error parsing metadata from PNG (${fileInfo}bytes=${bytes.length}): $error';
      PortableLogger.e(message, error, stackTrace, _tag);
      return MetadataParseResult.failed(
        const [],
        message,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }
  }

  MetadataParseResult parseFromWebp(Uint8List bytes, {String? filePathForLog}) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final result = _parseWebp(
      bytes,
      stopwatch,
      filePathForLog: filePathForLog,
      includeStealth: true,
    )!;
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  /// Follows NovelAI's web reader: EXIF UserComment first, then the stealth
  /// payload. A damaged container stops before the pixel decode.
  MetadataParseResult? _parseWebp(
    Uint8List bytes,
    Stopwatch stopwatch, {
    String? filePathForLog,
    required bool includeStealth,
  }) {
    try {
      final extraction = WebpExifMetadataExtractor.extract(bytes);
      final result = _parseWebpExif(extraction, bytes, stopwatch);
      if (result.success || extraction.containerDamaged) return result;
      if (!includeStealth) return null;
      return _preferStealth(bytes, stopwatch, fallback: result);
    } catch (error, stackTrace) {
      final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
      final message =
          'Error parsing metadata from WebP (${fileInfo}bytes=${bytes.length}): $error';
      PortableLogger.e(message, error, stackTrace, _tag);
      return MetadataParseResult.failed(
        const [_webpExifParser],
        message,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }
  }

  MetadataParseResult _parseWebpExif(
    WebpExifMetadataExtraction extraction,
    Uint8List bytes,
    Stopwatch stopwatch,
  ) {
    if (extraction.errorMessage != null || !extraction.hasMetadata) {
      return MetadataParseResult.failed(
        const [_webpExifParser],
        extraction.errorMessage ?? 'No EXIF UserComment metadata found in WebP',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }

    final parsed = _parseTextData(extraction.textData);
    return parsed.success && parsed.metadata != null
        ? MetadataParseResult.success(
            parsed.metadata!,
            '${parsed.sourceFormat} $_webpExifParser',
            extraction.textData['Comment']!,
            [_webpExifParser, ...parsed.triedParsers],
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
          )
        : MetadataParseResult.failed(
            [_webpExifParser, ...parsed.triedParsers],
            parsed.errorMessage ?? 'Invalid WebP EXIF metadata',
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
          );
  }

  MetadataParseResult parseFromTextData(Map<String, String> textData) {
    final result = _parseTextData(textData);
    _updateStatistics(result, result.parseTime ?? Duration.zero);
    return result;
  }

  MetadataParseResult _parseTextData(Map<String, String> textData) {
    final result = _textDecoder.decode(textData, statistics: statistics);
    for (final parserName in result.triedParsers) {
      if (parserName == result.sourceFormat) {
        statistics.parserSuccessCounts[parserName] =
            (statistics.parserSuccessCounts[parserName] ?? 0) + 1;
      }
    }
    return result;
  }

  MetadataParseResult parseStealthFromImageBytes(Uint8List bytes) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final result = _parseStealth(bytes, stopwatch);
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  /// The stealth result when it yields metadata, otherwise [fallback] so the
  /// container-level diagnosis is what callers see.
  MetadataParseResult _preferStealth(
    Uint8List bytes,
    Stopwatch stopwatch, {
    required MetadataParseResult fallback,
  }) {
    final stealth = _parseStealth(
      bytes,
      stopwatch,
      precedingParsers: fallback.triedParsers,
    );
    return stealth.success ? stealth : fallback;
  }

  MetadataParseResult _parseStealth(
    Uint8List bytes,
    Stopwatch stopwatch, {
    List<String> precedingParsers = const [],
  }) {
    final stealthText = ImageMetadataContainerCodec.extractStealthMetadataText(
      bytes,
    );
    if (stealthText == null) {
      return MetadataParseResult.failed(
        [...precedingParsers, _stealthParser],
        'No NovelAI stealth_pngcomp metadata found',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }

    final parsed = _parseTextData({'Comment': stealthText});
    final triedParsers = [
      ...precedingParsers,
      ...parsed.triedParsers,
      _stealthParser,
    ];
    if (!parsed.success || parsed.metadata == null) {
      return MetadataParseResult.failed(
        triedParsers,
        parsed.errorMessage ?? 'Failed to parse NovelAI stealth metadata',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }
    return MetadataParseResult.success(
      parsed.metadata!,
      _stealthParser,
      stealthText,
      triedParsers,
      parseTime: stopwatch.elapsed,
      bytesRead: bytes.length,
    );
  }

  void resetStatistics() => statistics.reset();

  void _updateStatistics(MetadataParseResult result, Duration elapsed) {
    statistics.totalParseTime += elapsed;
    if (result.success) {
      statistics.successfulParses++;
    } else {
      statistics.failedParses++;
    }
  }
}
