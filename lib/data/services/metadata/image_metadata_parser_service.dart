import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/exif_container.dart';
import '../../../core/utils/portable_logger.dart';
import 'exif_metadata_extractor.dart';
import 'image_metadata_container_codec.dart';
import 'metadata_error_summary.dart';
import 'metadata_file_repository.dart';
import 'metadata_parse_result.dart';
import 'metadata_text_decoder.dart';

/// Coordinates container decoding, text interpretation, files and stats.
class ImageMetadataParserService {
  ImageMetadataParserService({
    MetadataTextDecoder? textDecoder,
    MetadataFileRepository? fileRepository,
  }) : _textDecoder = textDecoder ?? MetadataTextDecoder(),
       _fileRepository = fileRepository ?? const MetadataFileRepository();

  static const String _tag = 'UnifiedMetadataParser';
  static const String _pngExifParser = 'PNG EXIF';
  static const String _webpExifParser = 'WebP EXIF';
  static const String _jpegExifParser = 'JPEG EXIF';
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
      final summary = metadataErrorSummary(error);
      PortableLogger.e('Unexpected error: $summary', null, stackTrace, _tag);
      return MetadataParseResult.failed(
        const [],
        'Unexpected error: $summary',
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
    if (ExifContainer.isJpeg(bytes)) {
      return parseFromJpeg(bytes, filePathForLog: filePathForLog);
    }

    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
    final result = MetadataParseResult.failed(
      const [],
      'Unsupported image container, ${fileInfo}bytes length=${bytes.length}',
      parseTime: stopwatch.elapsed,
      bytesRead: bytes.length,
      prefixVerdict: MetadataPrefixVerdict.conclusive,
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

  /// Containers whose [parseFromImage] result already settles the stealth
  /// payload, so callers need no separate pixel decode for them. JPEG has no
  /// alpha channel and therefore never carries one.
  static bool readsStealthPayload(Uint8List bytes) =>
      ImageMetadataContainerCodec.isPngHeader(bytes) ||
      ExifContainer.isWebp(bytes) ||
      ExifContainer.isJpeg(bytes);

  /// Returns the same result as [parseFromImage] without any pixel decode, or
  /// null when that result depends on the stealth payload in the pixels.
  MetadataParseResult? parseFromImageWithoutPixelDecode(Uint8List bytes) {
    if (ImageMetadataContainerCodec.isPngHeader(bytes)) {
      return parseFromPngWithoutPixelDecode(bytes);
    }
    if (ExifContainer.isWebp(bytes)) {
      return _parseFromWebpWithoutPixelDecode(bytes);
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

  MetadataParseResult? _parseFromWebpWithoutPixelDecode(Uint8List bytes) {
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

  /// Text chunks, then the eXIf UserComment, then the stealth payload. Text
  /// chunks without generation data do not stop the search, and neither chunk
  /// source needs the image structure to be complete; the pixels do.
  MetadataParseResult? _parsePng(
    Uint8List bytes,
    Stopwatch stopwatch, {
    String? filePathForLog,
    required bool includeStealth,
  }) {
    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
    return _guarded(
      'PNG',
      bytes,
      stopwatch,
      filePathForLog: filePathForLog,
      parse: () {
        if (!ImageMetadataContainerCodec.isPngHeader(bytes)) {
          return MetadataParseResult.failed(
            const [],
            'Not a valid PNG file header, ${fileInfo}bytes length=${bytes.length}',
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
          );
        }

        // startDecode is null for anything that stops before IEND anyway; on a
        // prefix it reads chunk data past the end of the view or throws
        final info = ImageMetadataContainerCodec.pngReachesEnd(bytes)
            ? img.PngDecoder().startDecode(bytes) as img.PngInfo?
            : null;
        final text = _parseTextData(
          ImageMetadataContainerCodec.extractPngTextData(
            bytes,
            decoderTextData: info?.textData ?? const {},
          ),
        );
        if (text.success) return text;
        final exif = _parseExif(
          ExifMetadataExtractor.fromPng(bytes),
          bytes,
          stopwatch,
          parser: _pngExifParser,
          container: 'PNG',
          incompleteVerdict: MetadataPrefixVerdict.needsMoreBytes,
        );
        if (exif.success) return exif;
        final triedParsers = [...text.triedParsers, ...exif.triedParsers];
        // The text diagnosis stays: callers tell a damaged Comment from none by it
        if (info == null) {
          return MetadataParseResult.failed(
            triedParsers,
            text.errorMessage!,
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
            // Every chunk before the image data has been read by now; what is
            // left lives after it or in the pixels
            prefixVerdict:
                ImageMetadataContainerCodec.pngReachesImageData(bytes)
                ? MetadataPrefixVerdict.needsCompleteFile
                : MetadataPrefixVerdict.needsMoreBytes,
          );
        }
        if (!includeStealth) return null;
        return _preferStealth(
          bytes,
          stopwatch,
          fallback: MetadataParseResult.failed(
            triedParsers,
            text.errorMessage!,
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
          ),
        );
      },
    );
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
  }) => _guarded(
    'WebP',
    bytes,
    stopwatch,
    filePathForLog: filePathForLog,
    triedParsers: const [_webpExifParser],
    parse: () {
      final extraction = ExifMetadataExtractor.fromWebp(bytes);
      final result = _parseExif(
        extraction,
        bytes,
        stopwatch,
        parser: _webpExifParser,
        container: 'WebP',
        // The EXIF chunk sits at the end and the stealth payload needs every
        // pixel, so no shorter prefix of a truncated container can answer
        incompleteVerdict: MetadataPrefixVerdict.needsCompleteFile,
      );
      if (result.success || extraction.containerDamaged) return result;
      if (!includeStealth) return null;
      return _preferStealth(bytes, stopwatch, fallback: result);
    },
  );

  MetadataParseResult parseFromJpeg(Uint8List bytes, {String? filePathForLog}) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final result = _guarded(
      'JPEG',
      bytes,
      stopwatch,
      filePathForLog: filePathForLog,
      triedParsers: const [_jpegExifParser],
      // Without an alpha channel the web reader's stealth step always fails,
      // so the EXIF answer is final and needs no pixel decode.
      parse: () => _parseExif(
        ExifMetadataExtractor.fromJpeg(bytes),
        bytes,
        stopwatch,
        parser: _jpegExifParser,
        container: 'JPEG',
        incompleteVerdict: MetadataPrefixVerdict.needsMoreBytes,
      ),
    )!;
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  /// [incompleteVerdict] is how a gradual reader should go on when the bytes
  /// end before every place [container] may keep EXIF.
  MetadataParseResult _parseExif(
    ExifMetadataExtraction extraction,
    Uint8List bytes,
    Stopwatch stopwatch, {
    required String parser,
    required String container,
    required MetadataPrefixVerdict incompleteVerdict,
  }) {
    final prefixVerdict = extraction.complete
        ? MetadataPrefixVerdict.conclusive
        : incompleteVerdict;
    if (extraction.errorMessage != null || !extraction.hasMetadata) {
      return MetadataParseResult.failed(
        [parser],
        extraction.errorMessage ??
            'No EXIF UserComment metadata found in $container',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
        prefixVerdict: prefixVerdict,
      );
    }

    final parsed = _parseTextData(extraction.textData);
    return parsed.success && parsed.metadata != null
        ? MetadataParseResult.success(
            parsed.metadata!,
            '${parsed.sourceFormat} $parser',
            extraction.textData['Comment']!,
            [parser, ...parsed.triedParsers],
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
          )
        : MetadataParseResult.failed(
            [parser, ...parsed.triedParsers],
            parsed.errorMessage ?? 'Invalid $container EXIF metadata',
            parseTime: stopwatch.elapsed,
            bytesRead: bytes.length,
            prefixVerdict: prefixVerdict,
          );
  }

  /// Turns an unexpected throw while reading [container] into a failed result.
  MetadataParseResult? _guarded(
    String container,
    Uint8List bytes,
    Stopwatch stopwatch, {
    String? filePathForLog,
    List<String> triedParsers = const [],
    required MetadataParseResult? Function() parse,
  }) {
    try {
      return parse();
    } catch (error, stackTrace) {
      final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
      final summary = metadataErrorSummary(error);
      final message =
          'Error parsing metadata from $container (${fileInfo}bytes=${bytes.length}): $summary';
      PortableLogger.e(message, null, stackTrace, _tag);
      return MetadataParseResult.failed(
        triedParsers,
        message,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
    }
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
