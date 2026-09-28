import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gallery_image_request.dart';
import 'online_gallery_image_cache_manager.dart';
import 'online_gallery_prefetch_coordinator.dart';

class CancellableGalleryImageLoader {
  CancellableGalleryImageLoader({
    BaseCacheManager? cacheManager,
    Dio? dio,
    HttpClient? httpClient,
  }) : _cacheManager = cacheManager ?? OnlineGalleryImageCacheManager.instance,
       _ownsDio = dio == null,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    if (httpClient != null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => httpClient,
      );
    }
  }

  final BaseCacheManager _cacheManager;
  final Dio _dio;
  final bool _ownsDio;
  final Map<String, _SharedGalleryTransfer> _transfers = {};
  bool _disposed = false;

  GalleryImagePreloadOperation start(GalleryImageRequest request) {
    if (_disposed || request.url.isEmpty) {
      return GalleryImagePreloadOperation.fromFuture(Future<void>.value());
    }

    final transferKey = request.transportKey;
    final existing = _transfers[transferKey];
    if (existing != null && existing.canAcceptConsumer) {
      return existing.addConsumer();
    }

    final transfer = _SharedGalleryTransfer();
    _transfers[transferKey] = transfer;
    unawaited(
      _run(request, transfer).whenComplete(() {
        if (_transfers[transferKey] == transfer) {
          _transfers.remove(transferKey);
        }
      }),
    );
    return transfer.addConsumer();
  }

  Future<void> _run(
    GalleryImageRequest request,
    _SharedGalleryTransfer transfer,
  ) async {
    try {
      final cacheKey = request.canonicalCacheKey;
      final cached = await _cacheManager.getFileFromCache(cacheKey);
      if (cached != null &&
          cached.validTill.isAfter(DateTime.now()) &&
          await cached.file.exists()) {
        transfer.complete();
        return;
      }

      final response = await _downloadWithRetry(request, transfer.cancelToken);
      if (transfer.cancelToken.isCancelled) {
        throw const _GalleryDownloadCancelled();
      }
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Gallery image response was empty');
      }
      final contentType = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != null && !contentType.startsWith('image/')) {
        throw StateError(
          'Gallery image response had invalid content type: $contentType',
        );
      }

      await _cacheManager.putFile(
        request.url,
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        key: cacheKey,
        eTag: response.headers.value('etag'),
        maxAge: const Duration(days: 7),
        fileExtension: _fileExtension(request.url, contentType),
      );
      transfer.complete();
    } catch (error, stackTrace) {
      transfer.completeError(error, stackTrace);
    }
  }

  Future<Response<List<int>>> _downloadWithRetry(
    GalleryImageRequest request,
    CancelToken cancelToken,
  ) async {
    DioException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _dio.get<List<int>>(
          request.url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            headers: request.headers,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
      } on DioException catch (error) {
        lastError = error;
        if (cancelToken.isCancelled || attempt > 0 || !_isTransient(error)) {
          rethrow;
        }
      }
    }
    throw lastError!;
  }

  bool _isTransient(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }
    final status = error.response?.statusCode;
    return status == 408 ||
        status == 425 ||
        status == 429 ||
        (status ?? 0) >= 500;
  }

  String _fileExtension(String url, String? contentType) {
    final mimeExtension = switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/avif' => 'avif',
      _ => null,
    };
    if (mimeExtension != null) return mimeExtension;
    final path = Uri.tryParse(url)?.path ?? '';
    final separator = path.lastIndexOf('.');
    if (separator < 0 || separator == path.length - 1) return 'file';
    return path.substring(separator + 1).toLowerCase();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final transfer in _transfers.values.toList(growable: false)) {
      transfer.abort();
    }
    _transfers.clear();
    if (_ownsDio) _dio.close(force: true);
  }
}

class _SharedGalleryTransfer {
  final CancelToken cancelToken = CancelToken();
  final Set<Completer<void>> _consumers = {};
  bool _completed = false;
  Object? _error;
  StackTrace? _stackTrace;

  bool get canAcceptConsumer =>
      !cancelToken.isCancelled && (!_completed || _error == null);

  GalleryImagePreloadOperation addConsumer() {
    final completer = Completer<void>();
    if (_completed) {
      final error = _error;
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(error, _stackTrace ?? StackTrace.current);
      }
    } else {
      _consumers.add(completer);
    }
    return GalleryImagePreloadOperation(
      future: completer.future,
      cancel: () {
        if (!_consumers.remove(completer) || completer.isCompleted) return;
        completer.completeError(const _GalleryDownloadCancelled());
        if (_consumers.isEmpty && !_completed && !cancelToken.isCancelled) {
          cancelToken.cancel(const _GalleryDownloadCancelled());
        }
      },
    );
  }

  void complete() {
    if (_completed) return;
    _completed = true;
    final consumers = _consumers.toList(growable: false);
    _consumers.clear();
    for (final consumer in consumers) {
      if (!consumer.isCompleted) consumer.complete();
    }
  }

  void completeError(Object error, StackTrace stackTrace) {
    if (_completed) return;
    _completed = true;
    _error = error;
    _stackTrace = stackTrace;
    final consumers = _consumers.toList(growable: false);
    _consumers.clear();
    for (final consumer in consumers) {
      if (!consumer.isCompleted) consumer.completeError(error, stackTrace);
    }
  }

  void abort() {
    if (_completed) return;
    if (!cancelToken.isCancelled) {
      cancelToken.cancel(const _GalleryDownloadCancelled());
    }
    completeError(const _GalleryDownloadCancelled(), StackTrace.current);
  }
}

class _GalleryDownloadCancelled implements Exception {
  const _GalleryDownloadCancelled();

  @override
  String toString() => 'Gallery image download cancelled';
}
