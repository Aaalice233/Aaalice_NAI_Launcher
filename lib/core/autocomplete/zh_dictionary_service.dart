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

const ffdkjRepositoryUrl =
    'https://github.com/ffdkj/ffdkj-Danbooru_Tag-Chinese-English-Translation-Table';
const _ffdkjApiUrl =
    'https://api.github.com/repos/ffdkj/ffdkj-Danbooru_Tag-Chinese-English-Translation-Table/contents/tag.sqlite?ref=main';

class ZhDictionaryState {
  const ZhDictionaryState({
    this.isInstalled = false,
    this.isBusy = false,
    this.progress = 0,
    this.tagCount = 0,
    this.version,
    this.updateAvailable = false,
    this.lastCheckedAt,
    this.error,
  });

  final bool isInstalled;
  final bool isBusy;
  final double progress;
  final int tagCount;
  final String? version;
  final bool updateAvailable;
  final DateTime? lastCheckedAt;
  final String? error;

  ZhDictionaryState copyWith({
    bool? isInstalled,
    bool? isBusy,
    double? progress,
    int? tagCount,
    String? version,
    bool? updateAvailable,
    DateTime? lastCheckedAt,
    String? error,
    bool clearError = false,
  }) {
    return ZhDictionaryState(
      isInstalled: isInstalled ?? this.isInstalled,
      isBusy: isBusy ?? this.isBusy,
      progress: progress ?? this.progress,
      tagCount: tagCount ?? this.tagCount,
      version: version ?? this.version,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ZhDictionaryService extends ChangeNotifier
    implements CompletionSource, TranslationResolver {
  ZhDictionaryService({
    Dio? dio,
    TraditionalChineseConverter? traditionalChineseConverter,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(minutes: 3),
               sendTimeout: const Duration(seconds: 15),
               headers: const {'Accept': 'application/vnd.github+json'},
             ),
           ),
       _traditionalChineseConverter =
           traditionalChineseConverter ?? TraditionalChineseConverter(),
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Dio _dio;
  final TraditionalChineseConverter _traditionalChineseConverter;
  final Future<Directory> Function() _applicationSupportDirectory;
  Database? _database;
  CancelToken? _cancelToken;
  String? _databasePath;
  String? _metadataPath;
  ZhDictionaryState _state = const ZhDictionaryState();

  ZhDictionaryState get state => _state;

  Future<void> initialize() async {
    if (_databasePath != null) return;
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
      final remote = await _fetchRemoteMetadata();
      final now = DateTime.now();
      final available = remote.blobSha != _state.version;
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
    } catch (error) {
      _setState(_state.copyWith(error: error.toString()));
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
      final remote = await _fetchRemoteMetadata(cancelToken: _cancelToken);
      _validateDownloadUri(remote.downloadUri);
      await temp.deleteIfExists();
      await _dio.download(
        remote.downloadUri.toString(),
        temp.path,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _setState(_state.copyWith(progress: received / total));
          }
        },
      );
      if (await temp.length() != remote.size) {
        throw StateError('Downloaded dictionary size does not match GitHub');
      }
      final blobSha = await _gitBlobSha(temp);
      if (blobSha != remote.blobSha) {
        throw StateError('Downloaded dictionary Git blob SHA mismatch');
      }
      final count = await _validate(temp.path);

      await _database?.close();
      _database = null;
      await backup.deleteIfExists();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temp.rename(target.path);
        await _writeMetadata({
          'blobSha': remote.blobSha,
          'etag': remote.etag,
          'size': remote.size,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
          'lastCheckedAt': DateTime.now().toUtc().toIso8601String(),
          'source': _ffdkjApiUrl,
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
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        _setState(_state.copyWith(error: error.message, isBusy: false));
        rethrow;
      }
      _setState(_state.copyWith(isBusy: false));
    } catch (error) {
      _setState(_state.copyWith(error: error.toString(), isBusy: false));
      rethrow;
    } finally {
      await temp.deleteIfExists();
      _cancelToken = null;
      if (_state.isBusy) _setState(_state.copyWith(isBusy: false));
    }
  }

  void cancelInstall() => _cancelToken?.cancel('Cancelled by user');

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
    final rows = await _database!.rawQuery(
      '''
      SELECT name, category, cn_name, post_count,
        CASE
          WHEN cn_name = ? THEN 0
          WHEN cn_name LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END AS match_rank
      FROM tags
      WHERE cn_name = ?
         OR cn_name LIKE ? ESCAPE '\\'
         OR cn_name LIKE ? ESCAPE '\\'
      ORDER BY match_rank, post_count DESC, name ASC
      LIMIT ?
      ''',
      [token, '$escaped%', token, '$escaped%', '%$escaped%', requestedLimit],
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

  Future<_RemoteDictionaryMetadata> _fetchRemoteMetadata({
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.parse(_ffdkjApiUrl);
    _validateMetadataUri(uri);
    final response = await _dio.get<Map<String, dynamic>>(
      uri.toString(),
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data == null) throw StateError('GitHub returned empty metadata');
    final download = Uri.parse(data['download_url'] as String);
    _validateDownloadUri(download);
    return _RemoteDictionaryMetadata(
      blobSha: data['sha'] as String,
      size: (data['size'] as num).toInt(),
      downloadUri: download,
      etag: response.headers.value('etag'),
    );
  }

  static void _validateMetadataUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host != 'api.github.com') {
      throw StateError('Untrusted dictionary metadata host');
    }
  }

  static void _validateDownloadUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host != 'raw.githubusercontent.com') {
      throw StateError('Untrusted dictionary download host');
    }
    if (!uri.path.startsWith(
      '/ffdkj/ffdkj-Danbooru_Tag-Chinese-English-Translation-Table/',
    )) {
      throw StateError('Unexpected dictionary download path');
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
}

class _DigestCaptureSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('Digest is not available'));

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

class _RemoteDictionaryMetadata {
  const _RemoteDictionaryMetadata({
    required this.blobSha,
    required this.size,
    required this.downloadUri,
    required this.etag,
  });

  final String blobSha;
  final int size;
  final Uri downloadUri;
  final String? etag;
}

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}
