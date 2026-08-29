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
  bool _disposed = false;

  GalleryImagePreloadOperation start(GalleryImageRequest request) {
    if (_disposed || request.url.isEmpty) {
      return GalleryImagePreloadOperation.fromFuture(Future<void>.value());
    }

    final completer = Completer<void>();
    final cancelToken = CancelToken();

    Future<void> run() async {
      try {
        final cacheKey = request.canonicalCacheKey;
        final cached = await _cacheManager.getFileFromCache(cacheKey);
        if (cached != null &&
            cached.validTill.isAfter(DateTime.now()) &&
            await cached.file.exists()) {
          if (!completer.isCompleted) completer.complete();
          return;
        }

        final response = await _dio.get<List<int>>(
          request.url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            headers: request.headers,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
        if (cancelToken.isCancelled) throw const _GalleryDownloadCancelled();
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
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    }

    unawaited(run());
    return GalleryImagePreloadOperation(
      future: completer.future,
      cancel: () {
        if (cancelToken.isCancelled) return;
        cancelToken.cancel(const _GalleryDownloadCancelled());
        if (!completer.isCompleted) {
          completer.completeError(const _GalleryDownloadCancelled());
        }
      },
    );
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
    if (_ownsDio) _dio.close(force: true);
  }
}

class _GalleryDownloadCancelled implements Exception {
  const _GalleryDownloadCancelled();

  @override
  String toString() => 'Gallery image download cancelled';
}
