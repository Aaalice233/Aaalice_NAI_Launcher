import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';

void main() {
  late Directory supportDirectory;
  late _CatalogFixture fixture;
  late _RoutingAdapter adapter;
  late QuickTagCloudRemoteCatalogService service;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'quick_tag_cloud_',
    );
    fixture = _CatalogFixture();
    adapter = _RoutingAdapter(fixture.routes);
    final dio = Dio()..httpClientAdapter = adapter;
    service = QuickTagCloudRemoteCatalogService(
      dio: dio,
      supportDirectoryLoader: () async => supportDirectory,
    );
  });

  tearDown(() async {
    await supportDirectory.delete(recursive: true);
  });

  test(
    'loads current catalog files from network and verifies the manifest',
    () async {
      final catalog = await service.fetchCatalog();

      expect(catalog.release, fixture.release);
      expect(catalog.codexes.map((item) => item.id), ['book', 'external']);
      expect(catalog.media.imagePrefix, 'images');
      expect(
        adapter.requests.map((request) => request.uri.toString()),
        containsAll([
          QuickTagCloudRemoteCatalogService.dataSourceUrl,
          'https://data.example/root/current.json',
          'https://data.example/root/releases/${fixture.release}/manifest.json',
          'https://data.example/root/releases/${fixture.release}/codexes.json',
          'https://data.example/root/releases/${fixture.release}/media.json',
        ]),
      );
    },
  );

  test(
    'rejects a snapshot whose release files no longer match manifest',
    () async {
      await service.fetchCatalog();
      final snapshot = File(
        p.join(
          supportDirectory.path,
          'online_gallery',
          'quick_tag_cloud',
          'catalog_snapshot.json',
        ),
      );
      final envelope = jsonDecode(await snapshot.readAsString()) as Map;
      final payload = Map<String, dynamic>.from(envelope['payload'] as Map);
      final releaseFiles = Map<String, dynamic>.from(
        payload['releaseFiles'] as Map,
      );
      releaseFiles['codexes.json'] = base64Encode(
        utf8.encode('[{"id":"tampered"}]'),
      );
      payload['releaseFiles'] = releaseFiles;
      final payloadJson = jsonEncode(payload);
      await snapshot.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'payloadSha256': sha256.convert(utf8.encode(payloadJson)).toString(),
          'payload': payload,
        }),
      );
      adapter.failures.add(QuickTagCloudRemoteCatalogService.dataSourceUrl);

      await expectLater(service.fetchCatalog(), throwsA(isA<DioException>()));
    },
  );

  test('honors cancellation before catalog loading starts', () async {
    final cancelToken = CancelToken()..cancel('superseded');

    await expectLater(
      service.fetchCatalog(cancelToken: cancelToken),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });

  test(
    'caches canonical JSON by release and repairs a corrupt cache',
    () async {
      final catalog = await service.fetchCatalog();
      final meta = catalog.findCodex('book')!;

      final first = await service.fetchCodex(catalog, meta);
      expect(first.entries.single.title, 'Canonical entry');
      expect(adapter.count(fixture.canonicalUrl), 1);

      service.clearMemoryCache();
      fixture.routes.remove(fixture.canonicalUrl);
      final cached = await service.fetchCodex(catalog, meta);
      expect(cached.entries.single.title, 'Canonical entry');
      expect(adapter.count(fixture.canonicalUrl), 1);

      final cacheFile = File(
        p.join(
          supportDirectory.path,
          'online_gallery',
          'quick_tag_cloud',
          fixture.release,
          'book.json',
        ),
      );
      final interruptedBackup = File('${cacheFile.path}.123.backup');
      await cacheFile.rename(interruptedBackup.path);
      service.clearMemoryCache();
      final restored = await service.fetchCodex(catalog, meta);
      expect(restored.entries.single.title, 'Canonical entry');
      expect(cacheFile.existsSync(), isTrue);
      expect(interruptedBackup.existsSync(), isFalse);

      await cacheFile.writeAsString('corrupt');
      fixture.routes[fixture.canonicalUrl] = fixture.canonicalBytes;
      service.clearMemoryCache();

      final repaired = await service.fetchCodex(catalog, meta);
      expect(repaired.entries.single.title, 'Canonical entry');
      expect(adapter.count(fixture.canonicalUrl), 2);
      expect(await cacheFile.readAsBytes(), fixture.canonicalBytes);
      expect(
        cacheFile.parent.listSync().where(
          (item) =>
              item.path.endsWith('.downloading') ||
              item.path.endsWith('.backup'),
        ),
        isEmpty,
      );
    },
  );

  test('rejects canonical bytes that do not match size and sha256', () async {
    final catalog = await service.fetchCatalog();
    final meta = catalog.findCodex('book')!;
    fixture.routes[fixture.canonicalUrl] = utf8.encode('{"id":"changed"}');

    await expectLater(
      service.fetchCodex(catalog, meta),
      throwsA(isA<QuickTagCloudIntegrityException>()),
    );
  });

  test('keeps the previous verified release when a new codex fails', () async {
    final previousCatalog = await service.fetchCatalog();
    final previousMeta = previousCatalog.findCodex('book')!;
    await service.fetchCodex(previousCatalog, previousMeta);

    final staleDirectory = Directory(
      p.join(
        supportDirectory.path,
        'online_gallery',
        'quick_tag_cloud',
        'r-11111111111111111111',
      ),
    );
    await staleDirectory.create(recursive: true);
    final nextCanonicalBytes = _CatalogFixture._jsonBytes({
      'id': 'book',
      'entries': [
        {'id': 'one', 'title': 'New entry'},
      ],
    });
    final nextFiles = <String, Map<String, Object>>{
      'codexes.json': _CatalogFixture._metadata(fixture.codexesBytes),
      'media.json': _CatalogFixture._metadata(fixture.mediaBytes),
      'book.json': _CatalogFixture._metadata(nextCanonicalBytes),
      'external.json': _CatalogFixture._metadata(fixture.fallbackBytes),
    };
    final nextContentHash = _CatalogFixture._contentHash(nextFiles);
    final nextRelease = 'r-${nextContentHash.substring(0, 20)}';
    final nextManifest = {
      'schemaVersion': 1,
      'release': nextRelease,
      'contentHash': nextContentHash,
      'files': nextFiles,
    };
    fixture.routes['https://data.example/root/current.json'] =
        _CatalogFixture._jsonBytes({
          'schemaVersion': 1,
          'release': nextRelease,
          'manifest': 'releases/$nextRelease/manifest.json',
          'contentHash': nextContentHash,
        });
    fixture.routes['https://data.example/root/releases/$nextRelease/manifest.json'] =
        _CatalogFixture._jsonBytes(nextManifest);
    fixture.routes['https://data.example/root/releases/$nextRelease/codexes.json'] =
        fixture.codexesBytes;
    fixture.routes['https://data.example/root/releases/$nextRelease/media.json'] =
        fixture.mediaBytes;
    final nextBookUrl =
        'https://data.example/root/releases/$nextRelease/book.json';
    adapter.failures.add(nextBookUrl);

    final nextCatalog = await service.fetchCatalog();
    service.clearMemoryCache();
    final recovered = await service.fetchCodex(
      nextCatalog,
      nextCatalog.findCodex('book')!,
    );

    expect(recovered.entries.single.title, 'Canonical entry');
    expect(recovered.loadSource, QuickTagCloudCodexLoadSource.previousRelease);
    expect(recovered.sourceRelease, previousCatalog.release);
    expect(recovered.mediaOverride?.baseUrl, previousCatalog.media.baseUrl);
    expect(adapter.count(nextBookUrl), 1);

    adapter.failures.remove(nextBookUrl);
    fixture.routes[nextBookUrl] = nextCanonicalBytes;
    final current = await service.fetchCodex(
      nextCatalog,
      nextCatalog.findCodex('book')!,
    );
    expect(current.entries.single.title, 'New entry');
    expect(current.loadSource, QuickTagCloudCodexLoadSource.canonical);
    expect(adapter.count(nextBookUrl), 2);
    expect(staleDirectory.existsSync(), isFalse);
    final previousSnapshot = File(
      p.join(
        supportDirectory.path,
        'online_gallery',
        'quick_tag_cloud',
        'catalog_snapshot.previous.json',
      ),
    );
    expect(previousSnapshot.existsSync(), isTrue);

    final currentSnapshot = File(
      p.join(
        supportDirectory.path,
        'online_gallery',
        'quick_tag_cloud',
        'catalog_snapshot.json',
      ),
    );
    await currentSnapshot.writeAsString('{"schemaVersion":1,"payload":{}}');
    adapter.failures.add(QuickTagCloudRemoteCatalogService.dataSourceUrl);

    final offlineCatalog = await service.fetchCatalog();
    expect(offlineCatalog.release, previousCatalog.release);
    expect(offlineCatalog.isOffline, isTrue);
  });

  test(
    'fetches pointer previousRelease and resolves renamed codex aliases',
    () async {
      final currentCodexes = _CatalogFixture._jsonBytes([
        {
          'id': 'book-v2',
          'title': 'Renamed Book',
          'aliases': ['legacy-book'],
        },
      ]);
      final currentMedia = fixture.mediaBytes;
      final currentBook = _CatalogFixture._jsonBytes({
        'id': 'book-v2',
        'entries': [
          {'id': 'new', 'title': 'Unavailable new entry'},
        ],
      });
      final currentFiles = <String, Map<String, Object>>{
        'codexes.json': _CatalogFixture._metadata(currentCodexes),
        'media.json': _CatalogFixture._metadata(currentMedia),
        'book-v2.json': _CatalogFixture._metadata(currentBook),
      };
      final currentHash = _CatalogFixture._contentHash(currentFiles);
      final currentRelease = 'r-${currentHash.substring(0, 20)}';
      fixture.routes['https://data.example/root/current.json'] =
          _CatalogFixture._jsonBytes({
            'schemaVersion': 1,
            'release': currentRelease,
            'manifest': 'releases/$currentRelease/manifest.json',
            'contentHash': currentHash,
            'previousRelease': fixture.release,
          });
      fixture.routes['https://data.example/root/releases/$currentRelease/manifest.json'] =
          _CatalogFixture._jsonBytes({
            'schemaVersion': 1,
            'release': currentRelease,
            'contentHash': currentHash,
            'files': currentFiles,
          });
      fixture.routes['https://data.example/root/releases/$currentRelease/codexes.json'] =
          currentCodexes;
      fixture.routes['https://data.example/root/releases/$currentRelease/media.json'] =
          currentMedia;
      final currentBookUrl =
          'https://data.example/root/releases/$currentRelease/book-v2.json';
      adapter.failures.add(currentBookUrl);

      final catalog = await service.fetchCatalog();
      final recovered = await service.fetchCodex(
        catalog,
        catalog.findCodex('book-v2')!,
      );

      expect(recovered.entries.single.title, 'Canonical entry');
      expect(recovered.id, 'book');
      expect(
        recovered.loadSource,
        QuickTagCloudCodexLoadSource.previousRelease,
      );
      expect(recovered.sourceRelease, fixture.release);
      expect(
        adapter.count(
          'https://data.example/root/releases/${fixture.release}/manifest.json',
        ),
        1,
      );
      expect(adapter.count(fixture.canonicalUrl), 1);
    },
  );

  test(
    'retries external data after verified fallback and caches recovery',
    () async {
      final catalog = await service.fetchCatalog();
      final meta = catalog.findCodex('external')!;
      adapter.failures.add(fixture.externalUrl);

      final first = await service.fetchCodex(catalog, meta);

      expect(first.loadSource, QuickTagCloudCodexLoadSource.fallback);
      expect(first.entries.single.title, 'Fallback entry');
      expect(adapter.count(fixture.externalUrl), 1);
      expect(adapter.count(fixture.fallbackUrl), 1);
      final externalRequest = adapter.requests.firstWhere(
        (request) => request.uri.toString() == fixture.externalUrl,
      );
      expect(externalRequest.headers['Cache-Control'], 'no-store');
      expect(externalRequest.extra['quickTagCloudCache'], 'no-store');

      adapter.failures.remove(fixture.externalUrl);
      fixture.routes[fixture.externalUrl] = fixture.externalBytes;
      final recovered = await service.fetchCodex(catalog, meta);
      final cached = await service.fetchCodex(catalog, meta);

      expect(recovered.loadSource, QuickTagCloudCodexLoadSource.external);
      expect(recovered.title, 'Live External');
      expect(recovered.version, 'live-v2');
      expect(recovered.author, 'Live Author');
      expect(recovered.entries.single.title, 'External entry');
      expect(cached, same(recovered));
      expect(adapter.count(fixture.externalUrl), 2);
      expect(adapter.count(fixture.fallbackUrl), 1);
    },
  );

  test('never serves mengshen_r18 from the QuickTagCloud fallback', () async {
    final catalog = await service.fetchCatalog();
    adapter.failures.add(fixture.externalUrl);
    final meta = QuickTagCloudCodexMeta(
      id: 'dream-god-renamed',
      title: 'DreamGod',
      dataUrl: fixture.externalUrl,
      fallbackDataUrl: 'data/external.json',
      aliases: const ['mengshen_r18'],
    );

    await expectLater(
      service.fetchCodex(catalog, meta),
      throwsA(isA<DioException>()),
    );
    expect(adapter.count(fixture.externalUrl), 1);
    expect(adapter.count(fixture.fallbackUrl), 0);
  });
}

