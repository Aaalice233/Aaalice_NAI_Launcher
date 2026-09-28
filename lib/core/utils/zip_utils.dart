import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart' show InputFileStream, ZipFileEncoder;
import 'package:path/path.dart' as path;

import 'image_share_sanitizer.dart';

class ZipCreationProgress {
  const ZipCreationProgress({
    required this.current,
    required this.total,
    required this.currentFileName,
  });

  final int current;
  final int total;
  final String currentFileName;

  double get fraction => total == 0 ? 0 : current / total;
}

class ZipCreationFailure {
  const ZipCreationFailure({required this.path, required this.error});

  final String path;
  final String error;
}

class ZipCreationResult {
  const ZipCreationResult({
    required this.requestedCount,
    required this.exportedCount,
    required this.failures,
    this.error,
  });

  final int requestedCount;
  final int exportedCount;
  final List<ZipCreationFailure> failures;
  final String? error;

  bool get succeeded => error == null && exportedCount > 0;
  bool get isPartial => succeeded && failures.isNotEmpty;
}

class _ZipWorkerRequest {
  const _ZipWorkerRequest({
    required this.sendPort,
    required this.imagePaths,
    required this.outputPath,
    required this.stripMetadata,
  });

  final SendPort sendPort;
  final List<String> imagePaths;
  final String outputPath;
  final bool stripMetadata;
}

/// ZIP 工具类 - 处理 NovelAI 返回的 ZIP 响应
class ZipUtils {
  ZipUtils._();

  /// 从 ZIP 二进制数据中提取第一张 PNG 图片
  ///
  /// NovelAI 的图像生成 API 返回 ZIP 格式的响应，
  /// 其中包含一个或多个 PNG 图片文件
  static Uint8List? extractFirstImage(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile && file.name.toLowerCase().endsWith('.png')) {
          return Uint8List.fromList(file.content as List<int>);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 从 ZIP 中提取所有图片
  static List<Uint8List> extractAllImages(Uint8List zipBytes) {
    final images = <Uint8List>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.png') ||
              name.endsWith('.jpg') ||
              name.endsWith('.jpeg')) {
            images.add(Uint8List.fromList(file.content as List<int>));
          }
        }
      }
    } catch (e) {
      // 解压失败返回空列表
    }

    return images;
  }

  /// 从 ZIP 中提取图片及其文件名
  static List<({String name, Uint8List data})> extractImagesWithNames(
    Uint8List zipBytes,
  ) {
    final results = <({String name, Uint8List data})>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final file in archive.files) {
        if (file.isFile) {
          final name = file.name.toLowerCase();
          if (name.endsWith('.png') ||
              name.endsWith('.jpg') ||
              name.endsWith('.jpeg')) {
            results.add((
              name: file.name,
              data: Uint8List.fromList(file.content as List<int>),
            ));
          }
        }
      }
    } catch (e) {
      // 解压失败返回空列表
    }

    return results;
  }

  /// 将多个图片文件流式打包成 ZIP，避免保留整批图片和完整 ZIP 的内存副本。
  static Future<bool> createZipFromImages(
    List<String> imagePaths,
    String outputPath, {
    bool stripMetadata = false,
    void Function(int current, int total)? onProgress,
  }) async {
    final result = await createZipFromImagesDetailed(
      imagePaths,
      outputPath,
      stripMetadata: stripMetadata,
      onProgress: onProgress == null
          ? null
          : (progress) => onProgress(progress.current, progress.total),
    );
    return result.succeeded;
  }

  /// 在独立 isolate 中流式创建 ZIP，并返回可用于展示部分失败的结构化结果。
  static Future<ZipCreationResult> createZipFromImagesDetailed(
    List<String> imagePaths,
    String outputPath, {
    bool stripMetadata = false,
    void Function(ZipCreationProgress progress)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      return const ZipCreationResult(
        requestedCount: 0,
        exportedCount: 0,
        failures: [],
        error: 'No images were selected',
      );
    }

    final receivePort = ReceivePort();
    try {
      await Isolate.spawn(
        _createZipWorker,
        _ZipWorkerRequest(
          sendPort: receivePort.sendPort,
          imagePaths: List<String>.of(imagePaths),
          outputPath: outputPath,
          stripMetadata: stripMetadata,
        ),
        debugName: 'local-gallery-zip-export',
      );

      await for (final message in receivePort) {
        if (message is! Map<Object?, Object?>) continue;
        switch (message['type']) {
          case 'progress':
            onProgress?.call(
              ZipCreationProgress(
                current: message['current']! as int,
                total: message['total']! as int,
                currentFileName: message['fileName']! as String,
              ),
            );
            break;
          case 'result':
            final failureMaps = message['failures']! as List<Object?>;
            return ZipCreationResult(
              requestedCount: message['requestedCount']! as int,
              exportedCount: message['exportedCount']! as int,
              failures: failureMaps
                  .map((failure) {
                    final map = failure! as Map<Object?, Object?>;
                    return ZipCreationFailure(
                      path: map['path']! as String,
                      error: map['error']! as String,
                    );
                  })
                  .toList(growable: false),
              error: message['error'] as String?,
            );
        }
      }
    } on Object catch (error) {
      return ZipCreationResult(
        requestedCount: imagePaths.length,
        exportedCount: 0,
        failures: const [],
        error: error.toString(),
      );
    } finally {
      receivePort.close();
    }

    return ZipCreationResult(
      requestedCount: imagePaths.length,
      exportedCount: 0,
      failures: const [],
      error: 'ZIP worker exited without a result',
    );
  }

  /// 将多个图片文件打包成 ZIP 字节数据
  ///
  /// [imagePaths] 图片文件路径列表
  /// 返回 ZIP 的字节数据，失败返回 null
  static Future<Uint8List?> createZipBytesFromImages(
    List<String> imagePaths,
  ) async {
    try {
      final archive = Archive();

      for (final imagePath in imagePaths) {
        final file = File(imagePath);

        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path.basename(imagePath);

          archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
        }
      }

      if (archive.isEmpty) {
        return null;
      }

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      return zipData != null ? Uint8List.fromList(zipData) : null;
    } catch (e) {
      return null;
    }
  }
}

