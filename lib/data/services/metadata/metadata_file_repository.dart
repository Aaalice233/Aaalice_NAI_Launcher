import 'dart:io';
import 'dart:typed_data';

import '../../../core/utils/portable_logger.dart';
import 'metadata_parse_result.dart';

/// Reads image files using the scanner's progressive byte thresholds.
class MetadataFileRepository {
  const MetadataFileRepository();

  static const List<int> gradualReadThresholds = [
    100 * 1024,
    500 * 1024,
    2 * 1024 * 1024,
  ];

  MetadataParseResult parse(
    String filePath, {
    required MetadataParseResult Function(Uint8List bytes, String filePath)
    parseBytes,
    required ParseStatistics statistics,
    int? maxBytes,
    bool useGradualRead = true,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return MetadataParseResult.failed([], 'File not found: $filePath');
    }

    final fileSize = file.lengthSync();
    if (fileSize < 8) {
      return MetadataParseResult.failed([], 'File too small: $fileSize bytes');
    }

    if (maxBytes != null && !useGradualRead) {
      return _extractWithLimit(file, filePath, maxBytes, fileSize, parseBytes);
    }
    if (useGradualRead) {
      return _extractGradual(file, filePath, fileSize, parseBytes, statistics);
    }
    return _extractFullFile(file, filePath, parseBytes);
  }

  MetadataParseResult _extractGradual(
    File file,
    String filePath,
    int fileSize,
    MetadataParseResult Function(Uint8List bytes, String filePath) parseBytes,
    ParseStatistics statistics,
  ) {
    statistics.gradualReadAttempts++;
    if (fileSize <= gradualReadThresholds.first) {
      return _extractFullFile(file, filePath, parseBytes);
    }

    for (final threshold in gradualReadThresholds) {
      if (fileSize <= threshold) {
        return _extractFullFile(file, filePath, parseBytes);
      }

      final result = _extractWithLimit(
        file,
        filePath,
        threshold,
        fileSize,
        parseBytes,
      );
      if (result.success) {
        statistics.gradualReadSuccesses++;
        return result;
      }
      if (result.errorMessage?.startsWith('Unsupported image container') ??
          false) {
        return result;
      }
    }

    return _extractFullFile(file, filePath, parseBytes);
  }

  MetadataParseResult _extractFullFile(
    File file,
    String filePath,
    MetadataParseResult Function(Uint8List bytes, String filePath) parseBytes,
  ) {
    try {
      return parseBytes(file.readAsBytesSync(), filePath);
    } catch (error) {
      PortableLogger.e(
        'Error reading full file: $error',
        error,
        null,
        'UnifiedMetadataParser',
      );
      return MetadataParseResult.failed(
        [],
        'Error reading full file: $error',
        bytesRead: file.lengthSync(),
      );
    }
  }

  MetadataParseResult _extractWithLimit(
    File file,
    String filePath,
    int maxBytes,
    int fileSize,
    MetadataParseResult Function(Uint8List bytes, String filePath) parseBytes,
  ) {
    try {
      if (fileSize <= maxBytes) {
        return parseBytes(file.readAsBytesSync(), filePath);
      }

      final fileHandle = file.openSync();
      try {
        final buffer = BytesBuilder(copy: false);
        var remaining = maxBytes;
        while (remaining > 0) {
          final chunk = fileHandle.readSync(remaining);
          if (chunk.isEmpty) break;
          buffer.add(chunk);
          remaining -= chunk.length;
        }
        return parseBytes(buffer.takeBytes(), filePath);
      } finally {
        fileHandle.closeSync();
      }
    } catch (error) {
      PortableLogger.d(
        'Error with ${maxBytes ~/ 1024}KB read: $error',
        'UnifiedMetadataParser',
      );
      return MetadataParseResult.failed(
        [],
        'Error with ${maxBytes ~/ 1024}KB read: $error',
        bytesRead: maxBytes,
      );
    }
  }
}
