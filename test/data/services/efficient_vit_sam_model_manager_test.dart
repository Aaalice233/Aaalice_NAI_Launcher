import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/efficient_vit_sam_model_manager.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory modelDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'efficient_vit_sam_model_manager_test_',
    );
    modelDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}models',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('downloads, verifies, and reuses both model files', () async {
    final encoderBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final decoderBytes = Uint8List.fromList(<int>[5, 6, 7]);
    final encoder = _asset('encoder.onnx', encoderBytes);
    final decoder = _asset('decoder.onnx', decoderBytes);
    final downloads = <String>[];
    final progress = <double>[];

    final manager = EfficientVitSamModelManager(
      directoryResolver: () async => modelDirectory,
      encoder: encoder,
      decoder: decoder,
      download: (asset, destination, onProgress) async {
        downloads.add(asset.fileName);
        final bytes = asset.fileName == encoder.fileName
            ? encoderBytes
            : decoderBytes;
        await destination.writeAsBytes(bytes, flush: true);
        onProgress(bytes.length, bytes.length);
      },
    );

    final first = await manager.ensureModels(
      onProgress: (value, _) => progress.add(value),
    );
    final second = await manager.ensureModels(
      onProgress: (value, _) => progress.add(value),
    );

    expect(downloads, <String>['encoder.onnx', 'decoder.onnx']);
    expect(await File(first.encoderPath).readAsBytes(), encoderBytes);
    expect(await File(first.decoderPath).readAsBytes(), decoderBytes);
    expect(second.encoderPath, first.encoderPath);
    expect(second.decoderPath, first.decoderPath);
    expect(progress.last, 1);
  });

  test('redownloads a cached file that fails integrity validation', () async {
    final encoderBytes = Uint8List.fromList(<int>[10, 20, 30, 40]);
    final decoderBytes = Uint8List.fromList(<int>[50, 60, 70]);
    final encoder = _asset('encoder.onnx', encoderBytes);
    final decoder = _asset('decoder.onnx', decoderBytes);
    await modelDirectory.create(recursive: true);
    await File(
      '${modelDirectory.path}${Platform.pathSeparator}${encoder.fileName}',
    ).writeAsBytes(<int>[0, 0, 0, 0]);
    await File(
      '${modelDirectory.path}${Platform.pathSeparator}${decoder.fileName}',
    ).writeAsBytes(decoderBytes);
    final downloads = <String>[];

    final manager = EfficientVitSamModelManager(
      directoryResolver: () async => modelDirectory,
      encoder: encoder,
      decoder: decoder,
      download: (asset, destination, onProgress) async {
        downloads.add(asset.fileName);
        final bytes = asset.fileName == encoder.fileName
            ? encoderBytes
            : decoderBytes;
        await destination.writeAsBytes(bytes, flush: true);
        onProgress(bytes.length, bytes.length);
      },
    );

    await manager.ensureModels();

    expect(downloads, <String>['encoder.onnx']);
  });
}

EfficientVitSamModelAsset _asset(String fileName, Uint8List bytes) {
  return EfficientVitSamModelAsset(
    fileName: fileName,
    url: 'https://example.invalid/$fileName',
    expectedBytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
}
