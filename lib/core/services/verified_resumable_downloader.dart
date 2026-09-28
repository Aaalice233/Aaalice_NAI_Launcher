import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Why a verified download failed. Callers map this to domain-specific copy.
enum VerifiedDownloadFailure {
  invalidRequest,
  http,
  rangeRejected,
  emptyResponse,
  network,
  fileSystem,
  diskFull,
  sizeMismatch,
  checksumMismatch,
}

class VerifiedDownloadException implements Exception {
  const VerifiedDownloadException(
    this.failure,
    this.message, {
    this.statusCode,
    this.host,
    this.downloadedBytes,
    this.originalError,
  });

  final VerifiedDownloadFailure failure;
  final String message;
  final int? statusCode;
  final String? host;
  final int? downloadedBytes;
  final Object? originalError;

  @override
  String toString() {
    final details = <String>[
      if (statusCode != null) 'status=$statusCode',
      if (host != null) 'host=$host',
      if (downloadedBytes != null) 'downloaded=$downloadedBytes',
      if (originalError != null) 'cause=$originalError',
    ];
    return 'VerifiedDownloadException: $message'
        '${details.isEmpty ? '' : ' (${details.join(', ')})'}';
  }
}

class VerifiedDownloadCancelledException implements Exception {
  const VerifiedDownloadCancelledException();

  @override
  String toString() => 'VerifiedDownloadCancelledException';
}

typedef VerifiedSha256Calculator = Future<String> Function(File file);

class VerifiedDownloadProgress {
  const VerifiedDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    required this.bytesPerSecond,
  });

  final int receivedBytes;
  final int totalBytes;
  final double progress;
  final int bytesPerSecond;
}

class VerifiedDownloadResult {
  const VerifiedDownloadResult({
    required this.file,
    required this.length,
    required this.reusedExistingFile,
  });

  final File file;
  final int length;
  final bool reusedExistingFile;
}

/// Downloads one immutable file with resumable Range requests and verifies both
/// its declared byte length and SHA256 digest before exposing the final path.
class VerifiedResumableDownloader {
  VerifiedResumableDownloader({
    required Dio dio,
    VerifiedSha256Calculator? sha256Calculator,
  }) : _dio = dio,
       _sha256Calculator = sha256Calculator ?? calculateSha256;

