import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
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
          kind: LocalOnnxModelKind.clTagger,
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

  group('ComputeGate', () {
    test('provides a serial gate for memory-heavy ONNX work', () {
      expect(ComputeGate.singleTask().maxConcurrentTasks, 1);
    });
  });
}
