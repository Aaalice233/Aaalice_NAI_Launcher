import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/utils/antialiased_bilinear_resampler.dart';
import 'local_onnx_model_service.dart';
import 'local_onnx_tagger_labels.dart';

enum OnnxTaggerPreprocessing {
  wd14,
  clTagger,
  clTaggerV2,
  animeTimm,
  pixaiRescalePad,
}

enum OnnxTaggerOutputActivation { auto, sigmoid }

enum OnnxTensorLayout { nchw, nhwc }

class OnnxTaggerPreprocessProfile {
  const OnnxTaggerPreprocessProfile({
    required this.preprocessing,
    required this.inputSize,
    required this.outputActivation,
    this.layout = OnnxTensorLayout.nchw,
    this.recommendedThresholds = const {},
    this.lowersOpsetImports = true,
  });

  final OnnxTaggerPreprocessing preprocessing;

  // 模型输入未声明固定尺寸时采用的边长
  final int inputSize;
  final OnnxTaggerOutputActivation outputActivation;
  final OnnxTensorLayout layout;

  // 模型官方的分类阈值，标签文件自带阈值时让位
  final Map<OnnxTaggerLabelCategory, double> recommendedThresholds;

  // 单文件模型加载前把 opset 降到 18，绕开捆绑 ORT 绑定 Shape(19) 失败
  final bool lowersOpsetImports;

  List<double> normalizeScores(List<double> scores) {
    if (outputActivation == OnnxTaggerOutputActivation.sigmoid ||
        scores.any((score) => score < 0 || score > 1)) {
      return scores.map((score) => 1 / (1 + math.exp(-score))).toList();
    }
    return scores;
  }
}

class OnnxImageInput {
  const OnnxImageInput({required this.data, required this.shape});

  final Float32List data;
  final List<int> shape;

  OnnxImageInput repeatedForBatch(int batchSize) {
    if (batchSize <= 1) return this;
    final batched = Float32List(data.length * batchSize);
    for (var index = 0; index < batchSize; index++) {
      batched.setRange(index * data.length, (index + 1) * data.length, data);
    }
    return OnnxImageInput(data: batched, shape: [batchSize, ...shape.skip(1)]);
  }
}

