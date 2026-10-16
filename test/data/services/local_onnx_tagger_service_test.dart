import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/utils/exif_orientation.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_labels.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_preprocessor.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_service.dart';
import 'package:nai_launcher/data/services/onnx_session_input_spec.dart';

import '../../helpers/grayscale_png_fixture.dart';

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
    test('feeds single-channel grayscale as equal color channels', () {
      const descriptor = LocalOnnxModelDescriptor(
        name: 'wd-v1-4-vit-tagger-v2.onnx',
        path: 'wd-v1-4-vit-tagger-v2.onnx',
        kind: LocalOnnxModelKind.wd14Tagger,
      );
      final gray = ExifOrientation.decodeUpright(
        grayscalePng(width: 4, height: 4),
      )!;

      final input = LocalOnnxTaggerPreprocessor.preprocess(gray, descriptor);
      const center = (224 * 448 + 224) * 3;

      expect(input.shape, [1, 448, 448, 3]);
      expect(input.data.sublist(center, center + 3), [160, 160, 160]);
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
          OnnxSessionLoadMode.originalFile,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('LocalOnnxTaggerService mobile inference tuning', () {
    test(
      'caps mobile intra-op threads at four and gives desktop half the cores',
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
          8,
        );
        expect(
          LocalOnnxTaggerService.resolveIntraOpThreadCount(
            PlatformCapabilities.forPlatform(TargetPlatform.macOS),
            processorCount: 1,
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
            .ensurePatchedModelPathForTesting(model.path);

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
            .ensurePatchedModelPathForTesting(model.path);
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

  group('PixAI rescale-pad preprocessing', () {
    // 期望值由 pixai-tagger-v1.0 的 tagger_pipeline.py 原样代码
    // （PIL alpha_composite + torchvision rescale_pad + normalize）算出
    test('matches the official pipeline on an rgb source', () {
      final input = LocalOnnxTaggerPreprocessor.preprocess(
        _rgbPattern(37, 23),
        _pixaiDescriptor,
        inputSize: 16,
      );

      _expectMatchesOfficial(
        input,
        shape: [1, 3, 16, 16],
        sums: [-112.16435, -112.21782, -112.41779],
        picks: {
          0: -1.0,
          74: 0.641688,
          111: -0.219441,
          148: -0.691914,
          185: 0.308497,
          222: -1.0,
          333: -0.593743,
          370: 0.73761,
          407: -0.050305,
          444: -0.561431,
          592: 0.432568,
          629: -0.429652,
          666: 0.718679,
          703: -0.164332,
          740: -1.0,
        },
      );
    });

    test('matches the official alpha flattening and upscaling', () {
      final input = LocalOnnxTaggerPreprocessor.preprocess(
        _rgbaPattern(5, 3),
        _pixaiDescriptor,
        inputSize: 8,
      );

      _expectMatchesOfficial(
        input,
        shape: [1, 3, 8, 8],
        sums: [-15.34142, -9.82684, -19.80741],
        picks: {
          0: -1.0,
          37: 0.468934,
          74: -1.0,
          111: 0.262745,
          148: 0.938235,
          185: -1.0,
        },
      );
    });

    test('defaults to the 1008 input of the released model', () {
      final input = LocalOnnxTaggerPreprocessor.preprocess(
        _rgbPattern(4, 2),
        _pixaiDescriptor,
      );

      expect(input.shape, [1, 3, 1008, 1008]);
    });

    test('floors the scaled side like the official int() conversion', () {
      final layout = LocalOnnxTaggerPreprocessor.computeRescalePadLayout(
        sourceWidth: 1216,
        sourceHeight: 832,
        inputSize: 1008,
      );

      expect((layout.resizedWidth, layout.resizedHeight), (1008, 689));
      expect((layout.offsetX, layout.offsetY), (0, 159));
    });

    test('keeps an exact-size source unscaled and unpadded', () {
      final layout = LocalOnnxTaggerPreprocessor.computeRescalePadLayout(
        sourceWidth: 1008,
        sourceHeight: 1008,
        inputSize: 1008,
      );

      expect((layout.resizedWidth, layout.resizedHeight), (1008, 1008));
      expect((layout.offsetX, layout.offsetY), (0, 0));
    });

    test('profile keeps the original graph and official thresholds', () {
      final profile = LocalOnnxTaggerPreprocessor.profileFor(_pixaiDescriptor);

      expect(profile.layout, OnnxTensorLayout.nchw);
      expect(profile.lowersOpsetImports, isFalse);
      expect(profile.recommendedThresholds, {
        OnnxTaggerLabelCategory.copyright: 0.24,
        OnnxTaggerLabelCategory.artist: 0.15,
        OnnxTaggerLabelCategory.meta: 0.17,
      });
      expect(
        LocalOnnxTaggerService.debugSessionLoadModeForTesting(_pixaiDescriptor),
        OnnxSessionLoadMode.originalFile,
      );
    });

    test('repeats the image for a fixed batch input', () {
      final single = OnnxImageInput(
        data: Float32List.fromList([1, 2, 3]),
        shape: const [1, 3, 1, 1],
      );

      final batched = single.repeatedForBatch(2);

      expect(batched.shape, [2, 3, 1, 1]);
      expect(batched.data, [1, 2, 3, 1, 2, 3]);
      expect(single.repeatedForBatch(1), same(single));
    });
  });

  group('OnnxSessionInputSpec', () {
    test('reads layout, square size and fixed batch', () {
      const pixai = OnnxSessionInputSpec([-1, 3, 1008, 1008]);
      const wd14 = OnnxSessionInputSpec([1, 448, 448, 3]);
      const fixedBatch = OnnxSessionInputSpec([2, 3, 336, 336]);

      expect(
        (pixai.layout, pixai.squareSize, pixai.batchSize),
        (OnnxTensorLayout.nchw, 1008, 1),
      );
      expect(
        (wd14.layout, wd14.squareSize, wd14.batchSize),
        (OnnxTensorLayout.nhwc, 448, 1),
      );
      expect(fixedBatch.batchSize, 2);
    });

    test('leaves dynamic or unusual shapes to the profile', () {
      for (final dimensions in [
        <int>[],
        [1, 3, -1, -1],
        [1, 3, 448, 384],
        [1, 1, 64, 64],
      ]) {
        expect(OnnxSessionInputSpec(dimensions).squareSize, isNull);
      }
      expect(const OnnxSessionInputSpec([1, 1, 64, 64]).layout, isNull);
    });
  });

  group('LocalOnnxTaggerService.selectTags', () {
    const labels = [
      OnnxTaggerLabel(name: '1girl', category: 'general'),
      OnnxTaggerLabel(name: 'solo', category: 'general'),
      OnnxTaggerLabel(name: 'hatsune_miku', category: 'character'),
      OnnxTaggerLabel(name: 'vocaloid', category: 'copyright'),
      OnnxTaggerLabel(name: 'kujiran', category: 'style'),
      OnnxTaggerLabel(name: 'highres', category: 'meta'),
      OnnxTaggerLabel(name: 'rating:g', category: 'rating'),
    ];
    const scores = [0.6, 0.9, 0.5, 0.3, 0.2, 0.95, 0.99];

    test('groups like the gallery and prefixes artists', () {
      final tags = LocalOnnxTaggerService.selectTags(
        labels: labels,
        scores: scores,
        thresholds: const OnnxTaggerThresholds(
          general: 0.35,
          character: 0.35,
          recommended: {
            OnnxTaggerLabelCategory.copyright: 0.24,
            OnnxTaggerLabelCategory.artist: 0.15,
            OnnxTaggerLabelCategory.meta: 0.17,
          },
        ),
        categories: OnnxTaggerLabelCategory.selectable.toSet(),
      );

      expect(
        OnnxTaggerResult(model: _pixaiDescriptor, tags: tags).prompt,
        'artist:kujiran, hatsune_miku, vocaloid, solo, 1girl, highres',
      );
    });

    test('drops unselected categories and never outputs ratings', () {
      final tags = LocalOnnxTaggerService.selectTags(
        labels: labels,
        scores: scores,
        thresholds: const OnnxTaggerThresholds(general: 0.35, character: 0.35),
        categories: OnnxTaggerLabelCategory.defaultPromptCategories,
      );

      expect(tags.map((tag) => tag.name), ['hatsune_miku', 'solo', '1girl']);
    });

    test('falls back to the sliders without recommended values', () {
      const thresholds = OnnxTaggerThresholds(general: 0.4, character: 0.6);

      expect(thresholds.forCategory(OnnxTaggerLabelCategory.copyright), 0.6);
      expect(thresholds.forCategory(OnnxTaggerLabelCategory.artist), 0.6);
      expect(thresholds.forCategory(OnnxTaggerLabelCategory.meta), 0.4);
      expect(thresholds.forCategory(OnnxTaggerLabelCategory.general), 0.4);
      expect(thresholds.forCategory(OnnxTaggerLabelCategory.character), 0.6);
    });

    test('sliders keep control of general and character', () {
      const thresholds = OnnxTaggerThresholds(
        general: 0.4,
        character: 0.6,
        recommended: {
          OnnxTaggerLabelCategory.general: 0.17,
          OnnxTaggerLabelCategory.character: 0.27,
        },
      );

      expect(thresholds.forCategory(OnnxTaggerLabelCategory.general), 0.4);
      expect(thresholds.forCategory(OnnxTaggerLabelCategory.character), 0.6);
    });
  });

  group('ComputeGate', () {
    test('provides a serial gate for memory-heavy ONNX work', () {
      expect(ComputeGate.singleTask().maxConcurrentTasks, 1);
    });
  });
}

const _pixaiDescriptor = LocalOnnxModelDescriptor(
  name: 'model.onnx',
  path: 'pixai-tagger-v1.0-onnx/model.onnx',
  kind: LocalOnnxModelKind.pixaiTagger,
);

img.Image _rgbPattern(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.setRgb(
      (pixel.x * 7 + pixel.y * 13) % 256,
      (pixel.x * 7 + pixel.y * 13 + 50) % 256,
      (pixel.x * 7 + pixel.y * 13 + 100) % 256,
    );
  }
  return image;
}

img.Image _rgbaPattern(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (final pixel in image) {
    pixel.setRgba(
      (pixel.x * 29 + pixel.y * 61) % 256,
      (pixel.x * 29 + pixel.y * 61 + 83) % 256,
      (pixel.x * 29 + pixel.y * 61 + 166) % 256,
      (pixel.x * 47 + pixel.y * 97) % 256,
    );
  }
  return image;
}

void _expectMatchesOfficial(
  OnnxImageInput input, {
  required List<int> shape,
  required List<double> sums,
  required Map<int, double> picks,
}) {
  expect(input.shape, shape);
  final planeSize = shape[2] * shape[3];
  for (var channel = 0; channel < 3; channel++) {
    var sum = 0.0;
    for (var index = 0; index < planeSize; index++) {
      sum += input.data[channel * planeSize + index];
    }
    expect(sum, closeTo(sums[channel], 1e-3), reason: 'channel $channel');
  }
  for (final MapEntry(key: index, value: expected) in picks.entries) {
    expect(input.data[index], closeTo(expected, 1e-5), reason: '$index');
  }
}
