import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'dlss_options.dart';
import '../metadata/image_metadata_container_codec.dart';

class DlssWorker {
  Future<void> probe(Directory runtime, {int adapter = 0}) async {
    final sample = img.Image(width: 256, height: 256, numChannels: 4);
    for (final pixel in sample) {
      pixel.setRgba(pixel.x, pixel.y, (pixel.x * 7 + pixel.y * 3) % 256, 255);
    }
    final source = Uint8List.fromList(img.encodePng(sample));
    final result = await run(
      runtime,
      source,
      const DlssOptions(),
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
  }) async {
    if (!Platform.isWindows) throw UnsupportedError('DLSS requires Windows');
    final directory = runtime.absolute;
    final job = await directory.createTemp('.job-');
    final input = File(p.join(job.path, 'input.png'));
    final output = Directory(p.join(job.path, 'output'));
    Process? process;
    var wasCancelled = false;
    var finished = false;
    try {
      await input.writeAsBytes(source, flush: true);
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
      // A temporary working directory stays locked by the Windows graphics
      // process lifecycle after exit. Absolute paths let installation rename
      // the probed directory without retaining that working-directory handle.
      process =
          await Process.start(p.join(directory.path, 'video2dlssnr.exe'), [
            '--nr-run',
            '--in',
            input.path,
            '--out',
            output.path,
            '--adapter',
            '$adapter',
            ...options.arguments,
          ]);
      if (wasCancelled) process.kill();
      final stdout = process.stdout.transform(utf8.decoder).join();
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
      if (exit != 0 || !log.contains('Neural Rendering done: 1 ok, 0 failed')) {
        throw DlssWorkerFailure(exit, log);
      }
      final file = File(p.join(output.path, 'input.png_nr.png'));
      final bytes = await file.readAsBytes();
      return await _preserveInIsolate(source, bytes, options, version);
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

Future<Uint8List> _preserveInIsolate(
  Uint8List source,
  Uint8List output,
  DlssOptions options,
  String? version,
) => Isolate.run(() => preserveDlssImage(source, output, options, version));

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

/// The upstream PNG writer discards alpha. Restore the source channel exactly.
Uint8List preserveDlssImage(
  Uint8List sourceBytes,
  Uint8List outputBytes,
  DlssOptions options,
  String? version,
) {
  if (!ImageMetadataContainerCodec.isPngHeader(outputBytes)) {
    throw const FormatException('DLSS did not produce a PNG');
  }
  final source = img.decodeImage(sourceBytes);
  final decoded = img.decodePng(outputBytes);
  if (source == null || decoded == null) {
    throw const FormatException('Invalid DLSS image');
  }
  if (source.width != decoded.width || source.height != decoded.height) {
    throw const FormatException('DLSS changed image dimensions');
  }
  final output = decoded.convert(numChannels: 4);
  for (final pixel in output) {
    pixel.a = source.getPixel(pixel.x, pixel.y).a;
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
