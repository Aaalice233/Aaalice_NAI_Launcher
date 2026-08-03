import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/isolate_pool.dart';

typedef EfficientVitSamDirectoryResolver = Future<Directory> Function();
typedef EfficientVitSamModelProgressCallback =
    void Function(double progress, bool isDownloading);
typedef EfficientVitSamDownloadCallback =
    Future<void> Function(
      EfficientVitSamModelAsset asset,
      File destination,
      void Function(int receivedBytes, int totalBytes) onProgress,
    );

class EfficientVitSamModelAsset {
  const EfficientVitSamModelAsset({
    required this.fileName,
    required this.url,
    required this.expectedBytes,
    required this.sha256,
  });

  final String fileName;
  final String url;
  final int expectedBytes;
  final String sha256;
}

class EfficientVitSamModelFiles {
  const EfficientVitSamModelFiles({
    required this.encoderPath,
    required this.decoderPath,
  });

  final String encoderPath;
  final String decoderPath;
}

class EfficientVitSamModelManager {
  EfficientVitSamModelManager({
    EfficientVitSamDirectoryResolver? directoryResolver,
    EfficientVitSamDownloadCallback? download,
    EfficientVitSamModelAsset encoder = encoderAsset,
    EfficientVitSamModelAsset decoder = decoderAsset,
  }) : _directoryResolver = directoryResolver ?? _defaultModelDirectoryResolver,
       _download = download ?? _downloadWithDio,
       _encoder = encoder,
       _decoder = decoder;

  static const String modelRevision =
      '6a80311888e8c2e2e92f22f554564c0be1f018ae';
  static const String modelRepositoryUrl =
      'https://huggingface.co/mit-han-lab/efficientvit-sam';
  static const int totalDownloadBytes = 139583279;

  static const EfficientVitSamModelAsset
  encoderAsset = EfficientVitSamModelAsset(
    fileName: 'l0_encoder.onnx',
    url:
        '$modelRepositoryUrl/resolve/$modelRevision/onnx/l0_encoder.onnx?download=true',
    expectedBytes: 123112917,
    sha256: '7a37ebd16e65c31253416e33897e7e6b07699127765d538e99ecbfaa3ad1e727',
  );

  static const EfficientVitSamModelAsset
  decoderAsset = EfficientVitSamModelAsset(
    fileName: 'l0_decoder.onnx',
    url:
        '$modelRepositoryUrl/resolve/$modelRevision/onnx/l0_decoder.onnx?download=true',
    expectedBytes: 16470362,
    sha256: '053e72c5703736a8a8a92482c9990c4a26dde9dcb7ff26b05843cf0bc433f42f',
  );

  final EfficientVitSamDirectoryResolver _directoryResolver;
  final EfficientVitSamDownloadCallback _download;
  final EfficientVitSamModelAsset _encoder;
  final EfficientVitSamModelAsset _decoder;
  EfficientVitSamModelFiles? _readyFiles;

  Future<EfficientVitSamModelFiles> ensureModels({
    EfficientVitSamModelProgressCallback? onProgress,
  }) async {
    final readyFiles = _readyFiles;
    if (readyFiles != null) {
      onProgress?.call(1, false);
      return readyFiles;
    }

    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    final assets = <EfficientVitSamModelAsset>[_encoder, _decoder];
    final completedByAsset = <String, int>{};
    final totalBytes = assets.fold<int>(
      0,
      (sum, asset) => sum + asset.expectedBytes,
    );

    void reportProgress({required bool isDownloading}) {
      if (totalBytes <= 0) {
        onProgress?.call(0, isDownloading);
        return;
      }
      final received = completedByAsset.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      onProgress?.call((received / totalBytes).clamp(0.0, 1.0), isDownloading);
    }

    for (final asset in assets) {
      final target = File(p.join(directory.path, asset.fileName));
      if (await _isValidModel(target, asset)) {
        completedByAsset[asset.fileName] = asset.expectedBytes;
        reportProgress(isDownloading: false);
        continue;
      }

      if (await target.exists()) {
        await target.delete();
      }
      final partial = File('${target.path}.part');
      if (await partial.exists()) {
        await partial.delete();
      }

      try {
        await _download(asset, partial, (receivedBytes, total) {
          completedByAsset[asset.fileName] = receivedBytes
              .clamp(0, asset.expectedBytes)
              .toInt();
          reportProgress(isDownloading: true);
        });
        if (!await _isValidModel(partial, asset)) {
          throw StateError(
            'Downloaded EfficientViT-SAM file failed integrity validation: '
            '${asset.fileName}',
          );
        }
        await partial.rename(target.path);
        completedByAsset[asset.fileName] = asset.expectedBytes;
        reportProgress(isDownloading: true);
      } catch (_) {
        if (await partial.exists()) {
          await partial.delete();
        }
        rethrow;
      }
    }

    final files = EfficientVitSamModelFiles(
      encoderPath: p.join(directory.path, _encoder.fileName),
      decoderPath: p.join(directory.path, _decoder.fileName),
    );
    _readyFiles = files;
    onProgress?.call(1, false);
    return files;
  }

  static Future<Directory> _defaultModelDirectoryResolver() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      p.join(supportDirectory.path, 'models', 'efficientvit_sam', 'l0'),
    );
  }

  static Future<void> _downloadWithDio(
    EfficientVitSamModelAsset asset,
    File destination,
    void Function(int receivedBytes, int totalBytes) onProgress,
  ) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 30),
        followRedirects: true,
      ),
    );
    try {
      await dio.download(
        asset.url,
        destination.path,
        deleteOnError: true,
        onReceiveProgress: onProgress,
      );
    } finally {
      dio.close();
    }
  }

  static Future<bool> _isValidModel(
    File file,
    EfficientVitSamModelAsset asset,
  ) async {
    if (!await file.exists()) {
      return false;
    }
    if (await file.length() != asset.expectedBytes) {
      return false;
    }
    final path = file.path;
    final digest = await ComputeGate.singleTask().runIsolate(
      () async => sha256.bind(File(path).openRead()).first,
    );
    return digest.toString().toLowerCase() == asset.sha256.toLowerCase();
  }
}
