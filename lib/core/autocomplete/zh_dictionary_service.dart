import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'completion_models.dart';
import 'traditional_chinese_converter.dart';
import 'zh_dictionary_download.dart';
import 'zh_dictionary_models.dart';

export 'zh_dictionary_models.dart' show ZhDictionaryState;
export 'zh_dictionary_download.dart' show ffdkjRepositoryUrl;

class ZhDictionaryService extends ChangeNotifier
    implements CompletionSource, TranslationResolver {
  ZhDictionaryService({
    Dio? dio,
    TraditionalChineseConverter? traditionalChineseConverter,
    Future<Directory> Function()? applicationSupportDirectory,
    ZhDictionarySource? pinnedSource,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(minutes: 3),
               sendTimeout: const Duration(seconds: 15),
             ),
           ),
       _pinnedSource = pinnedSource ?? ffdkjPinnedSource,
       _traditionalChineseConverter =
           traditionalChineseConverter ?? TraditionalChineseConverter(),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Dio _dio;
  final ZhDictionarySource _pinnedSource;
  final TraditionalChineseConverter _traditionalChineseConverter;
  final Future<Directory> Function() _applicationSupportDirectory;
  Database? _database;
  CancelToken? _cancelToken;
  String? _databasePath;
  String? _metadataPath;
  ZhDictionaryState _state = const ZhDictionaryState();
  ZhDictionarySource? _pendingUpdateSource;
  Future<void>? _initialization;

  ZhDictionaryDownloader get _downloader => ZhDictionaryDownloader(dio: _dio);

  ZhDictionaryState get state => _state;

  // A resolved path does not mean the installed database has been validated.
  // Startup lookups and editor hints must wait for the same installed state.
  Future<void> initialize() =>
      _initialization ??= _initialize().onError<Object>((error, stack) {
        _initialization = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _initialize() async {
    final appDir = await _applicationSupportDirectory();
    final directory = Directory(p.join(appDir.path, 'autocomplete', 'ffdkj'));
    await directory.create(recursive: true);
    _databasePath = p.join(directory.path, 'tag.sqlite');
    _metadataPath = p.join(directory.path, 'metadata.json');
    await _loadInstalledState();
  }

  Future<void> _loadInstalledState() async {
    final file = File(_databasePath!);
    if (!await file.exists()) {
      _setState(const ZhDictionaryState());
      return;
    }
    try {
      final count = await _validate(file.path);
      final metadata = await _readMetadata();
      _setState(
        ZhDictionaryState(
          isInstalled: true,
          tagCount: count,
          version: metadata['blobSha'] as String?,
          lastCheckedAt: DateTime.tryParse(
            metadata['lastCheckedAt'] as String? ?? '',
          ),
        ),
      );
    } catch (error, stack) {
      AppLogger.e('Installed ffdkj dictionary is invalid', error, stack);
      _setState(ZhDictionaryState(error: error.toString()));
    }
  }

  Future<bool> checkForUpdate({bool force = false}) async {
    await initialize();
    if (!_state.isInstalled) return false;
    if (!force &&
        _state.lastCheckedAt != null &&
        DateTime.now().difference(_state.lastCheckedAt!) <
            const Duration(days: 1)) {
      return _state.updateAvailable;
    }
    try {
      final remote = await _downloader.fetchLatestSource();
      final now = DateTime.now();
      final available = remote.blobSha != _state.version;
      _pendingUpdateSource = available ? remote : null;
      await _writeMetadata({
        ...(await _readMetadata()),
        'lastCheckedAt': now.toUtc().toIso8601String(),
      });
      _setState(
        _state.copyWith(
          updateAvailable: available,
          lastCheckedAt: now,
          clearError: true,
        ),
      );
      return available;
    } on ZhDictionaryException catch (error, stack) {
      _recordFailure(error, stack);
      return false;
    } catch (error, stack) {
      _recordUnexpectedFailure(error, stack);
      return false;
    }
  }

  Future<void> installOrUpdate() async {
    await initialize();
    if (_state.isBusy) return;
    _cancelToken = CancelToken();
    _setState(_state.copyWith(isBusy: true, progress: 0, clearError: true));
    final target = File(_databasePath!);
    final temp = File('${target.path}.downloading');
    final backup = File('${target.path}.backup');
    try {
      final remote = await _sourceForInstall();
      await temp.deleteIfExists();
      await _downloader.download(
        remote,
        temp.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _setState(_state.copyWith(progress: received / total));
          }
        },
      );
      if (await temp.length() != remote.size) {
        throw const ZhDictionaryException(
          stage: ZhDictionaryFailureStage.integrity,
          kind: ZhDictionaryFailureKind.integrity,
          diagnostic: 'Downloaded dictionary size does not match metadata',
        );
      }
      final blobSha = await _gitBlobSha(temp);
      if (blobSha != remote.blobSha) {
        throw const ZhDictionaryException(
          stage: ZhDictionaryFailureStage.integrity,
          kind: ZhDictionaryFailureKind.integrity,
          diagnostic: 'Downloaded dictionary Git blob SHA mismatch',
        );
      }
      if (remote.sha256 != null && await _sha256(temp) != remote.sha256) {
        throw const ZhDictionaryException(
          stage: ZhDictionaryFailureStage.integrity,
          kind: ZhDictionaryFailureKind.integrity,
          diagnostic: 'Downloaded dictionary SHA-256 mismatch',
        );
      }
      final count = await _validateDownloadedDatabase(temp.path);

      await _database?.close();
      _database = null;
      await backup.deleteIfExists();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temp.rename(target.path);
        await _writeMetadata({
          'blobSha': remote.blobSha,
          'commitSha': remote.commitSha,
          if (remote.sha256 != null) 'sha256': remote.sha256,
          'etag': remote.etag,
          'size': remote.size,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
          'lastCheckedAt': DateTime.now().toUtc().toIso8601String(),
          'source': remote.downloadUri.toString(),
        });
        await backup.deleteIfExists();
      } catch (_) {
        await target.deleteIfExists();
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      _setState(
        ZhDictionaryState(
          isInstalled: true,
          tagCount: count,
          version: remote.blobSha,
          progress: 1,
          lastCheckedAt: DateTime.now(),
        ),
      );
      _pendingUpdateSource = null;
    } on ZhDictionaryException catch (error, stack) {
      _recordFailure(error, stack, isBusy: false);
      rethrow;
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) rethrow;
      _setState(_state.copyWith(isBusy: false));
    } catch (error, stack) {
      _recordUnexpectedFailure(error, stack, isBusy: false);
      rethrow;
    } finally {
      await temp.deleteIfExists();
      _cancelToken = null;
      if (_state.isBusy) _setState(_state.copyWith(isBusy: false));
    }
  }

  void cancelInstall() => _cancelToken?.cancel('Cancelled by user');

  Future<ZhDictionarySource> _sourceForInstall() async {
    if (_pendingUpdateSource != null) return _pendingUpdateSource!;
    if (!_state.isInstalled || _state.version == _pinnedSource.blobSha) {
      return _pinnedSource;
    }
    return _downloader.fetchLatestSource(cancelToken: _cancelToken);
  }

  Future<void> remove() async {
    await initialize();
    await _database?.close();
    _database = null;
    await File(_databasePath!).deleteIfExists();
    await File(_metadataPath!).deleteIfExists();
    _setState(const ZhDictionaryState());
  }

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async {
    if (!locale.toLowerCase().startsWith('zh') || canonicalTags.isEmpty) {
      return const {};
    }
    if (!await _openIfInstalled()) return const {};
    final result = <String, String>{};
    for (var offset = 0; offset < canonicalTags.length; offset += 400) {
      final chunk = canonicalTags
          .skip(offset)
          .take(400)
          .map(_normalize)
          .toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _database!.rawQuery(
        'SELECT name, cn_name FROM tags WHERE name IN ($placeholders) AND cn_name IS NOT NULL AND TRIM(cn_name) <> \'\'',
        chunk,
      );
      for (final row in rows) {
        result[row['name'] as String] = (row['cn_name'] as String).trim();
      }
    }
    return result;
  }

  /// Resolves a narrowly scoped missing-character fallback for plain words.
  ///
  /// Structured tags, artist names, identifiers and multi-word tags are
  /// deliberately excluded because an approximate match could silently change
  /// their meaning. Substitutions and extra characters are also rejected so a
  /// valid word absent from the dictionary cannot become another word such as
  /// `fewer` -> `fever`. A match is accepted only when exactly one dictionary
  /// tag with the same first character can restore one omitted character.
  Future<Map<String, String>> resolveFuzzy(List<String> canonicalTags) async {
    if (canonicalTags.isEmpty || !await _openIfInstalled()) return const {};
    final result = <String, String>{};
    for (final source in canonicalTags) {
      final tag = _normalize(source);
      if (tag.length < 5 ||
          tag.length > 12 ||
          !RegExp(r'^[a-z]+$').hasMatch(tag)) {
        continue;
      }
      final prefix = tag.substring(0, 2);
      final prefixUpperBound =
          '${prefix[0]}'
          '${String.fromCharCode(prefix.codeUnitAt(1) + 1)}';
      final rows = await _database!.rawQuery(
        '''
        SELECT name, cn_name FROM tags
        WHERE name >= ? AND name < ?
          AND LENGTH(name) = ?
          AND cn_name IS NOT NULL
          AND TRIM(cn_name) <> ''
        ORDER BY post_count DESC
        ''',
        [prefix, prefixUpperBound, tag.length + 1],
      );
      final matches = rows.where(
        (row) => _isSingleMissingCharacterAway(tag, row['name'] as String),
      );
      final unique = matches.take(2).toList(growable: false);
      if (unique.length == 1) {
        result[source] = (unique.single['cn_name'] as String).trim();
      }
    }
    return result;
  }

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    if (!query.isChinese || query.token.trim().isEmpty) return const [];
    if (!await _openIfInstalled()) return const [];
    final token = await _traditionalChineseConverter.toSimplified(
      query.token.trim(),
    );
    final escaped = _escapeLike(token);
    final requestedLimit =
        token.runes.length == 1 && CompletionResultLimits.isAll(query.limit)
        ? CompletionResultLimits.oneCharacter
        : query.limit;
    final categoryClause = query.categoryFilter == null
        ? ''
        : 'AND category = ?';
    final rows = await _database!.rawQuery(
      '''
      SELECT name, category, cn_name, post_count,
        CASE
          WHEN cn_name = ? THEN 0
          WHEN cn_name LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END AS match_rank
      FROM tags
      WHERE (cn_name = ?
         OR cn_name LIKE ? ESCAPE '\\'
         OR cn_name LIKE ? ESCAPE '\\')
      $categoryClause
      ORDER BY match_rank, post_count DESC, name ASC
      LIMIT ?
      ''',
      [
        token,
        '$escaped%',
        token,
        '$escaped%',
        '%$escaped%',
        if (query.categoryFilter != null) query.categoryFilter!.value,
        requestedLimit,
      ],
    );
    return rows
        .map((row) {
          final category =
              TagCategory.fromDanbooru(
                (row['category'] as num?)?.toInt() ?? 0,
              ) ??
              TagCategory.general;
          final rank = (row['match_rank'] as num).toInt();
          return CompletionCandidate(
            canonicalTag: row['name'] as String,
            category: category,
            postCount: (row['post_count'] as num?)?.toInt() ?? 0,
            translation: row['cn_name'] as String?,
            matchKind: rank == 0
                ? CompletionMatchKind.chineseExact
                : rank == 1
                ? CompletionMatchKind.chinesePrefix
                : CompletionMatchKind.chineseContains,
            sources: const {CompletionSourceKind.zhDictionary},
          );
        })
        .toList(growable: false);
  }

  Future<bool> _openIfInstalled() async {
    await initialize();
    if (!_state.isInstalled) return false;
    _database ??= await databaseFactoryFfi.openDatabase(
      _databasePath!,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    return true;
  }

  @visibleForTesting
  Future<int> validateDatabaseFile(String path) => _validate(path);

  Future<int> _validate(String path) async {
    final file = File(path);
    final header = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (!ascii.decode(header).startsWith('SQLite format 3')) {
      throw StateError('Invalid SQLite dictionary header');
    }
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final columns = await db.rawQuery('PRAGMA table_info(tags)');
      final names = columns.map((row) => row['name'] as String).toSet();
      if (!names.containsAll({'name', 'category', 'cn_name', 'post_count'})) {
        throw StateError('ffdkj tags schema is not supported: $names');
      }
      final countRows = await db.rawQuery('SELECT COUNT(*) AS count FROM tags');
      final count = (countRows.first['count'] as num).toInt();
      if (count < 1000) throw StateError('ffdkj dictionary has too few rows');
      final check = await db.rawQuery('PRAGMA quick_check');
      if (check.first.values.first != 'ok') {
        throw StateError('ffdkj quick_check failed');
      }
      return count;
    } finally {
      await db.close();
    }
  }

  Future<int> _validateDownloadedDatabase(String path) async {
    try {
      return await _validate(path);
    } catch (error, stack) {
      throw ZhDictionaryException(
        stage: ZhDictionaryFailureStage.integrity,
        kind: ZhDictionaryFailureKind.integrity,
        diagnostic: 'Downloaded dictionary validation failed: $error\n$stack',
      );
    }
  }

  Future<Map<String, dynamic>> _readMetadata() async {
    try {
      final file = File(_metadataPath!);
      if (!await file.exists()) return <String, dynamic>{};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMetadata(Map<String, dynamic> data) async {
    await File(
      _metadataPath!,
    ).writeAsString(jsonEncode(data), encoding: utf8, flush: true);
  }

  void _setState(ZhDictionaryState value) {
    _state = value;
    notifyListeners();
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '_');

  static bool _isSingleMissingCharacterAway(String source, String candidate) {
    if (candidate.length != source.length + 1) return false;
    var sourceIndex = 0;
    var candidateIndex = 0;
    var skipped = false;
    while (sourceIndex < source.length && candidateIndex < candidate.length) {
      if (source.codeUnitAt(sourceIndex) ==
          candidate.codeUnitAt(candidateIndex)) {
        sourceIndex++;
        candidateIndex++;
      } else if (skipped) {
        return false;
      } else {
        skipped = true;
        candidateIndex++;
      }
    }
    return true;
  }

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static Future<String> _gitBlobSha(File file) async {
    final output = _DigestCaptureSink();
    final input = sha1.startChunkedConversion(output);
    input.add(utf8.encode('blob ${await file.length()}\u0000'));
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.value.toString();
  }

  static Future<String> _sha256(File file) =>
      sha256.bind(file.openRead()).first.then((digest) => digest.toString());

  void _recordFailure(
    ZhDictionaryException error,
    StackTrace stack, {
    bool? isBusy,
  }) {
    AppLogger.e(
      'ffdkj dictionary ${error.stage.name} failure\n${error.diagnostic}',
      error,
      stack,
      'ZhDictionary',
    );
    _setState(
      _state.copyWith(
        error: error.diagnostic,
        failureStage: error.stage,
        failureKind: error.kind,
        isBusy: isBusy,
      ),
    );
  }

  void _recordUnexpectedFailure(
    Object error,
    StackTrace stack, {
    bool? isBusy,
  }) {
    final failure = ZhDictionaryException(
      stage: ZhDictionaryFailureStage.install,
      kind: ZhDictionaryFailureKind.unknown,
      diagnostic: 'Unexpected ffdkj installation failure: $error\n$stack',
    );
    _recordFailure(failure, stack, isBusy: isBusy);
  }
}

class _DigestCaptureSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('Digest is not available'));

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}
