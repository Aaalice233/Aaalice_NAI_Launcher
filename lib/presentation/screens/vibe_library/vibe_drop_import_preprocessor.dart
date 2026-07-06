import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../data/services/vibe_import_service.dart';

typedef VibeDropFileLengthReader = Future<int> Function(String path);
typedef VibeDropFileBytesReader = Future<Uint8List> Function(String path);

class VibeDropImageReadLimits {
  const VibeDropImageReadLimits({
    this.maxFileBytes = 50 * 1024 * 1024,
    this.maxTotalBytes = 500 * 1024 * 1024,
    this.batchSize = 5,
  }) : assert(maxFileBytes > 0),
       assert(maxTotalBytes > 0),
       assert(batchSize > 0);

  final int maxFileBytes;
  final int maxTotalBytes;
  final int batchSize;
}

class VibeDropImageReadResult {
  const VibeDropImageReadResult({
    required this.items,
    required this.failedCount,
    required this.skippedOversizedCount,
    required this.skippedTotalLimitCount,
  });

  final List<VibeImageImportItem> items;
  final int failedCount;
  final int skippedOversizedCount;
  final int skippedTotalLimitCount;
}

class VibeDropImportPreprocessor {
  const VibeDropImportPreprocessor._();

  static Future<VibeDropImageReadResult> collectImageItems(
    List<String> imagePaths, {
    VibeDropImageReadLimits limits = const VibeDropImageReadLimits(),
    VibeDropFileLengthReader lengthReader = _fileLength,
    VibeDropFileBytesReader bytesReader = _fileBytes,
  }) async {
    final candidates = <String>[];
    var totalBytes = 0;
    var failedCount = 0;
    var skippedOversizedCount = 0;
    var skippedTotalLimitCount = 0;

    for (var index = 0; index < imagePaths.length; index += 1) {
      final path = imagePaths[index];
      int size;
      try {
        size = await lengthReader(path);
      } catch (_) {
        failedCount += 1;
        continue;
      }

      if (size > limits.maxFileBytes) {
        skippedOversizedCount += 1;
        continue;
      }
      if (totalBytes + size > limits.maxTotalBytes) {
        skippedTotalLimitCount = imagePaths.length - index;
        break;
      }

      candidates.add(path);
      totalBytes += size;
    }

    final items = <VibeImageImportItem>[];
    for (var start = 0; start < candidates.length; start += limits.batchSize) {
      final end = math.min(start + limits.batchSize, candidates.length);
      final batch = candidates.sublist(start, end);
      final results = await Future.wait(
        batch.map((path) async {
          try {
            final bytes = await bytesReader(path);
            return VibeImageImportItem(source: p.basename(path), bytes: bytes);
          } catch (_) {
            failedCount += 1;
            return null;
          }
        }),
      );
      items.addAll(results.whereType<VibeImageImportItem>());
      await Future<void>.delayed(Duration.zero);
    }

    return VibeDropImageReadResult(
      items: items,
      failedCount: failedCount,
      skippedOversizedCount: skippedOversizedCount,
      skippedTotalLimitCount: skippedTotalLimitCount,
    );
  }

  static Future<int> _fileLength(String path) => File(path).length();

  static Future<Uint8List> _fileBytes(String path) => File(path).readAsBytes();
}
