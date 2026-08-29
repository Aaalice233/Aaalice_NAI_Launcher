import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gallery_image_request.dart';
import 'online_gallery_image_cache_manager.dart';
import 'online_gallery_prefetch_coordinator.dart';

/// Downloads gallery images with request-scoped transport cancellation.
///
/// flutter_cache_manager keeps downloads alive after its last stream listener
/// detaches. This loader aborts the underlying HttpClientRequest instead, then
/// publishes only complete responses into the existing shared disk cache.
class CancellableGalleryImageLoader {
  CancellableGalleryImageLoader({
    BaseCacheManager? cacheManager,
    HttpClient? httpClient,
  }) : _cacheManager = cacheManager ?? OnlineGalleryImageCacheManager.instance,
       _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 15);
    _httpClient.maxConnectionsPerHost = 4;
  }

  final BaseCacheManager _cacheManager;
  final HttpClient _httpClient;
  bool _disposed = false;

  GalleryImagePreloadOperation start(GalleryImageRequest request) {
    if (_disposed) {
      return GalleryImagePreloadOperation.fromFuture(
        Future<void>.error(StateError('Gallery image loader is disposed')),
      );
    }

    final completer = Completer<void>();
    HttpClientRequest? httpRequest;
    var cancelled = false;

    Future<void> run() async {
      try {
        final cacheKey = request.canonicalCacheKey;
        final cached = await _cacheManager.getFileFromCache(cacheKey);
        if (cached != null && cached.validTill.isAfter(DateTime.now())) return;
        if (cancelled) throw const _GalleryDownloadCancelled();

        final outgoing = await _httpClient.getUrl(Uri.parse(request.url));
        httpRequest = outgoing;
        request.headers.forEach(outgoing.headers.set);
        if (cancelled) {
          outgoing.abort();
          throw const _GalleryDownloadCancelled();
        }

        final response = await outgoing.close();
        if (response.statusCode < HttpStatus.ok ||
            response.statusCode >= HttpStatus.multipleChoices) {
          throw HttpException(
            'Gallery image HTTP status ${response.statusCode}',
          );
        }
        final contentType = response.headers.contentType;
        if (contentType != null && contentType.primaryType != 'image') {
          throw const HttpException('Gallery response is not an image');
        }

        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (cancelled) throw const _GalleryDownloadCancelled();
          bytes.add(chunk);
        }
        if (cancelled) throw const _GalleryDownloadCancelled();

        await _cacheManager.putFile(
          request.url,
          bytes.takeBytes(),
          key: cacheKey,
          eTag: response.headers.value(HttpHeaders.etagHeader),
          maxAge: const Duration(days: 7),
          fileExtension: _fileExtension(response, request.url),
        );
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        return;
      }
      if (!completer.isCompleted) completer.complete();
    }

    unawaited(run());
    return GalleryImagePreloadOperation(
      future: completer.future,
      cancel: () {
        if (cancelled) return;
        cancelled = true;
        httpRequest?.abort(const _GalleryDownloadCancelled());
        if (!completer.isCompleted) {
          completer.completeError(const _GalleryDownloadCancelled());
        }
      },
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _httpClient.close(force: true);
  }

  static String _fileExtension(HttpClientResponse response, String url) {
    final mime = response.headers.contentType?.mimeType.toLowerCase();
    final mimeExtension = switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/avif' => 'avif',
      _ => null,
    };
    if (mimeExtension != null) return mimeExtension;
    final path = Uri.tryParse(url)?.path ?? '';
    final separator = path.lastIndexOf('.');
    if (separator < 0 || separator == path.length - 1) return 'file';
    return path.substring(separator + 1).toLowerCase();
  }
}

class _GalleryDownloadCancelled implements Exception {
  const _GalleryDownloadCancelled();

  @override
  String toString() => 'Gallery image download cancelled';
}