class _CatalogFixture {
  late final Map<String, Map<String, Object>> files = {
    'codexes.json': _metadata(codexesBytes),
    'media.json': _metadata(mediaBytes),
    'book.json': _metadata(canonicalBytes),
    'external.json': _metadata(fallbackBytes),
  };
  late final String contentHash = _contentHash(files);
  late final String release = 'r-${contentHash.substring(0, 20)}';
  late final String canonicalUrl =
      'https://data.example/root/releases/$release/book.json';
  late final String fallbackUrl =
      'https://data.example/root/releases/$release/external.json';
  final String externalUrl = 'https://external.example/book.json';

  late final List<int> canonicalBytes = _jsonBytes({
    'id': 'book',
    'entries': [
      {'id': 'one', 'title': 'Canonical entry'},
    ],
  });
  late final List<int> fallbackBytes = _jsonBytes({
    'id': 'external',
    'entries': [
      {'id': 'fallback', 'title': 'Fallback entry'},
    ],
  });
  late final List<int> externalBytes = _jsonBytes({
    'id': 'external',
    'title': 'Live External',
    'version': 'live-v2',
    'author': 'Live Author',
    'entries': [
      {'id': 'remote', 'title': 'External entry'},
    ],
  });
  late final List<int> codexesBytes = _jsonBytes([
    {
      'id': 'book',
      'title': 'Book',
      'aliases': ['legacy-book'],
    },
    {
      'id': 'external',
      'title': 'External',
      'dataUrl': externalUrl,
      'fallbackDataUrl': 'data/external.json',
      'fallbackVersion': 'snapshot',
      'assetBaseUrl': 'https://external.example/assets',
      'assetPathMode': 'relative',
    },
  ]);
  late final List<int> mediaBytes = _jsonBytes({
    'baseUrl': 'https://assets.example',
    'imagePrefix': 'images',
    'originalPrefix': 'originals',
  });

