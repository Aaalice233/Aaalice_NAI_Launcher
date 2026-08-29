import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/cancellable_gallery_image_loader.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/core/network/critical_network_activity.dart';

void main() {
  test(
    'cancel aborts an unfinished transfer without publishing cache',
    () async {
      final requestArrived = Completer<void>();
      final finishResponse = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(List<int>.filled(1024, 1));
        await request.response.flush();
        requestArrived.complete();
        await finishResponse.future;
        try {
          request.response.add(List<int>.filled(1024, 2));
          await request.response.close();
        } on Object {
          // The expected peer abort closes the response while the server waits.
        }
      });

      final url = 'http://${server.address.host}:${server.port}/slow.png';
      final request = GalleryImageRequest(
        sourceId: 'test',
        url: url,
        cacheKey: 'cancel-test-${DateTime.now().microsecondsSinceEpoch}',
        tier: GalleryImageTier.thumbnail,
      );
      final cache = _RecordingCacheManager();
      final loader = CancellableGalleryImageLoader(cacheManager: cache);
      addTearDown(loader.dispose);

      final operation = loader.start(request);
      await requestArrived.future.timeout(const Duration(seconds: 2));
      operation.cancel();

      await expectLater(operation.future, throwsA(isA<Exception>()));
      finishResponse.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cache.putCalled, isFalse);
    },
  );

  test(
    'cancel aborts a gallery transfer routed through a slow proxy',
    () async {
      final requestArrived = Completer<Uri>();
      final finishResponse = Completer<void>();
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => proxy.close(force: true));
      proxy.listen((request) async {
        requestArrived.complete(request.uri);
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(List<int>.filled(1024, 1));
        await request.response.flush();
        await finishResponse.future;
        try {
          request.response.add(List<int>.filled(1024, 2));
          await request.response.close();
        } on Object {
          // The expected peer abort closes the proxied response while it waits.
        }
      });

      final httpClient = HttpClient()
        ..findProxy = (_) => 'PROXY ${proxy.address.host}:${proxy.port}';
      final cache = _RecordingCacheManager();
      final loader = CancellableGalleryImageLoader(
        cacheManager: cache,
        httpClient: httpClient,
      );
      addTearDown(loader.dispose);
      const request = GalleryImageRequest(
        sourceId: 'test',
        url: 'http://gallery.invalid/slow.jpg',
        cacheKey: 'slow-proxy-cancel-test',
        tier: GalleryImageTier.thumbnail,
      );

      final operation = loader.start(request);
      final proxyUri = await requestArrived.future.timeout(
        const Duration(seconds: 2),
      );
      expect(proxyUri.host, 'gallery.invalid');
      operation.cancel();

      await expectLater(operation.future, throwsA(isA<Exception>()));
      finishResponse.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cache.putCalled, isFalse);
    },
  );

  test('generation activity aborts an in-flight slow-proxy image', () async {
    final requestArrived = Completer<void>();
    final finishResponse = Completer<void>();
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => proxy.close(force: true));
    proxy.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(List<int>.filled(1024, 1));
      await request.response.flush();
      requestArrived.complete();
      await finishResponse.future;
      try {
        request.response.add(List<int>.filled(1024, 2));
        await request.response.close();
      } on Object {
        // The generation lease is expected to abort the gallery peer.
      }
    });

    final httpClient = HttpClient()
      ..findProxy = (_) => 'PROXY ${proxy.address.host}:${proxy.port}';
    final cache = _RecordingCacheManager();
    final loader = CancellableGalleryImageLoader(
      cacheManager: cache,
      httpClient: httpClient,
    );
    addTearDown(loader.dispose);
    final prefetch = OnlineGalleryPrefetchCoordinator(preloader: loader.start);
    addTearDown(prefetch.dispose);
    final critical = CriticalNetworkActivityCoordinator();
    void syncCriticalState() {
      prefetch.setCriticalNetworkActive(critical.isActive);
    }

    critical.addListener(syncCriticalState);
    addTearDown(() => critical.removeListener(syncCriticalState));
    const request = GalleryImageRequest(
      sourceId: 'test',
      url: 'http://gallery.invalid/competing.jpg',
      cacheKey: 'generation-qos-slow-proxy-test',
      tier: GalleryImageTier.thumbnail,
    );

    final galleryTransfer = prefetch.submit(
      request,
      priority: GalleryImagePriority.visible,
    );
    await requestArrived.future.timeout(const Duration(seconds: 2));
    final generation = critical.acquire(
      CriticalNetworkActivityType.imageGeneration,
    );

    expect(await galleryTransfer, isFalse);
    expect(cache.putCalled, isFalse);

    generation.release();
    finishResponse.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cache.putCalled, isFalse);
  });

  test('non-image responses are rejected without publishing cache', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write('<html>upstream error</html>');
      await request.response.close();
    });
    final cache = _RecordingCacheManager();
    final loader = CancellableGalleryImageLoader(cacheManager: cache);
    addTearDown(loader.dispose);
    final operation = loader.start(
      GalleryImageRequest(
        sourceId: 'test',
        url: 'http://${server.address.host}:${server.port}/error.jpg',
        cacheKey: 'invalid-content-type',
        tier: GalleryImageTier.thumbnail,
      ),
    );

    await expectLater(operation.future, throwsA(isA<StateError>()));
    expect(cache.putCalled, isFalse);
  });
}

class _RecordingCacheManager implements BaseCacheManager {
  bool putCalled = false;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #putFile) {
      putCalled = true;
      return Future<Object>.error(
        StateError('Cancelled responses must not be cached'),
      );
    }
    return super.noSuchMethod(invocation);
  }
}
