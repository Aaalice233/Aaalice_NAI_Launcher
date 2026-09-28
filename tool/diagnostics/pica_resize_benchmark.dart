import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/pica_lanczos_resizer.dart';

/// Non-CI resize benchmark for the Pica port and the previous local Lanczos3.
///
/// Compile this file before recording release measurements:
///
///   dart compile exe tool/diagnostics/pica_resize_benchmark.dart \
///     -o C:\tmp\pica_resize_benchmark.exe
///   C:\tmp\pica_resize_benchmark.exe --iterations=3
///
/// Each sample runs in a fresh isolate so the large source buffer is released
/// between algorithms. Timings cover resize work only, not fixture generation.
Future<void> main(List<String> arguments) async {
  final options = _BenchmarkOptions.parse(arguments);
  final selectedCases = _cases.where(
    (testCase) => options.caseName == null || testCase.name == options.caseName,
  );
  if (selectedCases.isEmpty) {
    stderr.writeln('Unknown case: ${options.caseName}');
    exitCode = 64;
    return;
  }

  stdout.writeln(
    'Pica Lanczos3 benchmark | iterations=${options.iterations} '
    '| build=ae6a6aa-production (2026-07-16)',
  );
  for (final testCase in selectedCases) {
    stdout.writeln('\n${testCase.description}');
    await _printMeasurement(
      testCase,
      algorithm: _ResizeAlgorithm.pica,
      iterations: options.iterations,
    );
    if (!options.picaOnly) {
      await _printMeasurement(
        testCase,
        algorithm: _ResizeAlgorithm.legacyLanczos3,
        iterations: options.iterations,
      );
    }
  }
}

Future<void> _printMeasurement(
  _BenchmarkCase testCase, {
  required _ResizeAlgorithm algorithm,
  required int iterations,
}) async {
  final samples = <_BenchmarkSample>[];
  for (var iteration = 0; iteration < iterations; iteration++) {
    samples.add(
      await Isolate.run(() => _runSample(testCase, algorithm: algorithm)),
    );
  }

  final elapsed = samples.map((sample) => sample.elapsedMicros).toList()
    ..sort();
  final maxRss = samples.map((sample) => sample.rssAfterBytes).reduce(math.max);
  final maxRssDelta = samples
      .map((sample) => sample.rssDeltaBytes)
      .reduce(math.max);
  final checksum = samples.last.checksum;
  stdout.writeln(
    '  ${algorithm.label.padRight(18)} median='
    '${_formatDuration(elapsed[elapsed.length ~/ 2])} '
    'rss_after<=${_formatBytes(maxRss)} '
    'rss_delta<=${_formatBytes(maxRssDelta)} checksum=$checksum',
  );
}

_BenchmarkSample _runSample(
  _BenchmarkCase testCase, {
  required _ResizeAlgorithm algorithm,
}) {
  final source = _makeFixture(testCase);
  final rssBefore = ProcessInfo.currentRss;
  final stopwatch = Stopwatch()..start();
  var result = algorithm.resize(
    source,
    width: testCase.targetWidth,
    height: testCase.targetHeight,
  );
  if (testCase.roundTrip) {
    result = algorithm.resize(
      result,
      width: testCase.sourceWidth,
      height: testCase.sourceHeight,
    );
  }
  stopwatch.stop();
  final rssAfter = ProcessInfo.currentRss;
  return _BenchmarkSample(
    elapsedMicros: stopwatch.elapsedMicroseconds,
    rssAfterBytes: rssAfter,
    rssDeltaBytes: math.max(0, rssAfter - rssBefore),
    checksum: _sampleChecksum(result),
  );
}

img.Image _makeFixture(_BenchmarkCase testCase) {
  final image = img.Image(
    width: testCase.sourceWidth,
    height: testCase.sourceHeight,
    numChannels: 4,
  );
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 17 + y * 29) & 0xff,
        (x * 43 + y * 11) & 0xff,
        (x * 7 + y * 61) & 0xff,
        testCase.hasAlpha ? ((x * 13 + y * 19) & 0xff) : 255,
      );
    }
  }
  return image;
}

int _sampleChecksum(img.Image image) {
  var checksum = 0;
  const sampleCount = 1024;
  for (var index = 0; index < sampleCount; index++) {
    final x = (index * 7919) % image.width;
    final y = (index * 104729) % image.height;
    final pixel = image.getPixel(x, y);
    checksum =
        (checksum * 31 +
            pixel.r.toInt() * 17 +
            pixel.g.toInt() * 13 +
            pixel.b.toInt() * 7 +
            pixel.a.toInt()) &
        0x7fffffff;
  }
  return checksum;
}

String _formatDuration(int microseconds) {
  if (microseconds >= Duration.microsecondsPerSecond) {
    return '${(microseconds / Duration.microsecondsPerSecond).toStringAsFixed(2)}s';
  }
  return '${(microseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(1)}ms';
}

String _formatBytes(int bytes) {
  const mib = 1024 * 1024;
  return '${(bytes / mib).toStringAsFixed(1)}MiB';
}

enum _ResizeAlgorithm {
  pica('Pica Lanczos3'),
  legacyLanczos3('Legacy Lanczos3');

  const _ResizeAlgorithm(this.label);

  final String label;

  img.Image resize(
    img.Image source, {
    required int width,
    required int height,
  }) {
    return switch (this) {
      _ResizeAlgorithm.pica => PicaLanczosResizer.resizeImage(
        source,
        width: width,
        height: height,
      ),
      _ResizeAlgorithm.legacyLanczos3 => _LegacyLanczos3.resize(
        source,
        width: width,
        height: height,
      ),
    };
  }
}

