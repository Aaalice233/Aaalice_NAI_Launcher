import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_data_pack_service.dart';
import 'package:nai_launcher/core/services/verified_resumable_downloader.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

void main() {
  group('CooccurrenceDataPackManifest', () {
    test('accepts a pinned GitHub prerelease manifest', () {
      final manifest = CooccurrenceDataPackManifest.parse(
        jsonEncode(_validManifestJson()),
      );

      expect(manifest.schemaVersion, 2);
      expect(manifest.dataVersion, 'fixture-v2');
      expect(manifest.downloadUri.host, 'github.com');
      expect(manifest.directedEdgeCount, 4);
    });

    test('rejects untrusted release URLs and unpinned provenance', () {
      final cases = <Map<String, dynamic> Function(Map<String, dynamic>)>[
        (json) {
          (json['release'] as Map<String, dynamic>)['url'] =
              'http://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
              'download/autocomplete-data-cooccurrence-fixture-v2/'
              'cooccurrence-v2.db.gz';
          return json;
        },
        (json) {
          (json['release'] as Map<String, dynamic>)['url'] =
              'https://example.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
              'download/autocomplete-data-cooccurrence-fixture-v2/'
              'cooccurrence-v2.db.gz';
          return json;
        },
        (json) {
          (json['release'] as Map<String, dynamic>)['url'] =
              'https://github.com/attacker/repository/releases/download/'
              'autocomplete-data-cooccurrence-fixture-v2/'
              'cooccurrence-v2.db.gz';
          return json;
        },
        (json) {
          (json['provenance'] as Map<String, dynamic>)['sourceUrl'] =
              'https://huggingface.co/datasets/example/data/resolve/main/'
              'source.csv';
          return json;
        },
      ];

      for (final mutate in cases) {
        final json = mutate(_validManifestJson());
        expect(
          () => CooccurrenceDataPackManifest.parse(jsonEncode(json)),
          throwsFormatException,
        );
      }
    });

    test('rejects archive path traversal', () {
      final json = _validManifestJson();
      final release = json['release'] as Map<String, dynamic>;
      final archive = json['archive'] as Map<String, dynamic>;
      archive['name'] = '../outside.gz';
      release['url'] =
          'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
          'download/autocomplete-data-cooccurrence-fixture-v2/../outside.gz';

      expect(
        () => CooccurrenceDataPackManifest.parse(jsonEncode(json)),
        throwsFormatException,
      );
    });
  });

  group('CooccurrenceDataPackService', () {
    late Directory tempDirectory;
    late Directory supportDirectory;
    late _DataPackFixture fixture;
    late List<HttpServer> servers;
    final services = <CooccurrenceDataPackService>[];

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'cooccurrence_pack_service_test_',
      );
      supportDirectory = Directory(p.join(tempDirectory.path, 'support'));
      fixture = await _DataPackFixture.create(tempDirectory);
      servers = [];
      services.clear();
    });

    tearDown(() async {
      for (final service in services.reversed) {
        await service.close();
      }
      for (final server in servers) {
        await server.close(force: true);
      }
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    Future<Uri> serveBytes(List<int> bytes) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servers.add(server);
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = bytes.length
          ..add(bytes);
        await request.response.close();
      });
      return Uri.parse('http://127.0.0.1:${server.port}/cooccurrence.db.gz');
    }

    Future<Uri> serveArchive() => serveBytes(fixture.archiveBytes);

    CooccurrenceDataPackService createService({
      CooccurrenceDataPackManifest? manifest,
      VerifiedResumableDownloader? downloader,
      DatabaseFactory? databaseFactory,
    }) {
      final service = CooccurrenceDataPackService(
        downloader: downloader,
        manifestLoader: () async => manifest ?? fixture.manifest,
        supportDirectoryLoader: () async => supportDirectory,
        databaseFactoryOverride: databaseFactory ?? databaseFactoryFfi,
      );
      services.add(service);
      return service;
    }

    test('installs, validates, queries, and deletes a data pack', () async {
      final manifest = fixture.manifestWithDownloadUri(await serveArchive());
      final service = createService(manifest: manifest);

      await service.initialize();
      expect(service.state.status, CooccurrenceDataPackStatus.unavailable);
      expect(
        await service.queryRelatedTags('alpha', limit: 10, minCount: 1),
        isEmpty,
      );

      await service.install();

      expect(service.state.status, CooccurrenceDataPackStatus.ready);
      expect(service.state.installedVersion, fixture.manifest.dataVersion);
      expect(service.state.relationCount, 2);
      expect(service.isQueryReady, isTrue);
      expect(await service.queryRelatedTags('ALPHA', limit: 10, minCount: 1), [
        {'related_tag': 'beta', 'count': 50},
        {'related_tag': 'gamma', 'count': 10},
      ]);
      expect(await service.queryRelatedTags('alpha', limit: 10, minCount: 20), [
        {'related_tag': 'beta', 'count': 50},
      ]);
      expect(await service.queryPairCooccurrence('alpha', 'beta'), 50);
      expect(await service.querySummedCooccurrence('alpha'), 60);
      expect(await service.queryRelatedTagCount('alpha'), 2);
      expect(await service.queryPairCount(), 2);

      final installedDirectory = Directory(
        p.join(supportDirectory.path, 'autocomplete', 'cooccurrence'),
      );
      expect(
        await File(
          p.join(installedDirectory.path, fixture.manifest.databaseName),
        ).exists(),
        isTrue,
      );
      expect(
        await File(p.join(installedDirectory.path, 'install.json')).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(installedDirectory.path, fixture.manifest.archiveName),
        ).exists(),
        isFalse,
      );

      await service.deleteData();

      expect(service.state.status, CooccurrenceDataPackStatus.unavailable);
      expect(service.state.installedVersion, isNull);
      expect(service.isQueryReady, isFalse);
      expect(
        await service.queryRelatedTags('alpha', limit: 10, minCount: 1),
        isEmpty,
      );
      expect(await installedDirectory.list().toList(), isEmpty);
    });

    test(
      'removes a corrupted installed database and degrades queries',
      () async {
        final manifest = fixture.manifestWithDownloadUri(await serveArchive());
        final installer = createService(manifest: manifest);
        await installer.install();
        expect(installer.state.status, CooccurrenceDataPackStatus.ready);
        await installer.close();
        services.remove(installer);

        final target = File(
          p.join(
            supportDirectory.path,
            'autocomplete',
            'cooccurrence',
            fixture.manifest.databaseName,
          ),
        );
        final bytes = await target.readAsBytes();
        bytes[0] ^= 0xff;
        await target.writeAsBytes(bytes, flush: true);

        final restarted = createService(manifest: manifest);
        await restarted.initialize();

        expect(restarted.state.status, CooccurrenceDataPackStatus.error);
        expect(
          restarted.state.error,
          CooccurrenceDataPackError.databaseIntegrity,
        );
        expect(restarted.isQueryReady, isFalse);
        expect(await restarted.queryPairCount(), 0);
        expect(
          await restarted.queryRelatedTags('alpha', limit: 10, minCount: 1),
          isEmpty,
        );
        expect(await target.exists(), isFalse);
        expect(
          await File(p.join(target.parent.path, 'install.json')).exists(),
          isFalse,
        );
      },
    );

    test('rejects a truncated GZip and removes partial output', () async {
      final truncated = fixture.archiveBytes.sublist(
        0,
        fixture.archiveBytes.length ~/ 2,
      );
      final manifest = fixture.manifestWithPayload(
        downloadUri: await serveBytes(truncated),
        archiveBytes: truncated,
      );
      final service = createService(manifest: manifest);

      await service.install();

      expect(service.state.status, CooccurrenceDataPackStatus.error);
      expect(service.state.error, CooccurrenceDataPackError.archiveIntegrity);
      final installedDirectory = Directory(
        p.join(supportDirectory.path, 'autocomplete', 'cooccurrence'),
      );
      expect(
        await File(
          p.join(
            installedDirectory.path,
            '${manifest.databaseName}.installing',
          ),
        ).exists(),
        isFalse,
      );
      expect(
        await File(
          p.join(installedDirectory.path, manifest.archiveName),
        ).exists(),
        isFalse,
      );
    });

    test('rejects a decompressed payload that is not SQLite', () async {
      final databaseBytes = utf8.encode('not a SQLite database');
      final archiveBytes = gzip.encode(databaseBytes);
      final manifest = fixture.manifestWithPayload(
        downloadUri: await serveBytes(archiveBytes),
        archiveBytes: archiveBytes,
        databaseBytes: databaseBytes,
      );
      final service = createService(manifest: manifest);

      await service.install();

      expect(service.state.status, CooccurrenceDataPackStatus.error);
      expect(service.state.error, CooccurrenceDataPackError.databaseIntegrity);
      expect(service.isQueryReady, isFalse);
    });

    test('rejects a database whose metadata does not match manifest', () async {
      final invalidDatabase = File(
        p.join(tempDirectory.path, 'invalid-meta.db'),
      );
      await fixture.databaseFile.copy(invalidDatabase.path);
      final database = native.sqlite3.open(invalidDatabase.path);
      database.execute(
        "UPDATE metadata SET value = '1' WHERE key = 'schema_version'",
      );
      database.dispose();
      final databaseBytes = await invalidDatabase.readAsBytes();
      final archiveBytes = gzip.encode(databaseBytes);
      final manifest = fixture.manifestWithPayload(
        downloadUri: await serveBytes(archiveBytes),
        archiveBytes: archiveBytes,
        databaseBytes: databaseBytes,
      );
      final service = createService(manifest: manifest);

      await service.install();

      expect(service.state.status, CooccurrenceDataPackStatus.error);
      expect(service.state.error, CooccurrenceDataPackError.databaseIntegrity);
      expect(service.isQueryReady, isFalse);
    });

    test(
      'rejects decompressed output larger than the manifest limit',
      () async {
        final manifest = fixture.manifestWithPayload(
          downloadUri: await serveArchive(),
          archiveBytes: fixture.archiveBytes,
          databaseSize: fixture.manifest.databaseSize - 1,
        );
        final service = createService(manifest: manifest);

        await service.install();

        expect(service.state.status, CooccurrenceDataPackStatus.error);
        expect(service.state.error, CooccurrenceDataPackError.archiveIntegrity);
        expect(service.isQueryReady, isFalse);
      },
    );

    test('deduplicates concurrent installation requests', () async {
      final downloader = _BlockingDownloader(fixture.archiveFile);
      final service = createService(downloader: downloader);
      await service.initialize();

      final first = service.install();
      await downloader.started.future;
      final second = service.install();
      await Future<void>.delayed(Duration.zero);

      expect(downloader.callCount, 1);
      downloader.release.complete();
      await Future.wait([first, second]);

      expect(downloader.callCount, 1);
      expect(service.state.status, CooccurrenceDataPackStatus.ready);
      expect(await service.queryPairCooccurrence('alpha', 'beta'), 50);
    });

    test('recovers interrupted atomic install metadata replacement', () async {
      final uri = await serveArchive();
      final manifest = fixture.manifestWithDownloadUri(uri);
      final installer = createService(manifest: manifest);
      await installer.install();
      await installer.close();

      final installedDirectory = Directory(
        p.join(supportDirectory.path, 'autocomplete', 'cooccurrence'),
      );
      final metadata = File(p.join(installedDirectory.path, 'install.json'));
      final metadataBackup = File('${metadata.path}.backup');
      final metadataTemporary = File('${metadata.path}.tmp');
      await metadata.rename(metadataBackup.path);
      await metadataTemporary.writeAsString('interrupted replacement');

      final recovered = createService(manifest: manifest);
      await recovered.initialize();

      expect(recovered.state.status, CooccurrenceDataPackStatus.ready);
      expect(recovered.isQueryReady, isTrue);
      expect(await metadata.exists(), isTrue);
      expect(await metadataBackup.exists(), isFalse);
      expect(await metadataTemporary.exists(), isFalse);
      await recovered.close();
    });

    test(
      'recovers a valid backup when the replacement target is corrupt',
      () async {
        final installedDirectory = Directory(
          p.join(supportDirectory.path, 'autocomplete', 'cooccurrence'),
        );
        await installedDirectory.create(recursive: true);
        final target = File(
          p.join(installedDirectory.path, fixture.manifest.databaseName),
        );
        final backup = File('${target.path}.backup');
        await fixture.databaseFile.copy(backup.path);
        final corrupted = await fixture.databaseFile.readAsBytes();
        corrupted[0] ^= 0xff;
        await target.writeAsBytes(corrupted, flush: true);

        final service = createService();
        await service.initialize();

        expect(service.state.status, CooccurrenceDataPackStatus.ready);
        expect(service.isQueryReady, isTrue);
        expect(await backup.exists(), isFalse);
        expect(await target.exists(), isTrue);
        expect(await service.queryPairCooccurrence('alpha', 'beta'), 50);
      },
    );
  });
}