  static const Duration _speedSampleWindow = Duration(milliseconds: 500);
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 60);

  final Dio _dio;
  final VerifiedSha256Calculator _sha256Calculator;
  final Map<String, Future<VerifiedDownloadResult>> _activeDownloads = {};

  Future<VerifiedDownloadResult> download({
    required Uri uri,
    required File targetFile,
    required int expectedSize,
    required String expectedSha256,
    void Function(VerifiedDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) {
    _validateRequest(uri, expectedSize, expectedSha256);
    final key = targetFile.absolute.path;
    final active = _activeDownloads[key];
    if (active != null) return active;
    final future = _download(
      uri: uri,
      targetFile: targetFile,
      expectedSize: expectedSize,
      expectedSha256: expectedSha256,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    _activeDownloads[key] = future;
    unawaited(
      future.then<void>(
        (_) {
          _activeDownloads.remove(key);
        },
        onError: (Object _, StackTrace _) {
          _activeDownloads.remove(key);
        },
      ),
    );
    return future;
  }

  Future<bool> isValid({
    required File file,
    required int expectedSize,
    required String expectedSha256,
  }) async {
    if (!await file.exists() || await file.length() != expectedSize) {
      return false;
    }
    return equalsSha256(await _sha256Calculator(file), expectedSha256);
  }

  Future<VerifiedDownloadResult> _download({
    required Uri uri,
    required File targetFile,
    required int expectedSize,
    required String expectedSha256,
    required void Function(VerifiedDownloadProgress progress)? onProgress,
    required CancelToken? cancelToken,
  }) async {
    await targetFile.parent.create(recursive: true);
    _throwIfCancelled(cancelToken);

    if (await targetFile.exists()) {
      final valid = await isValid(
        file: targetFile,
        expectedSize: expectedSize,
        expectedSha256: expectedSha256,
      );
      _throwIfCancelled(cancelToken);
      if (valid) {
        onProgress?.call(
          VerifiedDownloadProgress(
            receivedBytes: expectedSize,
            totalBytes: expectedSize,
            progress: 1,
            bytesPerSecond: 0,
          ),
        );
        return VerifiedDownloadResult(
          file: targetFile,
          length: expectedSize,
          reusedExistingFile: true,
        );
      }
      await _deleteQuietly(targetFile);
    }

    final partFile = File('${targetFile.path}.part');
    try {
      await _downloadToPartFile(
        uri: uri,
        partFile: partFile,
        expectedSize: expectedSize,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      _throwIfCancelled(cancelToken);
      final fileLength = await partFile.length();
      _throwIfCancelled(cancelToken);
      if (fileLength != expectedSize) {
        await _deleteQuietly(partFile);
        throw VerifiedDownloadException(
          VerifiedDownloadFailure.sizeMismatch,
          'Downloaded file size does not match the manifest',
          host: uri.host,
          downloadedBytes: fileLength,
          originalError: 'expected=$expectedSize actual=$fileLength',
        );
      }
      final actualSha256 = await _sha256Calculator(partFile);
      _throwIfCancelled(cancelToken);
      if (!equalsSha256(actualSha256, expectedSha256)) {
        await _deleteQuietly(partFile);
        throw VerifiedDownloadException(
          VerifiedDownloadFailure.checksumMismatch,
          'Downloaded file checksum does not match the manifest',
          host: uri.host,
          downloadedBytes: fileLength,
          originalError: 'expected=$expectedSha256 actual=$actualSha256',
        );
      }

      // The final cancellation check deliberately occurs before this commit
      // boundary. Once rename succeeds, every caller observes a valid file.
      await partFile.rename(targetFile.path);
      onProgress?.call(
        VerifiedDownloadProgress(
          receivedBytes: fileLength,
          totalBytes: expectedSize,
          progress: 1,
          bytesPerSecond: 0,
        ),
      );
      return VerifiedDownloadResult(
        file: targetFile,
        length: fileLength,
        reusedExistingFile: false,
      );
    } on VerifiedDownloadCancelledException {
      rethrow;
    } on VerifiedDownloadException {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const VerifiedDownloadCancelledException();
      }
      throw VerifiedDownloadException(
        VerifiedDownloadFailure.network,
        'Download request failed',
        statusCode: error.response?.statusCode,
        host: uri.host,
        downloadedBytes: await _safeLength(partFile),
        originalError: error,
      );
    } on FileSystemException catch (error) {
      throw VerifiedDownloadException(
        _isDiskFull(error)
            ? VerifiedDownloadFailure.diskFull
            : VerifiedDownloadFailure.fileSystem,
        _isDiskFull(error)
            ? 'Disk space is insufficient'
            : 'Unable to write the downloaded file',
        host: uri.host,
        downloadedBytes: await _safeLength(partFile),
        originalError: error,
      );
    } catch (error) {
      throw VerifiedDownloadException(
        VerifiedDownloadFailure.network,
        'Download failed',
        host: uri.host,
        downloadedBytes: await _safeLength(partFile),
        originalError: error,
      );
    }
  }

  Future<void> _downloadToPartFile({
    required Uri uri,
    required File partFile,
    required int expectedSize,
    required void Function(VerifiedDownloadProgress progress)? onProgress,
    required CancelToken? cancelToken,
  }) async {
    var existingBytes = await partFile.exists() ? await partFile.length() : 0;
    if (existingBytes > expectedSize) {
      await _deleteQuietly(partFile);
      existingBytes = 0;
    }
    var retriedWithoutRange = false;

    while (true) {
      _throwIfCancelled(cancelToken);
      final response = await _dio.get<ResponseBody>(
        uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: {
            HttpHeaders.acceptEncodingHeader: 'identity',
            if (existingBytes > 0)
              HttpHeaders.rangeHeader: 'bytes=$existingBytes-',
          },
          validateStatus: (status) =>
              status == HttpStatus.ok ||
              status == HttpStatus.partialContent ||
              status == HttpStatus.requestedRangeNotSatisfiable,
        ),
      );
      final statusCode = response.statusCode;
      if (statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        if (existingBytes == expectedSize) return;
        if (retriedWithoutRange) {
          throw VerifiedDownloadException(
            VerifiedDownloadFailure.rangeRejected,
            'Server rejected the resume request',
            statusCode: statusCode,
            host: uri.host,
            downloadedBytes: existingBytes,
          );
        }
        await _deleteQuietly(partFile);
        existingBytes = 0;
        retriedWithoutRange = true;
        continue;
      }

      final isResumed =
          statusCode == HttpStatus.partialContent && existingBytes > 0;
      if (isResumed) {
        final rangeStart = _parseContentRangeStart(
          response.headers.value(HttpHeaders.contentRangeHeader),
        );
        if (rangeStart != existingBytes) {
          throw VerifiedDownloadException(
            VerifiedDownloadFailure.rangeRejected,
            'Server returned an invalid Content-Range start',
            statusCode: statusCode,
            host: uri.host,
            downloadedBytes: existingBytes,
            originalError: 'expected=$existingBytes actual=$rangeStart',
          );
        }
      } else if (existingBytes > 0) {
        // A 200 response ignored Range. Restart from byte zero rather than
        // appending a second complete file to the partial payload.
        await _deleteQuietly(partFile);
        existingBytes = 0;
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw VerifiedDownloadException(
          VerifiedDownloadFailure.emptyResponse,
          'Server returned an empty response',
          statusCode: statusCode,
          host: uri.host,
          downloadedBytes: existingBytes,
        );
      }
      final contentRangeTotal = _parseContentRangeTotal(
        response.headers.value(HttpHeaders.contentRangeHeader),
      );
      if (contentRangeTotal != null && contentRangeTotal != expectedSize) {
        throw VerifiedDownloadException(
          VerifiedDownloadFailure.sizeMismatch,
          'Server Content-Range total does not match the manifest',
          statusCode: statusCode,
          host: uri.host,
          downloadedBytes: existingBytes,
          originalError: 'expected=$expectedSize actual=$contentRangeTotal',
        );
      }

      var receivedBytes = existingBytes;
      var lastSampleBytes = receivedBytes;
      var lastSampleTime = DateTime.now();
      var smoothedSpeed = 0;
      final sink = partFile.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in responseBody.stream) {
          _throwIfCancelled(cancelToken);
          if (receivedBytes + chunk.length > expectedSize) {
            throw VerifiedDownloadException(
              VerifiedDownloadFailure.sizeMismatch,
              'Server sent more bytes than declared in the manifest',
              statusCode: statusCode,
              host: uri.host,
              downloadedBytes: receivedBytes + chunk.length,
              originalError: 'expected=$expectedSize',
            );
          }
          sink.add(chunk);
          receivedBytes += chunk.length;
          final now = DateTime.now();
          final elapsed = now.difference(lastSampleTime);
          if (elapsed >= _speedSampleWindow) {
            final instantSpeed =
                ((receivedBytes - lastSampleBytes) *
                        1000 /
                        elapsed.inMilliseconds)
                    .round();
            smoothedSpeed = smoothedSpeed == 0
                ? instantSpeed
                : (smoothedSpeed * 0.7 + instantSpeed * 0.3).round();
            lastSampleTime = now;
            lastSampleBytes = receivedBytes;
          }
          onProgress?.call(
            VerifiedDownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: expectedSize,
              progress: (receivedBytes / expectedSize).clamp(0.0, 0.99),
              bytesPerSecond: smoothedSpeed,
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return;
    }
  }

  static void _validateRequest(
    Uri uri,
    int expectedSize,
    String expectedSha256,
  ) {
    final isLoopbackTestServer =
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' ||
            uri.host == '::1' ||
            uri.host == 'localhost');
    if ((uri.scheme != 'https' && !isLoopbackTestServer) || uri.host.isEmpty) {
      throw const VerifiedDownloadException(
        VerifiedDownloadFailure.invalidRequest,
        'Download URL must use HTTPS',
      );
    }
    if (expectedSize <= 0 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha256)) {
      throw const VerifiedDownloadException(
        VerifiedDownloadFailure.invalidRequest,
        'Download size and SHA256 must be declared',
      );
    }
  }

  static int? _parseContentRangeStart(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^bytes\s+(\d+)-\d+/\d+$').firstMatch(value.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static int? _parseContentRangeTotal(String? value) {
    if (value == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(value.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static bool _isDiskFull(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 112 || code == 28 || code == 39;
  }

  static void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw const VerifiedDownloadCancelledException();
    }
  }

  static Future<int> _safeLength(File file) async {
    try {
      return await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup must not replace the original transport or integrity error.
    }
  }

  static Future<String> calculateSha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static bool equalsSha256(String actual, String expected) =>
      actual.toLowerCase() == expected.toLowerCase();
}
