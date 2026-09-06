import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'dlss_options.dart';
import 'dlss_float_frame.dart';
import '../metadata/image_metadata_container_codec.dart';

class DlssWorker {
  DlssWorker({String? executable}) : _executable = executable;
  final String? _executable;
  Future<void> probe(Directory runtime, {int adapter = 0}) async {
    final sample = img.Image(width: 256, height: 256, numChannels: 4);
    for (final pixel in sample) {
      pixel.setRgba(pixel.x, pixel.y, (pixel.x * 7 + pixel.y * 3) % 256, 255);
    }
    final source = Uint8List.fromList(img.encodePng(sample));
    final result = await run(
      runtime,
      source,
      const DlssOptions(scale: 1),
      adapter: adapter,
    );
    final output = img.decodePng(result)!;
    if (!sample.any((pixel) {
      final other = output.getPixel(pixel.x, pixel.y);
      return pixel.r != other.r || pixel.g != other.g || pixel.b != other.b;
    })) {
      throw StateError('DLSS probe returned an unchanged image');
    }
  }

  Future<Uint8List> run(
    Directory runtime,
    Uint8List source,
    DlssOptions options, {
    int adapter = 0,
    Future<void>? cancelled,
    String? version,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (!Platform.isWindows) throw UnsupportedError('DLSS requires Windows');
    final size = img.findDecoderForData(source)?.startDecode(source);
    if (size == null) throw const FormatException('Invalid DLSS source image');
    final target = options.targetSize(size.width, size.height);
    final job = await runtime.absolute.createTemp('.job-');
    final input = File(p.join(job.path, 'input.aaf'));
    final baseline = File(p.join(job.path, 'baseline.aaf'));
    final output = File(p.join(job.path, 'output.aaf'));
    Process? process;
    var wasCancelled = false;
    var finished = false;
    try {
      await input.writeAsBytes(await _encodeInIsolate(source), flush: true);
      if (cancelled != null) {
        unawaited(
          cancelled.then((_) {
            if (!finished) {
              wasCancelled = true;
              process?.kill();
            }
          }),
        );
      }
      if (wasCancelled) throw const DlssCancelled();
      process = await Process.start(
        _executable ??
            p.join(
              p.dirname(Platform.resolvedExecutable),
              'aaalice_dlss_worker.exe',
            ),
        [
          '--runtime',
          runtime.absolute.path,
          '--input',
          input.path,
          '--output',
          output.path,
          '--baseline',
          baseline.path,
          '--width',
          '${target.$1}',
          '--height',
          '${target.$2}',
          '--adapter',
          '$adapter',
          ...options.arguments,
        ],
      );
      if (wasCancelled) process.kill();
      final protocol = DlssWorkerProtocol(options.passes, onProgress);
      final stdout = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) {
            protocol.accept(line);
            return line;
          })
          .join('\n');
      final stderr = process.stderr.transform(utf8.decoder).join();
      final exit = await process.exitCode.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          process?.kill();
          throw TimeoutException('DLSS worker timed out');
        },
      );
      final log = '${await stdout}\n${await stderr}';
      if (wasCancelled) throw const DlssCancelled();
      if (exit != 0 || !protocol.complete) {
        throw DlssWorkerFailure(exit, log);
      }
      final bytes = await _composeInIsolate(
        source,
        await baseline.readAsBytes(),
        await output.readAsBytes(),
        options,
        version,
      );
      if (wasCancelled) throw const DlssCancelled();
      return bytes;
    } finally {
      finished = true;
      if (process != null) {
        process.kill();
        await process.exitCode;
      }
      await job.delete(recursive: true);
    }
  }
}

/// Reject incomplete, repeated or out-of-order native progress even on exit 0.
class DlssWorkerProtocol {
  DlssWorkerProtocol(this.total, this.onProgress);
  final int total;
  final void Function(int, int)? onProgress;
  int _completed = -1;
  bool _invalid = false;
  bool _done = false;
  bool get complete => !_invalid && _done && _completed == total;

  void accept(String line) {
    if (line.startsWith('AAALICE_NR_PROGRESS')) {
      final match = RegExp(
        r'^AAALICE_NR_PROGRESS (\d+) (\d+)$',
      ).firstMatch(line);
      if (match == null ||
          _done ||
          int.parse(match[2]!) != total ||
          int.parse(match[1]!) != _completed + 1 ||
          _completed >= total) {
        _invalid = true;
        return;
      }
      _completed++;
      onProgress?.call(_completed, total);
    } else if (line.startsWith('AAALICE_NR_DONE')) {
      if (line != 'AAALICE_NR_DONE $total fp16-cascade' ||
          _completed != total ||
          _done) {
        _invalid = true;
      }
      _done = true;
    }
  }
}

Future<Uint8List> _encodeInIsolate(Uint8List source) =>
    Isolate.run(() => DlssFloatFrame.fromImage(source).encode());

Future<Uint8List> _composeInIsolate(
  Uint8List source,
  Uint8List baseline,
  Uint8List neural,
  DlssOptions options,
  String? version,
) => Isolate.run(() {
  final output = DlssFloatFrame.decode(baseline).composite(
    DlssFloatFrame.decode(neural),
    detail: options.detail,
    color: options.color,
  );
  return preserveDlssImage(source, output, options, version);
});

class DlssCancelled implements Exception {
  const DlssCancelled();
  @override
  String toString() =>
      'DLSS enhancement was cancelled; the original is retained';
}

class DlssWorkerFailure implements Exception {
  const DlssWorkerFailure(this.exitCode, this.diagnostics);
  final int exitCode;
  final String diagnostics;
  bool get resourceLimited {
    final log = diagnostics.toLowerCase();
    return log.contains('out of memory') || log.contains('8007000e');
  }

  bool get requiresRecheck => !resourceLimited;
  @override
  String toString() => 'DLSS worker exited $exitCode\n$diagnostics';
}

/// Restore original alpha and metadata before the single final PNG encoding.
Uint8List preserveDlssImage(
  Uint8List sourceBytes,
  img.Image decoded,
  DlssOptions options,
  String? version,
) {
  if (sourceBytes.isEmpty) {
    throw const FormatException('Invalid DLSS image: empty source');
  }
  final source = img.decodeImage(sourceBytes);
  if (source == null) {
    throw const FormatException('Invalid DLSS image');
  }
  final expected = options.targetSize(source.width, source.height);
  if (expected.$1 != decoded.width || expected.$2 != decoded.height) {
    throw FormatException(
      'Unexpected DLSS image dimensions: expected ${expected.$1}x${expected.$2}, got ${decoded.width}x${decoded.height}',
    );
  }
  final alphaSource =
      source.width == decoded.width && source.height == decoded.height
      ? source
      : img.copyResize(
          source,
          width: decoded.width,
          height: decoded.height,
          interpolation: img.Interpolation.linear,
        );
  final output = decoded.convert(numChannels: 4);
  for (final pixel in output) {
    pixel.a = alphaSource.getPixel(pixel.x, pixel.y).a;
  }
  output.exif = source.exif;
  output.iccProfile = source.iccProfile;
  final withMetadata = ImageMetadataContainerCodec.copySupportedMetadata(
    source: sourceBytes,
    targetPng: Uint8List.fromList(img.encodePng(output)),
  );
  return ImageMetadataContainerCodec.embedTextChunkOnly(
    withMetadata,
    'Aaalice.DLSS',
    jsonEncode({'status': 'success', 'runtime': version, ...options.toJson()}),
  );
}