Map<String, dynamic> _validManifestJson() => {
  'manifestVersion': 1,
  'schemaVersion': 2,
  'dataVersion': 'fixture-v2',
  'release': {
    'tag': 'autocomplete-data-cooccurrence-fixture-v2',
    'url':
        'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
        'download/autocomplete-data-cooccurrence-fixture-v2/'
        'cooccurrence-v2.db.gz',
    'prerelease': true,
    'makeLatest': false,
  },
  'archive': {'name': 'cooccurrence-v2.db.gz', 'size': 100, 'sha256': 'a' * 64},
  'database': {'name': 'cooccurrence-v2.db', 'size': 200, 'sha256': 'b' * 64},
  'counts': {
    'sourcePairCount': 2,
    'selfRelationCount': 0,
    'directedEdgeCount': 4,
    'tagCount': 3,
  },
  'provenance': {
    'sourceRevision': '0123456789012345678901234567890123456789',
    'sourceUrl':
        'https://huggingface.co/datasets/example/data/resolve/'
        '0123456789012345678901234567890123456789/source.csv',
    'sourceSha256': 'c' * 64,
  },
};

class _DataPackFixture {
  const _DataPackFixture({
    required this.databaseFile,
    required this.archiveFile,
    required this.archiveBytes,
    required this.manifest,
  });

