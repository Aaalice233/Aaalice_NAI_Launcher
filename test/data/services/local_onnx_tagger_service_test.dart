import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_preprocessor.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_service.dart';

void main() {
  group('LocalOnnxTaggerService preprocessing', () {
    test(
      'letterboxes extreme source images directly into input-sized canvas',
      () {
        final layout = LocalOnnxTaggerService.debugLetterboxLayoutForTesting(
          sourceWidth: 20000,
          sourceHeight: 1000,
          inputSize: 448,
        );

        expect(layout.canvasWidth, 448);
        expect(layout.canvasHeight, 448);
        expect(layout.resizedWidth, 448);
        expect(layout.resizedHeight, 22);
        expect(layout.offsetX, 0);
        expect(layout.offsetY, 213);
        expect(layout.canvasPixels, 448 * 448);
      },
    );

    test('uses AnimeTimm official RGB NCHW normalization profile', () {
      const descriptor = LocalOnnxModelDescriptor(
        name: 'eva02_large_patch14.onnx',
        path: 'eva02_large_patch14.onnx',
        kind: LocalOnnxModelKind.animeTimmEva02,
      );
      final source = img.Image(width: 2, height: 1);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));

      final input = LocalOnnxTaggerPreprocessor.preprocess(source, descriptor);
      final profile = LocalOnnxTaggerPreprocessor.profileFor(descriptor);
      const planeSize = 448 * 448;
      const centerPixel = 224 * 448 + 224;

      expect(input.shape, [1, 3, 448, 448]);
      expect(input.data[centerPixel], closeTo(1.9303, 0.001));
      expect(input.data[planeSize + centerPixel], closeTo(-1.7521, 0.001));
      expect(input.data[planeSize * 2 + centerPixel], closeTo(-1.4802, 0.001));
      expect(input.data[planeSize], closeTo(2.0749, 0.001));
      expect(input.data[planeSize * 2], closeTo(2.1459, 0.001));
      expect(profile.normalizeScores([0]).single, closeTo(0.5, 0.000001));
    });
  });

  group('LocalOnnxTaggerService session loading', () {
    test('uses a patched file session for single-file models', () {
      const descriptor = LocalOnnxModelDescriptor(
        name: 'cl_tagger_1_02',
        path: r'G:\models\cl_tagger_1_02\model.onnx',
        kind: LocalOnnxModelKind.clTagger,
      );

      expect(
        LocalOnnxTaggerService.debugSessionLoadModeForTesting(descriptor),
        OnnxSessionLoadMode.patchedSingleFile,
      );
    });

    test('keeps external-data models on external-data file sessions', () async {
      final directory = await Directory.systemTemp.createTemp(
        'nai_launcher_onnx_external_data_test_',
      );
      try {
        final modelPath =
            '${directory.path}${Platform.pathSeparator}model.onnx';
        await File(modelPath).writeAsBytes(const []);
        await File('$modelPath.data').writeAsBytes(const []);

        final descriptor = LocalOnnxModelDescriptor(
          name: 'cl_tagger_v2',
          path: modelPath,
          kind: LocalOnnxModelKind.clTaggerV2,
          labelsPath:
              '${directory.path}${Platform.pathSeparator}model_vocabulary.json',
        );

        expect(
          LocalOnnxTaggerService.debugSessionLoadModeForTesting(descriptor),
          OnnxSessionLoadMode.externalDataFile,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('LocalOnnxTaggerService mobile inference tuning', () {
    test(
      'raises intra-op threads on mobile but keeps desktop single-threaded',
      () {
        expect(
          LocalOnnxTaggerService.resolveIntraOpThreadCount(
            PlatformCapabilities.forPlatform(TargetPlatform.iOS),
            processorCount: 8,
          ),
          4,
        );
        expect(
          LocalOnnxTaggerService.resolveIntraOpThreadCount(
            PlatformCapabilities.forPlatform(TargetPlatform.android),
            processorCount: 2,
          ),
          2,
        );
        expect(
          LocalOnnxTaggerService.resolveIntraOpThreadCount(
            PlatformCapabilities.forPlatform(TargetPlatform.windows),
            processorCount: 16,
          ),
          1,
        );
      },
    );

    test(
      'loads the original model file when the opset patch is a no-op',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'nai_launcher_onnx_opset_noop_test_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final model = await File(
          '${directory.path}${Platform.pathSeparator}model.onnx',
        ).writeAsBytes(List<int>.filled(8192, 0));

        final resolved = await const LocalOnnxTaggerService()
            .debugEnsurePatchedModelPathForTesting(model.path);

        expect(resolved, model.path);
      },
    );

    test(
      'still writes a patched copy when the opset tail needs patching',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'nai_launcher_onnx_opset_patch_test_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final bytes = List<int>.filled(8192, 0);
        bytes.setRange(8188, 8192, const [0x42, 0x02, 0x10, 20]);
        final model = await File(
          '${directory.path}${Platform.pathSeparator}model.onnx',
        ).writeAsBytes(bytes);

        final resolved = await const LocalOnnxTaggerService()
            .debugEnsurePatchedModelPathForTesting(model.path);
        addTearDown(() async {
          final patched = File(resolved);
          if (await patched.exists()) await patched.delete();
        });

        expect(resolved, isNot(model.path));
        final patchedBytes = await File(resolved).readAsBytes();
        expect(patchedBytes.length, bytes.length);
        expect(patchedBytes.sublist(8188), [0x42, 0x02, 0x10, 18]);
      },
    );
  });

  group('ComputeGate', () {
    test('provides a serial gate for memory-heavy ONNX work', () {
      expect(ComputeGate.singleTask().maxConcurrentTasks, 1);
    });
  });
}