class OnnxLetterboxLayout {
  const OnnxLetterboxLayout({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.offsetX,
    required this.offsetY,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int resizedWidth;
  final int resizedHeight;
  final int offsetX;
  final int offsetY;

  int get canvasPixels => canvasWidth * canvasHeight;
}

class LocalOnnxTaggerPreprocessor {
  const LocalOnnxTaggerPreprocessor._();

  static const int defaultInputSize = 448;
  static const List<double> _animeTimmMean = [
    0.48145466,
    0.4578275,
    0.40821073,
  ];
  static const List<double> _animeTimmStd = [0.26862954, 0.2613026, 0.2757771];

  static OnnxTaggerPreprocessProfile profileFor(
    LocalOnnxModelDescriptor model,
  ) {
    return switch (model.kind) {
      LocalOnnxModelKind.pixaiTagger => const OnnxTaggerPreprocessProfile(
        preprocessing: OnnxTaggerPreprocessing.pixaiRescalePad,
        inputSize: 1008,
        outputActivation: OnnxTaggerOutputActivation.auto,
        recommendedThresholds: {
          OnnxTaggerLabelCategory.general: 0.17,
          OnnxTaggerLabelCategory.character: 0.27,
          OnnxTaggerLabelCategory.copyright: 0.24,
          OnnxTaggerLabelCategory.artist: 0.15,
          OnnxTaggerLabelCategory.meta: 0.17,
          OnnxTaggerLabelCategory.rating: 0.41,
        },
        // 社区导出用到 opset 20 的 Gelu，降 opset 会让图失效
        lowersOpsetImports: false,
      ),
      LocalOnnxModelKind.clTaggerV2 => const OnnxTaggerPreprocessProfile(
        preprocessing: OnnxTaggerPreprocessing.clTaggerV2,
        inputSize: 384,
        outputActivation: OnnxTaggerOutputActivation.sigmoid,
      ),
      LocalOnnxModelKind.clTagger => const OnnxTaggerPreprocessProfile(
        preprocessing: OnnxTaggerPreprocessing.clTagger,
        inputSize: 448,
        outputActivation: OnnxTaggerOutputActivation.auto,
      ),
      LocalOnnxModelKind.animeTimmEva02 => const OnnxTaggerPreprocessProfile(
        preprocessing: OnnxTaggerPreprocessing.animeTimm,
        inputSize: 448,
        outputActivation: OnnxTaggerOutputActivation.sigmoid,
      ),
      LocalOnnxModelKind.wd14Tagger ||
      LocalOnnxModelKind.unknown => OnnxTaggerPreprocessProfile(
        preprocessing: OnnxTaggerPreprocessing.wd14,
        inputSize: _inputSizeFromName(model.name),
        outputActivation: OnnxTaggerOutputActivation.auto,
        layout: OnnxTensorLayout.nhwc,
      ),
    };
  }

  static OnnxImageInput preprocess(
    img.Image source,
    LocalOnnxModelDescriptor model, {
    int? inputSize,
  }) {
    final profile = profileFor(model);
    final size = inputSize ?? profile.inputSize;
    switch (profile.preprocessing) {
      case OnnxTaggerPreprocessing.animeTimm:
        return _preprocessAnimeTimm(source, size);
      case OnnxTaggerPreprocessing.pixaiRescalePad:
        return _preprocessRescalePad(source, size);
      case OnnxTaggerPreprocessing.wd14 ||
          OnnxTaggerPreprocessing.clTagger ||
          OnnxTaggerPreprocessing.clTaggerV2:
        break;
    }

    final resized = _letterbox(
      source,
      size,
      interpolation: img.Interpolation.cubic,
    );
    return switch (profile.preprocessing) {
      OnnxTaggerPreprocessing.clTaggerV2 => _nchwInput(
        resized,
        channelOrder: const [0, 1, 2],
        normalize: (value, _) => value / 127.5 - 1.0,
      ),
      OnnxTaggerPreprocessing.clTagger => _nchwInput(
        resized,
        channelOrder: const [2, 1, 0],
        normalize: (value, _) => value / 255.0,
      ),
      OnnxTaggerPreprocessing.wd14 => _nhwcBgrInput(resized),
      OnnxTaggerPreprocessing.animeTimm ||
      OnnxTaggerPreprocessing.pixaiRescalePad => throw StateError(
        '${profile.preprocessing.name} must use its own resize pipeline',
      ),
    };
  }

  // PixAI 官方 RescalePadProcessor：白底铺平透明 → torchvision 抗锯齿双线性缩放
  // （尺寸向下取整）→ 黑边居中补齐 → (x - 0.5) / 0.5
  static OnnxImageInput _preprocessRescalePad(img.Image source, int inputSize) {
    final layout = computeRescalePadLayout(
      sourceWidth: source.width,
      sourceHeight: source.height,
      inputSize: inputSize,
    );
    final resized = AntialiasedBilinearResampler.resizeRgbToPlanes(
      _flattenOnWhite(source),
      sourceWidth: source.width,
      sourceHeight: source.height,
      targetWidth: layout.resizedWidth,
      targetHeight: layout.resizedHeight,
    );
    final planeSize = layout.canvasPixels;
    final resizedPlaneSize = layout.resizedWidth * layout.resizedHeight;
    final data = Float32List(planeSize * 3)..fillRange(0, planeSize * 3, -1);
    for (var channel = 0; channel < 3; channel++) {
      for (var y = 0; y < layout.resizedHeight; y++) {
        final sourceRow = channel * resizedPlaneSize + y * layout.resizedWidth;
        final targetRow =
            channel * planeSize +
            (y + layout.offsetY) * layout.canvasWidth +
            layout.offsetX;
        for (var x = 0; x < layout.resizedWidth; x++) {
          data[targetRow + x] = resized[sourceRow + x] * 2 - 1;
        }
      }
    }
    return OnnxImageInput(data: data, shape: [1, 3, inputSize, inputSize]);
  }

  static OnnxLetterboxLayout computeRescalePadLayout({
    required int sourceWidth,
    required int sourceHeight,
    required int inputSize,
  }) {
    final ratio = math.min(inputSize / sourceHeight, inputSize / sourceWidth);
    final resizedWidth = (sourceWidth * ratio).toInt().clamp(1, inputSize);
    final resizedHeight = (sourceHeight * ratio).toInt().clamp(1, inputSize);
    return OnnxLetterboxLayout(
      canvasWidth: inputSize,
      canvasHeight: inputSize,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
      offsetX: (inputSize - resizedWidth) ~/ 2,
      offsetY: (inputSize - resizedHeight) ~/ 2,
    );
  }

  static Uint8List _flattenOnWhite(img.Image source) {
    final hasAlpha = source.hasPalette
        ? source.palette!.numChannels > 3
        : source.hasAlpha;
    final channels = hasAlpha ? 4 : 3;
    final rgb8 =
        source.format == img.Format.uint8 &&
            !source.hasPalette &&
            source.numChannels == channels
        ? source
        : source.convert(format: img.Format.uint8, numChannels: channels);
    if (!hasAlpha) return rgb8.getBytes(order: img.ChannelOrder.rgb);

    final rgba = rgb8.getBytes(order: img.ChannelOrder.rgba);
    final pixelCount = source.width * source.height;
    final rgb = Uint8List(pixelCount * 3);
    for (var pixel = 0; pixel < pixelCount; pixel++) {
      final alpha = rgba[pixel * 4 + 3];
      for (var channel = 0; channel < 3; channel++) {
        rgb[pixel * 3 + channel] = _compositeOnWhite(
          rgba[pixel * 4 + channel],
          alpha,
        );
      }
    }
    return rgb;
  }

  // PIL alpha_composite 叠到不透明白底时的整数公式，保证与官方输入逐字节一致
  static int _compositeOnWhite(int value, int alpha) {
    if (alpha == 0) return 255;
    final sourceWeight = alpha << 7;
    final backgroundWeight = (255 << 7) - sourceWeight;
    final blended = value * sourceWeight + 255 * backgroundWeight + (0x80 << 7);
    return (((blended >> 8) + blended) >> 8) >> 7;
  }

  static OnnxImageInput _preprocessAnimeTimm(img.Image source, int inputSize) {
    // AnimeTimm's published pipeline first fits onto a 512px white canvas
    // with bilinear interpolation, then resizes that canvas to 448px bicubic.
    final padded = _letterbox(
      source,
      512,
      interpolation: img.Interpolation.linear,
    );
    final resized = img.copyResize(
      padded,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );
    return _nchwInput(
      resized,
      channelOrder: const [0, 1, 2],
      normalize: (value, channel) =>
          (value / 255.0 - _animeTimmMean[channel]) / _animeTimmStd[channel],
    );
  }

  static img.Image _letterbox(
    img.Image source,
    int inputSize, {
    required img.Interpolation interpolation,
  }) {
    final layout = computeLetterboxLayout(
      sourceWidth: source.width,
      sourceHeight: source.height,
      inputSize: inputSize,
    );
    final resizedSource = img.copyResize(
      source,
      width: layout.resizedWidth,
      height: layout.resizedHeight,
      interpolation: interpolation,
    );
    final canvas = img.Image(
      width: layout.canvasWidth,
      height: layout.canvasHeight,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      resizedSource,
      dstX: layout.offsetX,
      dstY: layout.offsetY,
    );
    return canvas;
  }

  static OnnxImageInput _nchwInput(
    img.Image image, {
    required List<int> channelOrder,
    required double Function(double value, int channel) normalize,
  }) {
    final planeSize = image.width * image.height;
    final data = Float32List(planeSize * 3);
    for (
      var outputChannel = 0;
      outputChannel < channelOrder.length;
      outputChannel++
    ) {
      var offset = outputChannel * planeSize;
      final sourceChannel = channelOrder[outputChannel];
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final value = switch (sourceChannel) {
            0 => pixel.r.toDouble(),
            1 => pixel.g.toDouble(),
            2 => pixel.b.toDouble(),
            _ => throw RangeError.index(sourceChannel, channelOrder),
          };
          data[offset++] = normalize(value, sourceChannel);
        }
      }
    }
    return OnnxImageInput(data: data, shape: [1, 3, image.height, image.width]);
  }

