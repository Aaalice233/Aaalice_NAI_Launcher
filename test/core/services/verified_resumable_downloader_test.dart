import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/verified_resumable_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VerifiedResumableDownloader', () {
    late Directory tempDirectory;
    late List<HttpServer> servers;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'verified_downloader_test_',
      );
      servers = [];
    });

    tearDown(() async {
      for (final server in servers) {
        await server.close(force: true);
      }
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    Future<Uri> serve(
      FutureOr<void> Function(HttpRequest request) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servers.add(server);
      server.listen(handler);
      return Uri.parse('http://127.0.0.1:${server.port}/payload.bin');
    }

    test('downloads a fresh 200 response and verifies its contents', () async {
      final payload = _payload(48 * 1024);
      String? acceptEncoding;
      String? range;
      final uri = await serve((request) async {
        acceptEncoding = request.headers.value(
          HttpHeaders.acceptEncodingHeader,
        );
        range = request.headers.value(HttpHeaders.rangeHeader);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
        await request.response.close();
      });
      final target = File(p.join(tempDirectory.path, 'fresh.bin'));
      final progress = <VerifiedDownloadProgress>[];

      final result = await VerifiedResumableDownloader(dio: Dio()).download(
        uri: uri,
        targetFile: target,
        expectedSize: payload.length,
        expectedSha256: _sha256(payload),
        onProgress: progress.add,
      );

      expect(await target.readAsBytes(), payload);
      expect(result.reusedExistingFile, isFalse);
      expect(result.length, payload.length);
      expect(range, isNull);
      expect(acceptEncoding, 'identity');
      expect(progress.last.receivedBytes, payload.length);
      expect(progress.last.progress, 1);
      expect(await File('${target.path}.part').exists(), isFalse);
    });

    test('resumes a partial file from a valid 206 response', () async {
      final payload = _payload(96 * 1024);
      const existingLength = 27 * 1024;
      final ranges = <String?>[];
      final uri = await serve((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        final start = int.parse(
          range!.substring('bytes='.length).split('-').first,
        );
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-${payload.length - 1}/${payload.length}',
          )
          ..headers.contentLength = payload.length - start
          ..add(payload.sublist(start));
        await request.response.close();
      });
      final target = File(p.join(tempDirectory.path, 'resumed.bin'));
      await File(
        '${target.path}.part',
      ).writeAsBytes(payload.take(existingLength).toList());

      await VerifiedResumableDownloader(dio: Dio()).download(
        uri: uri,
        targetFile: target,
        expectedSize: payload.length,
        expectedSha256: _sha256(payload),
      );

      expect(ranges, ['bytes=$existingLength-']);
      expect(await target.readAsBytes(), payload);
    });

    test('restarts safely when the server ignores Range with 200', () async {
      final payload = _payload(32 * 1024);
      const existingLength = 4096;
      final ranges = <String?>[];
      final uri = await serve((request) async {
        ranges.add(request.headers.value(HttpHeaders.rangeHeader));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
        await request.response.close();
      });
      final target = File(p.join(tempDirectory.path, 'ignored-range.bin'));
      await File(
        '${target.path}.part',
      ).writeAsBytes(payload.take(existingLength).toList());

      await VerifiedResumableDownloader(dio: Dio()).download(
        uri: uri,
        targetFile: target,
        expectedSize: payload.length,
        expectedSha256: _sha256(payload),
      );

      expect(ranges, ['bytes=$existingLength-']);
      expect(await target.readAsBytes(), payload);
      expect(await target.length(), payload.length);
    });

    test(
      'recovers from 416 by discarding the stale part and retrying',
      () async {
        final payload = _payload(24 * 1024);
        const existingLength = 6000;
        final ranges = <String?>[];
        final uri = await serve((request) async {
          final range = request.headers.value(HttpHeaders.rangeHeader);
          ranges.add(range);
          if (range != null) {
            request.response.statusCode =
                HttpStatus.requestedRangeNotSatisfiable;
          } else {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentLength = payload.length
              ..add(payload);
          }
          await request.response.close();
        });
        final target = File(p.join(tempDirectory.path, 'range-416.bin'));
        await File(
          '${target.path}.part',
        ).writeAsBytes(payload.take(existingLength).toList());

        await VerifiedResumableDownloader(dio: Dio()).download(
          uri: uri,
          targetFile: target,
          expectedSize: payload.length,
          expectedSha256: _sha256(payload),
        );

        expect(ranges, ['bytes=$existingLength-', null]);
        expect(await target.readAsBytes(), payload);
      },
    );

    test(
      'cancellation preserves the part and the next call resumes it',
      () async {
        final payload = _payload(128 * 1024);
        final ranges = <String?>[];
        final uri = await serve((request) async {
          final range = request.headers.value(HttpHeaders.rangeHeader);
          ranges.add(range);
          final start = range == null
              ? 0
              : int.parse(range.substring('bytes='.length).split('-').first);
          request.response.statusCode = range == null
              ? HttpStatus.ok
              : HttpStatus.partialContent;
          if (range != null) {
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-${payload.length - 1}/${payload.length}',
            );
          }
          request.response.headers.contentLength = payload.length - start;
          try {
            for (var offset = start; offset < payload.length; offset += 4096) {
              final end = (offset + 4096).clamp(0, payload.length);
              request.response.add(payload.sublist(offset, end));
              await request.response.flush();
              await Future<void>.delayed(const Duration(milliseconds: 2));
            }
            await request.response.close();
          } on Object {
            // Cancellation closes the first client connection mid-response.
          }
        });
        final target = File(p.join(tempDirectory.path, 'cancel-resume.bin'));
        final cancelToken = CancelToken();
        var cancelled = false;
        final downloader = VerifiedResumableDownloader(dio: Dio());

        final firstDownload = downloader.download(
          uri: uri,
          targetFile: target,
          expectedSize: payload.length,
          expectedSha256: _sha256(payload),
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (!cancelled && progress.receivedBytes >= 16 * 1024) {
              cancelled = true;
              cancelToken.cancel('pause');
            }
          },
        );

        await expectLater(
          firstDownload,
          throwsA(isA<VerifiedDownloadCancelledException>()),
        );
        final part = File('${target.path}.part');
        expect(await part.exists(), isTrue);
        final partialLength = await part.length();
        expect(partialLength, inExclusiveRange(0, payload.length));

        await downloader.download(
          uri: uri,
          targetFile: target,
          expectedSize: payload.length,
          expectedSha256: _sha256(payload),
        );

        expect(ranges.first, isNull);
        expect(ranges.last, 'bytes=$partialLength-');
        expect(await target.readAsBytes(), payload);
      },
    );

    test('deletes an incomplete part after a size mismatch', () async {
      final payload = _payload(12 * 1024);
      final truncated = payload.take(payload.length - 17).toList();
      final uri = await serve((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..add(truncated);
        await request.response.close();
      });
      final target = File(p.join(tempDirectory.path, 'truncated.bin'));

      await expectLater(
        VerifiedResumableDownloader(dio: Dio()).download(
          uri: uri,
          targetFile: target,
          expectedSize: payload.length,
          expectedSha256: _sha256(payload),
        ),
        throwsA(
          isA<VerifiedDownloadException>().having(
            (error) => error.failure,
            'failure',
            VerifiedDownloadFailure.sizeMismatch,
          ),
        ),
      );

      expect(await target.exists(), isFalse);
      expect(await File('${target.path}.part').exists(), isFalse);
    });

    test('deletes a complete part after a checksum mismatch', () async {
      final payload = _payload(10 * 1024);
      final uri = await serve((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
        await request.response.close();
      });
      final target = File(p.join(tempDirectory.path, 'bad-hash.bin'));
      final wrongHash = _sha256(List<int>.filled(payload.length, 7));

      await expectLater(
        VerifiedResumableDownloader(dio: Dio()).download(
          uri: uri,
          targetFile: target,
          expectedSize: payload.length,
          expectedSha256: wrongHash,
        ),
        throwsA(
          isA<VerifiedDownloadException>().having(
            (error) => error.failure,
            'failure',
            VerifiedDownloadFailure.checksumMismatch,
          ),
        ),
      );

      expect(await target.exists(), isFalse);
      expect(await File('${target.path}.part').exists(), isFalse);
    });
  });
}

List<int> _payload(int length) =>
    List<int>.generate(length, (index) => (index * 31 + 17) % 251);

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
