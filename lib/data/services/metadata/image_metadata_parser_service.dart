import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/utils/portable_logger.dart';
import 'image_metadata_container_codec.dart';
import 'metadata_file_repository.dart';
import 'metadata_parse_result.dart';
import 'metadata_text_decoder.dart';
import 'webp_exif_metadata_extractor.dart';

/// Coordinates container decoding, text interpretation, files, cache and stats.
class ImageMetadataParserService {
  ImageMetadataParserService({
    MetadataTextDecoder? textDecoder,
    MetadataFileRepository? fileRepository,
  }) : _textDecoder = textDecoder ?? MetadataTextDecoder(),
       _fileRepository = fileRepository ?? const MetadataFileRepository();

  static const String _tag = 'UnifiedMetadataParser';

  final MetadataTextDecoder _textDecoder;
  final MetadataFileRepository _fileRepository;
  final Map<String, MetadataParseResult> _resultCache = {};
  final ParseStatistics statistics = ParseStatistics();

  MetadataParseResult parseFromFile(
    String filePath, {
    int? maxBytes,
    bool useGradualRead = true,
    bool useCache = true,
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
            parseFromImage(bytes, filePathForLog: path, useCache: false),
      );
      if (useCache && result.success && result.metadata != null) {
        _cacheFileResult(filePath, result);
      }
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
    bool useCache = false,
  }) {
    if (ImageMetadataContainerCodec.isPngHeader(bytes)) {
      return parseFromPng(
        bytes,
        filePathForLog: filePathForLog,
        useCache: useCache,
      );
    }
    if (WebpExifMetadataExtractor.hasWebpHeader(bytes)) {
      return parseFromWebp(
        bytes,
        filePathForLog: filePathForLog,
        useCache: useCache,
      );
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

  MetadataParseResult parseFromPng(
    Uint8List bytes, {
    String? filePathForLog,
    bool useCache = false,
  }) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final cacheKey = _bytesCacheKey(bytes);
    if (useCache) {
      final cached = _resultCache[cacheKey];
      if (cached != null) {
        _updateStatistics(cached, stopwatch.elapsed);
        return cached;
      }
    }

    final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
    try {
      if (!ImageMetadataContainerCodec.isPngHeader(bytes)) {
        final result = MetadataParseResult.failed(
          const [],
          'Not a valid PNG file header, ${fileInfo}bytes length=${bytes.length}',
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
        _updateStatistics(result, stopwatch.elapsed);
        return result;
      }

      final info = img.PngDecoder().startDecode(bytes);
      if (info == null) {
        final result = MetadataParseResult.failed(
          const [],
          bytes.length < 1024 * 1024
              ? 'Failed to decode PNG (incomplete data?)'
              : 'Failed to decode PNG',
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
        _updateStatistics(result, stopwatch.elapsed);
        return result;
      }

      final pngInfo = info as img.PngInfo;
      var result = _parseTextData(
        ImageMetadataContainerCodec.extractPngTextData(
          bytes,
          decoderTextData: pngInfo.textData,
        ),
      );
      if (!result.success) {
        final stealthText =
            ImageMetadataContainerCodec.extractStealthMetadataText(bytes);
        if (stealthText != null) {
          final stealthResult = _parseTextData({'Comment': stealthText});
          if (stealthResult.success && stealthResult.metadata != null) {
            result = MetadataParseResult.success(
              stealthResult.metadata!,
              'NovelAI stealth_pngcomp',
              stealthText,
              [...result.triedParsers, 'NovelAI stealth_pngcomp'],
              parseTime: stopwatch.elapsed,
              bytesRead: bytes.length,
            );
          }
        }
      }

      if (useCache && result.success) _resultCache[cacheKey] = result;
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    } catch (error, stackTrace) {
      final message =
          'Error parsing metadata from PNG (${fileInfo}bytes=${bytes.length}): $error';
      PortableLogger.e(message, error, stackTrace, _tag);
      final result = MetadataParseResult.failed(
        const [],
        message,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    }
  }

  MetadataParseResult parseFromWebp(
    Uint8List bytes, {
    String? filePathForLog,
    bool useCache = false,
  }) {
    final stopwatch = Stopwatch()..start();
    statistics.totalAttempts++;
    final cacheKey = _bytesCacheKey(bytes);
    if (useCache) {
      final cached = _resultCache[cacheKey];
      if (cached != null) {
        _updateStatistics(cached, stopwatch.elapsed);
        return cached;
      }
    }

    try {
      final extraction = WebpExifMetadataExtractor.extract(bytes);
      if (extraction.errorMessage != null || !extraction.hasMetadata) {
        final result = MetadataParseResult.failed(
          const ['WebP EXIF'],
          extraction.errorMessage ??
              'No EXIF UserComment metadata found in WebP',
          parseTime: stopwatch.elapsed,
          bytesRead: bytes.length,
        );
        _updateStatistics(result, stopwatch.elapsed);
        return result;
      }

      final parsed = _parseTextData(extraction.textData);
      final result = parsed.success && parsed.metadata != null
          ? MetadataParseResult.success(
              parsed.metadata!,
              '${parsed.sourceFormat} WebP EXIF',
              extraction.textData['Comment']!,
              ['WebP EXIF', ...parsed.triedParsers],
              parseTime: stopwatch.elapsed,
              bytesRead: bytes.length,
            )
          : MetadataParseResult.failed(
              ['WebP EXIF', ...parsed.triedParsers],
              parsed.errorMessage ?? 'Invalid WebP EXIF metadata',
              parseTime: stopwatch.elapsed,
              bytesRead: bytes.length,
            );
      if (useCache && result.success) _resultCache[cacheKey] = result;
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    } catch (error, stackTrace) {
      final fileInfo = filePathForLog != null ? 'file=$filePathForLog, ' : '';
      final message =
          'Error parsing metadata from WebP (${fileInfo}bytes=${bytes.length}): $error';
      PortableLogger.e(message, error, stackTrace, _tag);
      final result = MetadataParseResult.failed(
        const ['WebP EXIF'],
        message,
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
      _updateStatistics(result, stopwatch.elapsed);
      return result;
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
    final stealthText = ImageMetadataContainerCodec.extractStealthMetadataText(
      bytes,
    );
    if (stealthText == null) {
      final result = MetadataParseResult.failed(
        const ['NovelAI stealth_pngcomp'],
        'No NovelAI stealth_pngcomp metadata found',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    }

    final parsed = _parseTextData({'Comment': stealthText});
    if (!parsed.success || parsed.metadata == null) {
      final result = MetadataParseResult.failed(
        [...parsed.triedParsers, 'NovelAI stealth_pngcomp'],
        parsed.errorMessage ?? 'Failed to parse NovelAI stealth metadata',
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
      _updateStatistics(result, stopwatch.elapsed);
      return result;
    }

    final result = MetadataParseResult.success(
      parsed.metadata!,
      'NovelAI stealth_pngcomp',
      stealthText,
      [...parsed.triedParsers, 'NovelAI stealth_pngcomp'],
      parseTime: stopwatch.elapsed,
      bytesRead: bytes.length,
    );
    _updateStatistics(result, stopwatch.elapsed);
    return result;
  }

  void resetStatistics() => statistics.reset();

  void clearCache() => _resultCache.clear();

  void _cacheFileResult(String filePath, MetadataParseResult result) {
    final key =
        '$filePath:${result.bytesRead}:${result.metadata?.prompt.hashCode ?? 0}';
    _resultCache[key] = result;
    if (_resultCache.length > 100) _resultCache.remove(_resultCache.keys.first);
  }

  String _bytesCacheKey(Uint8List bytes) {
    final data = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    return data.hashCode.toString();
  }

  void _updateStatistics(MetadataParseResult result, Duration elapsed) {
    statistics.totalParseTime += elapsed;
    if (result.success) {
      statistics.successfulParses++;
    } else {
      statistics.failedParses++;
    }
  }
}
