import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/traditional_chinese_converter.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_download.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_models.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/core/database/datasources/translation_data_source.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

void main() {
  late Directory temp;
  late ZhDictionaryService service;
  late TranslationDataSource reader;

  setUp(() async {
    sqfliteFfiInit();
    final scratch = await Directory('tool/.tmp').create(recursive: true);
    temp = await scratch.absolute.createTemp('zh_dictionary_test_');
    reader = TranslationDataSource(
      applicationSupportDirectory: () async => temp,
    );
    service = ZhDictionaryService(
      translations: reader,
      traditionalChineseConverter: TraditionalChineseConverter(
        loadString: (_) =>
            File('assets/data/opencc/TSCharacters.txt').readAsString(),
      ),
    );
  });

  tearDown(() async {
    await reader.dispose();
    await service.remove();
    service.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('validates the upstream tags schema and quick_check', () async {
    final file = _createDictionary('${temp.path}/valid.sqlite', rows: 1000);

    expect(await service.validateDatabaseFile(file.path), 1000);
  });

  test(
    'concurrent initialization waits for the installed dictionary',
    () async {
      final directory = Directory(p.join(temp.path, 'autocomplete', 'ffdkj'));
      await directory.create(recursive: true);
      _createDictionary(p.join(directory.path, 'tag.sqlite'), rows: 1000);
      final supportDirectory = Completer<Directory>();
      var directoryRequests = 0;
      service.dispose();
      reader = TranslationDataSource(
        applicationSupportDirectory: () {
          directoryRequests++;
          return supportDirectory.future;
        },
      );
      service = ZhDictionaryService(translations: reader);
      final startup = service.initialize();
      final editorHint = service.initialize();
      supportDirectory.complete(temp);
      expect(editorHint, same(startup));
      expect(directoryRequests, 1);
      expect(service.state.isInstalled, isFalse);
      await editorHint;
      expect(service.state.isInstalled, isTrue);
      expect(service.state.tagCount, 1000);
      expect(await service.resolve(['tag_0'], locale: 'zh-CN'), {
        'tag_0': '标签0',
      });
      await service.initialize();
      expect(directoryRequests, 1);
    },
  );

  test('initialization failures remain visible and can be retried', () async {
    var attempts = 0;
    service.dispose();
    reader = TranslationDataSource(
      applicationSupportDirectory: () {
        if (++attempts == 1) {
          throw const FileSystemException('support directory unavailable');
        }
        return Future.value(temp);
      },
    );
    service = ZhDictionaryService(translations: reader);
    await expectLater(
      service.initialize(),
      throwsA(isA<FileSystemException>()),
    );
    await service.initialize();
    expect(attempts, 2);
    expect(service.state.isInstalled, isFalse);
  });

  test('searches the Simplified dictionary with Traditional input', () async {
    final dictionaryDirectory = Directory(
      p.join(temp.path, 'autocomplete', 'ffdkj'),
    );
    await dictionaryDirectory.create(recursive: true);
    _createDictionary(
      p.join(dictionaryDirectory.path, 'tag.sqlite'),
      rows: 1000,
    );

    final results = await service.search(
      const CompletionQuery(
        fullText: '標籤',
        cursorPosition: 2,
        token: '標籤',
        replacementRange: TextReplacementRange(start: 0, end: 2),
        existingTags: {},
        limit: 20,
        locale: 'zh_Hant',
      ),
    );

    expect(results, isNotEmpty);
    expect(results.first.canonicalTag, 'tag_0');
    expect(results.first.translation, '标签0');
  });

  test('fuzzy translation only restores one missing character', () async {
    final dictionaryDirectory = Directory(
      p.join(temp.path, 'autocomplete', 'ffdkj'),
    );
    await dictionaryDirectory.create(recursive: true);
    _createDictionary(
      p.join(dictionaryDirectory.path, 'tag.sqlite'),
      rows: 1000,
      extraRows: const {'toddler': '幼儿', 'screentones': '网点', 'fever': '发烧'},
    );

    final result = await service.resolveFuzzy([
      '',
      'a',
      '3d',
      '::',
      'todder',
      'screentone',
      'fewer',
      'artist:mx2j',
      'year_2026',
    ]);

    expect(result, {'todder': '幼儿', 'screentone': '网点'});
  });

  test('rejects a corrupt SQLite file', () async {
    final file = File('${temp.path}/corrupt.sqlite');
    await file.writeAsString('not a sqlite database');

    expect(() => service.validateDatabaseFile(file.path), throwsStateError);
  });

  test(
    'rejects a dictionary with an incompatible schema or too few rows',
    () async {
      final wrongSchema = File(p.join(temp.path, 'wrong.sqlite'));
      final db = native.sqlite3.open(wrongSchema.path);
      db.execute('CREATE TABLE tags(name TEXT, cn_name TEXT)');
      db.dispose();
      final tooSmall = _createDictionary('${temp.path}/small.sqlite', rows: 10);

      expect(
        () => service.validateDatabaseFile(wrongSchema.path),
        throwsStateError,
      );
      expect(
        () => service.validateDatabaseFile(tooSmall.path),
        throwsStateError,
      );
    },
  );

  test(
    'classifies a GitHub primary rate-limit 403 as metadata failure',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _RoutingAdapter((_) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'API rate limit exceeded'}),
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-ratelimit-limit': ['60'],
            'x-ratelimit-remaining': ['0'],
            'x-ratelimit-reset': ['1787894138'],
            'x-github-request-id': ['RATE-LIMIT-TEST'],
          },
        );
      });

      await expectLater(
        ZhDictionaryDownloader(dio: dio).fetchLatestSource(),
        throwsA(
          isA<ZhDictionaryException>()
              .having(
                (error) => error.stage,
                'stage',
                ZhDictionaryFailureStage.metadata,
              )
              .having(
                (error) => error.kind,
                'kind',
                ZhDictionaryFailureKind.rateLimited,
              )
              .having(
                (error) => error.diagnostic,
                'diagnostic',
                allOf(
                  contains('api.github.com'),
                  contains('RATE-LIMIT-TEST'),
                  contains('x-ratelimit-reset'),
                ),
              ),
        ),
      );
    },
  );

  test('distinguishes a non-rate-limit metadata 403', () async {
    final dio = Dio();
    dio.httpClientAdapter = _RoutingAdapter(
      (_) => ResponseBody.fromString(
        jsonEncode({'message': 'Forbidden'}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'x-ratelimit-remaining': ['42'],
        },
      ),
    );

    await expectLater(
      ZhDictionaryDownloader(dio: dio).fetchLatestSource(),
      throwsA(
        isA<ZhDictionaryException>()
            .having(
              (error) => error.stage,
              'stage',
              ZhDictionaryFailureStage.metadata,
            )
            .having(
              (error) => error.kind,
              'kind',
              ZhDictionaryFailureKind.accessDenied,
            ),
      ),
    );
  });

  test('pins latest metadata and raw download to the same commit', () async {
    const commitSha = '2222222222222222222222222222222222222222';
    const blobSha = '3333333333333333333333333333333333333333';
    final adapter = _RoutingAdapter((request) {
      if (request.uri.path.endsWith('/commits')) {
        return ResponseBody.fromString(
          jsonEncode([
            {'sha': commitSha},
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      expect(request.uri.queryParameters['ref'], commitSha);
      return ResponseBody.fromString(
        jsonEncode({'path': 'tag.sqlite', 'sha': blobSha, 'size': 1234}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'etag': ['"$blobSha"'],
        },
      );
    });
    final dio = Dio()..httpClientAdapter = adapter;

    final source = await ZhDictionaryDownloader(dio: dio).fetchLatestSource();

    expect(source.commitSha, commitSha);
    expect(source.blobSha, blobSha);
    expect(source.size, 1234);
    expect(
      source.downloadUri.toString(),
      'https://raw.githubusercontent.com/ffdkj/'
      'ffdkj-Danbooru_Tag-Chinese-English-Translation-Table/'
      '$commitSha/tag.sqlite',
    );
    expect(adapter.requests, hasLength(2));
  });

  test('distinguishes a raw download 403 from metadata failures', () async {
    final source = _testSource(const [1, 2, 3]);
    final dio = Dio();
    dio.httpClientAdapter = _RoutingAdapter(
      (_) => ResponseBody.fromString('Access denied', 403),
    );

    await expectLater(
      ZhDictionaryDownloader(
        dio: dio,
      ).download(source, p.join(temp.path, 'denied.sqlite')),
      throwsA(
        isA<ZhDictionaryException>()
            .having(
              (error) => error.stage,
              'stage',
              ZhDictionaryFailureStage.download,
            )
            .having(
              (error) => error.kind,
              'kind',
              ZhDictionaryFailureKind.accessDenied,
            )
            .having(
              (error) => error.diagnostic,
              'diagnostic',
              contains('raw.githubusercontent.com'),
            ),
      ),
    );
  });

  test(
    'falls back to the official Git blob endpoint when raw is blocked',
    () async {
      const bytes = [1, 2, 3, 4];
      final source = _testSource(bytes);
      final adapter = _RoutingAdapter((request) {
        if (request.uri.host == 'raw.githubusercontent.com') {
          return ResponseBody.fromString('Access denied', 403);
        }
        expect(request.uri.host, 'api.github.com');
        expect(request.uri.path, endsWith('/git/blobs/${source.blobSha}'));
        expect(request.headers['Accept'], 'application/vnd.github.raw+json');
        return ResponseBody.fromBytes(bytes, 200);
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final target = File(p.join(temp.path, 'blob-fallback.sqlite'));

      await ZhDictionaryDownloader(dio: dio).download(source, target.path);

      expect(await target.readAsBytes(), bytes);
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'installs the pinned immutable raw source without using GitHub API',
    () async {
      final upstream = _createDictionary(
        p.join(temp.path, 'upstream.sqlite'),
        rows: 1000,
      );
      final bytes = await upstream.readAsBytes();
      final source = _testSource(bytes);
      final adapter = _RoutingAdapter(
        (request) => ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            Headers.contentLengthHeader: ['${bytes.length}'],
            Headers.contentTypeHeader: ['application/octet-stream'],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      service.dispose();
      service = ZhDictionaryService(
        dio: dio,
        pinnedSource: source,
        translations: reader,
      );

      await service.installOrUpdate();

      expect(service.state.isInstalled, isTrue);
      expect(service.state.tagCount, 1000);
      expect(service.state.version, source.blobSha);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri, source.downloadUri);
      expect(adapter.requests.single.uri.host, 'raw.githubusercontent.com');
      expect(
        await File(
          p.join(temp.path, 'autocomplete', 'ffdkj', 'tag.sqlite'),
        ).readAsBytes(),
        bytes,
      );
    },
  );

  test(
    'rejects a complete download whose declared Git blob SHA is wrong',
    () async {
      final upstream = _createDictionary(
        p.join(temp.path, 'tampered.sqlite'),
        rows: 1000,
      );
      final bytes = await upstream.readAsBytes();
      final validSource = _testSource(bytes);
      final source = ZhDictionarySource(
        commitSha: validSource.commitSha,
        blobSha: '0000000000000000000000000000000000000000',
        sha256: validSource.sha256,
        size: validSource.size,
        downloadUri: validSource.downloadUri,
      );
      final dio = Dio()
        ..httpClientAdapter = _RoutingAdapter(
          (_) => ResponseBody.fromBytes(bytes, 200),
        );
      service.dispose();
      service = ZhDictionaryService(
        dio: dio,
        pinnedSource: source,
        translations: reader,
      );

      await expectLater(
        service.installOrUpdate(),
        throwsA(
          isA<ZhDictionaryException>()
              .having(
                (error) => error.stage,
                'stage',
                ZhDictionaryFailureStage.integrity,
              )
              .having(
                (error) => error.kind,
                'kind',
                ZhDictionaryFailureKind.integrity,
              ),
        ),
      );
      expect(service.state.isInstalled, isFalse);
      expect(service.state.failureStage, ZhDictionaryFailureStage.integrity);
      expect(
        File(
          p.join(temp.path, 'autocomplete', 'ffdkj', 'tag.sqlite'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  group('installed dictionary file operations', () {
    late File target;
    late File metadata;
    late List<int> oldBytes;
    late ZhDictionarySource update;
    late _RoutingAdapter adapter;
    late Dio dio;

    setUp(() async {
      target = await reader.databaseFile;
      await target.parent.create(recursive: true);
      oldBytes = await _createDictionary(
        target.path,
        rows: 1000,
        extraRows: {'key': '旧译'},
      ).readAsBytes();
      metadata = File(p.join(target.parent.path, 'metadata.json'));
      await metadata.writeAsString(
        jsonEncode({'blobSha': _gitBlobSha(oldBytes)}),
      );
      final bytes = await _createDictionary(
        p.join(temp.path, 'upstream.sqlite'),
        rows: 1000,
        extraRows: {'key': '新译'},
      ).readAsBytes();
      update = _testSource(bytes);
      adapter = _RoutingAdapter((request) {
        if (request.uri == update.downloadUri) {
          return ResponseBody.fromBytes(bytes, 200);
        }
        final Object body;
        if (request.uri.path.endsWith('/commits')) {
          body = [
            {'sha': update.commitSha},
          ];
        } else {
          expect(request.uri.path, endsWith('/contents/tag.sqlite'));
          body = {
            'path': 'tag.sqlite',
            'sha': update.blobSha,
            'size': update.size,
          };
        }
        return ResponseBody.fromString(
          jsonEncode(body),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      dio = Dio()..httpClientAdapter = adapter;
      service.dispose();
      service = ZhDictionaryService(
        translations: reader,
        dio: dio,
        pinnedSource: update,
      );
    });

    test(
      'updates with an open reader and refreshes the same cached tag',
      () async {
        expect(await reader.query('key'), '旧译');
        expect(await reader.query('key'), '旧译');
        expect(reader.getCacheStatistics()['hitCount'], 1);
        expect(await service.checkForUpdate(force: true), isTrue);

        await service.installOrUpdate();

        expect(service.state.version, update.blobSha);
        expect(await reader.queryBatch(['key']), {'key': '新译'});
        expect(await reader.query('key'), '新译');
      },
    );

    test(
      'repairs the same version and removes only dictionary sidecars',
      () async {
        await metadata.writeAsString(jsonEncode({'blobSha': update.blobSha}));
        await service.initialize();
        expect(await reader.query('key'), '旧译');
        final priorRevision = service.installRevision;
        final sidecars = await _writeSidecars(target);
        final unrelated = await File(
          '${target.path}.notes',
        ).writeAsString('keep');

        await service.installOrUpdate();

        expect(adapter.requests.single.uri, update.downloadUri);
        expect(service.installRevision, priorRevision + 1);
        expect(await reader.query('key'), '新译');
        for (final file in sidecars) {
          expect(await file.exists(), isFalse, reason: p.basename(file.path));
        }
        expect(await unrelated.readAsString(), 'keep');
        expect(await target.parent.list().length, 3);
      },
    );

    test(
      'removes the open database, its cached result and staging files',
      () async {
        await service.initialize();
        expect(await reader.query('key'), '旧译');
        await File('${target.path}.downloading').writeAsString('partial');
        await _writeSidecars(target);
        final unrelated = await File(
          '${target.path}.notes',
        ).writeAsString('keep');

        await service.remove();

        expect(service.state.isInstalled, isFalse);
        expect(await reader.query('key'), isNull);
        expect(await target.parent.list().map((entry) => entry.path).toList(), [
          unrelated.path,
        ]);
      },
    );

    test(
      'restores the original database and sidecars if writing metadata fails',
      () async {
        final wal = File('${target.path}-wal');
        final shm = File('${target.path}-shm');
        final files = <File, List<int>>{};
        final writer = native.sqlite3.open(target.path);
        try {
          writer.execute('PRAGMA journal_mode=WAL');
          writer.execute(
            "UPDATE tags SET cn_name = '旧库日志中的译文' WHERE name = 'key'",
          );
          for (final file in [target, wal, shm]) {
            files[file] = await file.readAsBytes();
          }
        } finally {
          writer.dispose();
        }
        // Restore the snapshot taken before the last writer checkpointed its WAL.
        for (final entry in files.entries) {
          await entry.key.writeAsBytes(entry.value);
        }
        await service.initialize();
        expect(await reader.query('key'), '旧库日志中的译文');
        await metadata.delete();
        await Directory(metadata.path).create();

        await expectLater(
          service.installOrUpdate(),
          throwsA(isA<FileSystemException>()),
        );

        expect(service.state.isInstalled, isTrue);
        expect(service.state.version, _gitBlobSha(oldBytes));
        expect(await target.readAsBytes(), files[target]);
        expect(await wal.readAsBytes(), files[wal]);
        expect(reader.getCacheStatistics()['size'], 0);
        expect(await reader.query('key'), '旧库日志中的译文');
        expect(await service.resolve(['tag_999'], locale: 'zh-CN'), {
          'tag_999': '标签999',
        });
      },
    );

    test(
      'removal waits for an active download while the old dictionary stays readable',
      () async {
        final downloading = Completer<void>();
        final resume = Completer<void>();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              if (request.uri == update.downloadUri) {
                downloading.complete();
                await resume.future;
              }
              handler.next(request);
            },
          ),
        );
        final install = service.installOrUpdate();
        await downloading.future;
        final sameInstall = service.installOrUpdate();
        final removal = service.remove();
        try {
          expect(await reader.query('key'), '旧译');
        } finally {
          resume.complete();
          await Future.wait([install, sameInstall, removal]);
        }
        expect(
          adapter.requests.where((r) => r.uri == update.downloadUri),
          hasLength(1),
        );
        expect(await reader.query('key'), isNull);
        expect(await target.parent.list().isEmpty, isTrue);
      },
    );

    test(
      'removal retries cleanup of a locked backup after a committed update',
      () async {
        final backup = File('${target.path}.backup');
        final outer = Zone.current;
        await IOOverrides.runZoned(
          service.installOrUpdate,
          createFile: (path) => path == backup.path
              ? _LockedBackup(backup)
              : outer.run(() => File(path)),
        );
        expect(service.state.version, update.blobSha);
        expect(await reader.query('key'), '新译');
        expect(await backup.exists(), isTrue);
        await service.remove();
        expect(await backup.exists(), isFalse);
      },
    );

    test(
      'an in-flight update check cannot recreate removed metadata',
      () async {
        final checking = Completer<void>();
        final resume = Completer<void>();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              if (request.uri.path.endsWith('/commits')) {
                checking.complete();
                await resume.future;
              }
              handler.next(request);
            },
          ),
        );
        final check = service.checkForUpdate(force: true);
        await checking.future;
        final removal = service.remove();
        try {
          expect(await reader.query('key'), '旧译');
        } finally {
          resume.complete();
          await check;
          await removal;
        }
        expect(service.state.isInstalled, isFalse);
        expect(await target.parent.list().isEmpty, isTrue);
      },
    );
  });
}

class _LockedBackup extends Fake implements File {
  _LockedBackup(this.file);
  final File file;

  @override
  String get path => file.path;

  @override
  Future<bool> exists() => file.exists();

  @override
  Future<File> delete({bool recursive = false}) async {
    throw FileSystemException('Backup is in use', path);
  }
}

Future<List<File>> _writeSidecars(File target) async {
  final files = [
    for (final base in [target.path, '${target.path}.downloading'])
      for (final suffix in ['-wal', '-shm', '-journal']) File('$base$suffix'),
  ];
  for (final file in files) {
    await file.writeAsString('sidecar');
  }
  return files;
}

ZhDictionarySource _testSource(List<int> bytes) {
  const commitSha = '1111111111111111111111111111111111111111';
  return ZhDictionarySource(
    commitSha: commitSha,
    blobSha: _gitBlobSha(bytes),
    sha256: sha256.convert(bytes).toString(),
    size: bytes.length,
    downloadUri: Uri.parse(
      'https://raw.githubusercontent.com/ffdkj/'
      'ffdkj-Danbooru_Tag-Chinese-English-Translation-Table/'
      '$commitSha/tag.sqlite',
    ),
  );
}

String _gitBlobSha(List<int> bytes) => sha1.convert([
  ...utf8.encode('blob ${bytes.length}\u0000'),
  ...bytes,
]).toString();

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions request) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

File _createDictionary(
  String path, {
  required int rows,
  Map<String, String> extraRows = const {},
}) {
  final db = native.sqlite3.open(path);
  db.execute('''
    CREATE TABLE tags(
      name TEXT PRIMARY KEY,
      category INTEGER,
      cn_name TEXT,
      post_count INTEGER
    )
  ''');
  final statement = db.prepare(
    'INSERT INTO tags(name, category, cn_name, post_count) VALUES (?, ?, ?, ?)',
  );
  db.execute('BEGIN');
  for (var index = 0; index < rows; index++) {
    statement.execute(['tag_$index', 0, '标签$index', rows - index]);
  }
  for (final entry in extraRows.entries) {
    statement.execute([entry.key, 0, entry.value, 1]);
  }
  db.execute('COMMIT');
  statement.dispose();
  db.dispose();
  return File(path);
}