class _LegacyLanczos3 {
  const _LegacyLanczos3._();

  static img.Image resize(
    img.Image source, {
    required int width,
    required int height,
  }) {
    if (source.width == width && source.height == height) {
      return source.clone();
    }

    final target = img.Image(
      width: width,
      height: height,
      numChannels: source.hasAlpha ? 4 : 3,
    );
    final xContributions = _buildContributions(source.width, width);
    final yContributions = _buildContributions(source.height, height);
    for (var y = 0; y < height; y++) {
      final ySamples = yContributions[y];
      for (var x = 0; x < width; x++) {
        final xSamples = xContributions[x];
        var red = 0.0;
        var green = 0.0;
        var blue = 0.0;
        var alpha = 0.0;
        for (final ySample in ySamples) {
          for (final xSample in xSamples) {
            final weight = xSample.weight * ySample.weight;
            final pixel = source.getPixel(xSample.index, ySample.index);
            red += pixel.r * weight;
            green += pixel.g * weight;
            blue += pixel.b * weight;
            alpha += pixel.a * weight;
          }
        }
        target.setPixelRgba(
          x,
          y,
          _clampChannel(red),
          _clampChannel(green),
          _clampChannel(blue),
          _clampChannel(alpha),
        );
      }
    }
    return target;
  }

  static List<List<_LanczosSample>> _buildContributions(
    int sourceSize,
    int targetSize,
  ) {
    final scale = sourceSize / targetSize;
    return List.generate(targetSize, (targetIndex) {
      final sourcePosition = (targetIndex + 0.5) * scale - 0.5;
      final sampleStart = (sourcePosition - 3).ceil();
      final sampleEnd = (sourcePosition + 3).floor();
      final samples = <_LanczosSample>[];
      var totalWeight = 0.0;
      for (var sample = sampleStart; sample <= sampleEnd; sample++) {
        final weight = _lanczos3(sourcePosition - sample);
        if (weight == 0) continue;
        samples.add(_LanczosSample(sample.clamp(0, sourceSize - 1), weight));
        totalWeight += weight;
      }
      if (totalWeight.abs() < 1e-12) {
        return [
          _LanczosSample(sourcePosition.round().clamp(0, sourceSize - 1), 1),
        ];
      }
      return [
        for (final sample in samples)
          _LanczosSample(sample.index, sample.weight / totalWeight),
      ];
    });
  }

  static double _lanczos3(double value) {
    final distance = value.abs();
    if (distance == 0) return 1;
    if (distance >= 3) return 0;
    return _sinc(distance) * _sinc(distance / 3);
  }

  static double _sinc(double value) {
    if (value == 0) return 1;
    final radians = math.pi * value;
    return math.sin(radians) / radians;
  }

  static int _clampChannel(double value) {
    if (value.isNaN) return 0;
    return value.round().clamp(0, 255);
  }
}

class _LanczosSample {
  const _LanczosSample(this.index, this.weight);

  final int index;
  final double weight;
}

class _BenchmarkCase {
  const _BenchmarkCase({
    required this.name,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.targetWidth,
    required this.targetHeight,
    this.hasAlpha = false,
    this.roundTrip = false,
  });

  final String name;
  final int sourceWidth;
  final int sourceHeight;
  final int targetWidth;
  final int targetHeight;
  final bool hasAlpha;
  final bool roundTrip;

  String get description {
    final suffix = roundTrip
        ? ' -> ${sourceWidth}x$sourceHeight (alpha round trip)'
        : '';
    return '$name: ${sourceWidth}x$sourceHeight -> '
        '${targetWidth}x$targetHeight$suffix';
  }
}

class _BenchmarkSample {
  const _BenchmarkSample({
    required this.elapsedMicros,
    required this.rssAfterBytes,
    required this.rssDeltaBytes,
    required this.checksum,
  });

  final int elapsedMicros;
  final int rssAfterBytes;
  final int rssDeltaBytes;
  final int checksum;
}

class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.iterations,
    required this.picaOnly,
    this.caseName,
  });

  final int iterations;
  final bool picaOnly;
  final String? caseName;

  static _BenchmarkOptions parse(List<String> arguments) {
    var iterations = 3;
    var picaOnly = false;
    String? caseName;
    for (final argument in arguments) {
      if (argument == '--pica-only') {
        picaOnly = true;
      } else if (argument.startsWith('--iterations=')) {
        iterations = int.parse(argument.substring('--iterations='.length));
      } else if (argument.startsWith('--case=')) {
        caseName = argument.substring('--case='.length);
      }
    }
    if (iterations <= 0 || iterations.isEven) {
      throw ArgumentError('--iterations must be a positive odd number.');
    }
    return _BenchmarkOptions(
      iterations: iterations,
      picaOnly: picaOnly,
      caseName: caseName,
    );
  }
}

const _cases = [
  _BenchmarkCase(
    name: 'large-square',
    sourceWidth: 4096,
    sourceHeight: 4096,
    targetWidth: 896,
    targetHeight: 896,
  ),
  _BenchmarkCase(
    name: 'large-landscape',
    sourceWidth: 8000,
    sourceHeight: 6000,
    targetWidth: 1216,
    targetHeight: 896,
  ),
  _BenchmarkCase(
    name: 'ceil64-near-2560',
    sourceWidth: 2559,
    sourceHeight: 1439,
    targetWidth: 2560,
    targetHeight: 1472,
  ),
  _BenchmarkCase(
    name: 'focus-alpha-round-trip',
    sourceWidth: 2048,
    sourceHeight: 1536,
    targetWidth: 1024,
    targetHeight: 768,
    hasAlpha: true,
    roundTrip: true,
  ),
];