  static OnnxImageInput _nhwcBgrInput(img.Image image) {
    final data = Float32List(image.width * image.height * 3);
    var offset = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        data[offset++] = pixel.b.toDouble();
        data[offset++] = pixel.g.toDouble();
        data[offset++] = pixel.r.toDouble();
      }
    }
    return OnnxImageInput(data: data, shape: [1, image.height, image.width, 3]);
  }

  static int _inputSizeFromName(String modelName) {
    final match = RegExp(
      r'(?:^|[^0-9])(224|256|384|448|512)(?:[^0-9]|$)',
    ).firstMatch(modelName.toLowerCase());
    return match == null ? defaultInputSize : int.parse(match.group(1)!);
  }

  static OnnxLetterboxLayout computeLetterboxLayout({
    required int sourceWidth,
    required int sourceHeight,
    required int inputSize,
  }) {
    final longestSide = math.max(1, math.max(sourceWidth, sourceHeight));
    final scale = inputSize / longestSide;
    final resizedWidth = math.max(1, (sourceWidth * scale).round());
    final resizedHeight = math.max(1, (sourceHeight * scale).round());
    return OnnxLetterboxLayout(
      canvasWidth: inputSize,
      canvasHeight: inputSize,
      resizedWidth: math.min(inputSize, resizedWidth),
      resizedHeight: math.min(inputSize, resizedHeight),
      offsetX: (inputSize - resizedWidth) ~/ 2,
      offsetY: (inputSize - resizedHeight) ~/ 2,
    );
  }
}
