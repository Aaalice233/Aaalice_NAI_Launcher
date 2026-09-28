import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'local_onnx_model_service.dart';

enum OnnxTaggerPreprocessing { wd14, clTagger, clTaggerV2, animeTimm }

enum OnnxTaggerOutputActivation { auto, sigmoid }

class OnnxTaggerPreprocessProfile {
  const OnnxTaggerPreprocessProfile({
    required this.preprocessing,
    required this.inputSize,
    required this.outputActivation,
  });

  final OnnxTaggerPreprocessing preprocessing;
  final int inputSize;
  final OnnxTaggerOutputActivation outputActivation;

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
      ),
    };
  }

  static OnnxImageInput preprocess(
    img.Image source,
    LocalOnnxModelDescriptor model,
  ) {
    final profile = profileFor(model);
    if (profile.preprocessing == OnnxTaggerPreprocessing.animeTimm) {
      return _preprocessAnimeTimm(source, profile.inputSize);
    }

    final resized = _letterbox(
      source,
      profile.inputSize,
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
      OnnxTaggerPreprocessing.animeTimm => throw StateError(
        'AnimeTimm preprocessing must use its official resize pipeline',
      ),
    };
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