Future<void> _createZipWorker(_ZipWorkerRequest request) async {
  final failures = <Map<String, String>>[];
  final outputFile = File(request.outputPath);
  final suffix = '${DateTime.now().microsecondsSinceEpoch}';
  final temporaryFile = File(
    path.join(
      outputFile.parent.path,
      '.${path.basename(outputFile.path)}.$suffix.part',
    ),
  );
  final encoder = ZipFileEncoder();
  var encoderIsOpen = false;
  var exportedCount = 0;

  void sendResult({String? error}) {
    request.sendPort.send({
      'type': 'result',
      'requestedCount': request.imagePaths.length,
      'exportedCount': exportedCount,
      'failures': failures,
      'error': error,
    });
  }

  try {
    if (!await outputFile.parent.exists()) {
      throw FileSystemException(
        'Output directory does not exist',
        outputFile.parent.path,
      );
    }
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    encoder.create(temporaryFile.path, level: ZipFileEncoder.STORE);
    encoderIsOpen = true;
    final usedNames = <String>{};

    for (var index = 0; index < request.imagePaths.length; index++) {
      final imagePath = request.imagePaths[index];
      final sourceFile = File(imagePath);
      var archiveName = path.basename(imagePath);

      if (!await sourceFile.exists()) {
        failures.add({'path': imagePath, 'error': 'File not found'});
        _sendZipProgress(request, index, archiveName);
        continue;
      }

      SanitizedShareImage? sanitized;
      if (request.stripMetadata) {
        try {
          sanitized = await ImageShareSanitizer.sanitizeForShare(
            await sourceFile.readAsBytes(),
            fileName: archiveName,
          );
          archiveName = sanitized.fileName;
        } on Object catch (error) {
          failures.add({'path': imagePath, 'error': error.toString()});
          _sendZipProgress(request, index, archiveName);
          continue;
        }
      }

      archiveName = _allocateUniqueArchiveName(archiveName, usedNames);
      if (sanitized == null) {
        await encoder.addFile(sourceFile, archiveName, ZipFileEncoder.STORE);
      } else {
        final archiveFile = ArchiveFile(
          archiveName,
          sanitized.bytes.length,
          sanitized.bytes,
        )..compress = false;
        encoder.addArchiveFile(archiveFile);
      }
      exportedCount++;
      _sendZipProgress(request, index, archiveName);
    }

    await encoder.close();
    encoderIsOpen = false;

    if (exportedCount == 0) {
      await temporaryFile.delete();
      sendResult(error: 'No readable images were available for export');
      return;
    }

    final input = InputFileStream(temporaryFile.path);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      if (archive.files.length != exportedCount) {
        throw const FormatException('ZIP entry count verification failed');
      }
    } finally {
      await input.close();
    }

    await _commitZipAtomically(temporaryFile, outputFile, suffix);
    sendResult();
  } on Object catch (error) {
    if (encoderIsOpen) {
      try {
        await encoder.close();
      } on Object {
        // The original export error is more useful than close cleanup errors.
      }
    }
    if (await temporaryFile.exists()) {
      try {
        await temporaryFile.delete();
      } on Object {
        // The worker still reports the original failure to the caller.
      }
    }
    sendResult(error: error.toString());
  }
}

void _sendZipProgress(
  _ZipWorkerRequest request,
  int zeroBasedIndex,
  String fileName,
) {
  request.sendPort.send({
    'type': 'progress',
    'current': zeroBasedIndex + 1,
    'total': request.imagePaths.length,
    'fileName': fileName,
  });
}

String _allocateUniqueArchiveName(String requestedName, Set<String> usedNames) {
  final safeName = path.basename(requestedName).isEmpty
      ? 'image.png'
      : path.basename(requestedName);
  var candidate = safeName;
  var suffix = 2;
  while (!usedNames.add(candidate.toLowerCase())) {
    final extension = path.extension(safeName);
    final stem = path.basenameWithoutExtension(safeName);
    candidate = '$stem ($suffix)$extension';
    suffix++;
  }
  return candidate;
}

Future<void> _commitZipAtomically(
  File temporaryFile,
  File outputFile,
  String suffix,
) async {
  File? backupFile;
  if (await outputFile.exists()) {
    backupFile = File('${outputFile.path}.$suffix.backup');
    await outputFile.rename(backupFile.path);
  }

  try {
    await temporaryFile.rename(outputFile.path);
    if (backupFile != null && await backupFile.exists()) {
      await backupFile.delete();
    }
  } on Object {
    if (backupFile != null && await backupFile.exists()) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      await backupFile.rename(outputFile.path);
    }
    rethrow;
  }
}