  final File databaseFile;
  final File archiveFile;
  final List<int> archiveBytes;
  final CooccurrenceDataPackManifest manifest;

  static const sourceRevision = '0123456789012345678901234567890123456789';
  static const sourceUrl =
      'https://huggingface.co/datasets/example/data/resolve/'
      '$sourceRevision/source.csv';
  static const sourceSha256 =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  static Future<_DataPackFixture> create(Directory root) async {
    final databaseFile = File(p.join(root.path, 'fixture-cooccurrence.db'));
    final database = native.sqlite3.open(databaseFile.path);
    database.execute('''
      CREATE TABLE metadata(
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
      );
      CREATE TABLE edges(
        source_tag_id INTEGER NOT NULL,
        target_tag_id INTEGER NOT NULL,
        count INTEGER NOT NULL CHECK(count > 0),
        PRIMARY KEY(source_tag_id, count DESC, target_tag_id)
      ) WITHOUT ROWID;
      INSERT INTO metadata VALUES
        ('schema_version', '2'),
        ('data_version', 'fixture-v2'),
        ('source_revision', '$sourceRevision'),
        ('source_url', '$sourceUrl'),
        ('source_sha256', '$sourceSha256'),
        ('source_pair_count', '2'),
        ('self_relation_count', '0'),
        ('tag_count', '3'),
        ('directed_edge_count', '4');
      INSERT INTO tags VALUES
        (1, 'alpha'),
        (2, 'beta'),
        (3, 'gamma');
      INSERT INTO edges VALUES
        (1, 2, 50),
        (2, 1, 50),
        (1, 3, 10),
        (3, 1, 10);
    ''');
    database.dispose();

    final databaseBytes = await databaseFile.readAsBytes();
    final archiveBytes = gzip.encode(databaseBytes);
    final archiveFile = File(p.join(root.path, 'fixture-cooccurrence.db.gz'));
    await archiveFile.writeAsBytes(archiveBytes, flush: true);
    final manifest = CooccurrenceDataPackManifest(
      dataVersion: 'fixture-v2',
      schemaVersion: 2,
      releaseTag: 'autocomplete-data-cooccurrence-fixture-v2',
      archiveName: 'cooccurrence-v2.db.gz',
      downloadUri: Uri.parse('https://github.com/fixture/archive.gz'),
      archiveSize: archiveBytes.length,
      archiveSha256: sha256.convert(archiveBytes).toString(),
      databaseName: 'cooccurrence-v2.db',
      databaseSize: databaseBytes.length,
      databaseSha256: sha256.convert(databaseBytes).toString(),
      sourcePairCount: 2,
      selfRelationCount: 0,
      directedEdgeCount: 4,
      tagCount: 3,
      sourceRevision: sourceRevision,
      sourceUrl: sourceUrl,
      sourceSha256: sourceSha256,
    );
    return _DataPackFixture(
      databaseFile: databaseFile,
      archiveFile: archiveFile,
      archiveBytes: archiveBytes,
      manifest: manifest,
    );
  }