  late final Map<String, List<int>> routes = _buildRoutes();

  Map<String, List<int>> _buildRoutes() {
    final manifest = {
      'schemaVersion': 1,
      'release': release,
      'contentHash': contentHash,
      'files': files,
    };
    return {
      QuickTagCloudRemoteCatalogService.dataSourceUrl: _jsonBytes({
        'schemaVersion': 1,
        'baseUrl': 'https://data.example/root',
        'pointer': 'current.json',
      }),
      'https://data.example/root/current.json': _jsonBytes({
        'schemaVersion': 1,
        'release': release,
        'manifest': 'releases/$release/manifest.json',
        'contentHash': contentHash,
      }),
      'https://data.example/root/releases/$release/manifest.json': _jsonBytes(
        manifest,
      ),
      'https://data.example/root/releases/$release/codexes.json': codexesBytes,
      'https://data.example/root/releases/$release/media.json': mediaBytes,
      canonicalUrl: canonicalBytes,
      fallbackUrl: fallbackBytes,
      externalUrl: externalBytes,
    };
  }

  static Map<String, Object> _metadata(List<int> bytes) => {
    'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  };

  static String _contentHash(Map<String, Map<String, Object>> files) {
    final paths = files.keys.toList()..sort();
    final input = StringBuffer();
    for (final path in paths) {
      input
        ..write(path)
        ..writeCharCode(0)
        ..write(files[path]!['sha256'])
        ..write('\n');
    }
    return sha256.convert(utf8.encode(input.toString())).toString();
  }

  static List<int> _jsonBytes(Object value) => utf8.encode(jsonEncode(value));
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  final Map<String, List<int>> routes;
  final Set<String> failures = {};
  final List<RequestOptions> requests = [];

  int count(String url) =>
      requests.where((request) => request.uri.toString() == url).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final url = options.uri.toString();
    if (failures.contains(url)) {
      return ResponseBody.fromString('unavailable', 503);
    }
    final bytes = routes[url];
    if (bytes == null) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
