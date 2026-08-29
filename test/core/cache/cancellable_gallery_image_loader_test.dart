import 'dart:async';
import 'dart:io';

import 'package:file/file.dart' as fs;
import 'package:file/memory.dart';
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
    'cancelled transport can be retried before old cleanup finishes',
    () async {
      final firstRequestArrived = Completer<void>();
      final releaseFirstResponse = Completer<void>();
      addTearDown(() {
        if (!releaseFirstResponse.isCompleted) releaseFirstResponse.complete();
      });
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestCount++;
        if (requestCount == 1) {
          firstRequestArrived.complete();
          await releaseFirstResponse.future;
          try {
            await request.response.close();
          } on Object {
            // The first consumer intentionally aborted this transport.
          }
          return;
        }
        request.response.headers.contentType = ContentType('image', 'webp');
        request.response.add([0x52, 0x49, 0x46, 0x46]);
        await request.response.close();
      });
      final cache = _RecordingCacheManager(allowPut: true);
      final loader = CancellableGalleryImageLoader(cacheManager: cache);
      addTearDown(loader.dispose);
      final request = GalleryImageRequest(
        sourceId: 'test',
        url: 'http://${server.address.host}:${server.port}/retry-cancel.webp',
        tier: GalleryImageTier.thumbnail,
      );

      final cancelled = loader.start(request);
      await firstRequestArrived.future.timeout(const Duration(seconds: 2));
      cancelled.cancel();
      await expectLater(cancelled.future, throwsA(isA<Exception>()));

      final retry = loader.start(request);
      await retry.future.timeout(const Duration(seconds: 2));
      releaseFirstResponse.complete();

      expect(requestCount, 2);
      expect(cache.putCount, 1);
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

  test(
    'shares one transport across decode tiers and keeps remaining consumer',
    () async {
      final requestArrived = Completer<void>();
      final finishResponse = Completer<void>();
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestCount++;
        if (!requestArrived.isCompleted) requestArrived.complete();
        await finishResponse.future;
        request.response.headers.contentType = ContentType('image', 'webp');
        request.response.add([0x52, 0x49, 0x46, 0x46]);
        await request.response.close();
      });
      final cache = _RecordingCacheManager(allowPut: true);
      final loader = CancellableGalleryImageLoader(cacheManager: cache);
      addTearDown(loader.dispose);
      final url = 'http://${server.address.host}:${server.port}/shared.webp';
      final thumbnail = GalleryImageRequest(
        sourceId: 'ai_tag',
        url: url,
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );
      final sample = GalleryImageRequest(
        sourceId: 'ai_tag',
        url: url,
        tier: GalleryImageTier.sample,
        targetDecodeWidth: 960,
      );

      final first = loader.start(thumbnail);
      final second = loader.start(sample);
      await requestArrived.future.timeout(const Duration(seconds: 2));
      first.cancel();
      await expectLater(first.future, throwsA(isA<Exception>()));
      finishResponse.complete();
      await second.future;

      expect(requestCount, 1);
      expect(cache.putCount, 1);
    },
  );

  test('valid disk cache hit completes without opening the network', () async {
    final file = MemoryFileSystem().file('cached.webp')..writeAsBytesSync([1]);
    final cache = _RecordingCacheManager(
      cached: FileInfo(
        file,
        FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)),
        'http://gallery.invalid/cached.webp',
      ),
    );
    final loader = CancellableGalleryImageLoader(cacheManager: cache);
    addTearDown(loader.dispose);

    await loader
        .start(
          const GalleryImageRequest(
            sourceId: 'test',
            url: 'http://gallery.invalid/cached.webp',
            tier: GalleryImageTier.thumbnail,
          ),
        )
        .future;

    expect(cache.cacheLookups, 1);
    expect(cache.putCount, 0);
  });

  test(
    'retries one transient response without publishing a failed body',
    () async {
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        requestCount++;
        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType('image', 'webp');
        request.response.add([0x52, 0x49, 0x46, 0x46]);
        await request.response.close();
      });
      final cache = _RecordingCacheManager(allowPut: true);
      final loader = CancellableGalleryImageLoader(cacheManager: cache);
      addTearDown(loader.dispose);

      await loader
          .start(
            GalleryImageRequest(
              sourceId: 'ai_tag',
              url: 'http://${server.address.host}:${server.port}/retry.webp',
              tier: GalleryImageTier.thumbnail,
            ),
          )
          .future;

      expect(requestCount, 2);
      expect(cache.putCount, 1);
    },
  );

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
  _RecordingCacheManager({this.allowPut = false, this.cached});

  final bool allowPut;
  final FileInfo? cached;
  int putCount = 0;
  int cacheLookups = 0;
  bool get putCalled => putCount > 0;

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    cacheLookups++;
    return cached;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #putFile) {
      putCount++;
      if (allowPut) {
        return Future<fs.File>.value(MemoryFileSystem().file('unused-cache'));
      }
      return Future<fs.File>.error(
        StateError('Cancelled responses must not be cached'),
      );
    }
    return super.noSuchMethod(invocation);
  }
}