  CooccurrenceDataPackManifest manifestWithDownloadUri(Uri downloadUri) =>
      manifestWithPayload(downloadUri: downloadUri, archiveBytes: archiveBytes);

  CooccurrenceDataPackManifest manifestWithPayload({
    required Uri downloadUri,
    required List<int> archiveBytes,
    List<int>? databaseBytes,
    int? databaseSize,
  }) {
    final resolvedDatabaseBytes =
        databaseBytes ?? databaseFile.readAsBytesSync();
    return CooccurrenceDataPackManifest(
      dataVersion: manifest.dataVersion,
      schemaVersion: manifest.schemaVersion,
      releaseTag: manifest.releaseTag,
      archiveName: manifest.archiveName,
      downloadUri: downloadUri,
      archiveSize: archiveBytes.length,
      archiveSha256: sha256.convert(archiveBytes).toString(),
      databaseName: manifest.databaseName,
      databaseSize: databaseSize ?? resolvedDatabaseBytes.length,
      databaseSha256: sha256.convert(resolvedDatabaseBytes).toString(),
      sourcePairCount: manifest.sourcePairCount,
      selfRelationCount: manifest.selfRelationCount,
      directedEdgeCount: manifest.directedEdgeCount,
      tagCount: manifest.tagCount,
      sourceRevision: manifest.sourceRevision,
      sourceUrl: manifest.sourceUrl,
      sourceSha256: manifest.sourceSha256,
    );
  }
}

class _BlockingDownloader extends VerifiedResumableDownloader {
  _BlockingDownloader(this.source) : super(dio: Dio());

  final File source;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  int callCount = 0;

  @override
  Future<VerifiedDownloadResult> download({
    required Uri uri,
    required File targetFile,
    required int expectedSize,
    required String expectedSha256,
    void Function(VerifiedDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    if (!started.isCompleted) started.complete();
    await release.future;
    await targetFile.parent.create(recursive: true);
    await source.copy(targetFile.path);
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
      reusedExistingFile: false,
    );
  }
}
