import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/verified_resumable_downloader.dart';
import '../utils/app_logger.dart';

const cooccurrenceDataPackManifestAsset =
    'assets/data/cooccurrence_data_pack_manifest.json';

enum CooccurrenceDataPackStatus {
  unavailable,
  checking,
  downloading,
  verifying,
  installing,
  ready,
  updateAvailable,
  error,
}

enum CooccurrenceDataPackError {
  manifest,
  network,
  diskFull,
  archiveIntegrity,
  databaseIntegrity,
  install,
  unknown,
}

class CooccurrenceDataPackState {
  const CooccurrenceDataPackState({
    this.status = CooccurrenceDataPackStatus.unavailable,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.bytesPerSecond = 0,
    this.installedVersion,
    this.availableVersion,
    this.relationCount = 0,
    this.diskBytes = 0,
    this.error,
    this.errorDetails,
  });

  final CooccurrenceDataPackStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final int bytesPerSecond;
  final String? installedVersion;
  final String? availableVersion;
  final int relationCount;
  final int diskBytes;
  final CooccurrenceDataPackError? error;
  final String? errorDetails;

  double get progress =>
      totalBytes <= 0 ? 0 : (downloadedBytes / totalBytes).clamp(0, 1);

  bool get hasInstalledData => installedVersion != null && diskBytes > 0;

  CooccurrenceDataPackState copyWith({
    CooccurrenceDataPackStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    int? bytesPerSecond,
    String? installedVersion,
    bool clearInstalledVersion = false,
    String? availableVersion,
    int? relationCount,
    int? diskBytes,
    CooccurrenceDataPackError? error,
    bool clearError = false,
    String? errorDetails,
  }) => CooccurrenceDataPackState(
    status: status ?? this.status,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    installedVersion: clearInstalledVersion
        ? null
        : installedVersion ?? this.installedVersion,
    availableVersion: availableVersion ?? this.availableVersion,
    relationCount: relationCount ?? this.relationCount,
    diskBytes: diskBytes ?? this.diskBytes,
    error: clearError ? null : error ?? this.error,
    errorDetails: clearError ? null : errorDetails ?? this.errorDetails,
  );
}

class CooccurrenceDataPackManifest {
  const CooccurrenceDataPackManifest({
    required this.dataVersion,
    required this.schemaVersion,
    required this.releaseTag,
    required this.archiveName,
    required this.downloadUri,
    required this.archiveSize,
    required this.archiveSha256,
    required this.databaseName,
    required this.databaseSize,
    required this.databaseSha256,
    required this.sourcePairCount,
    required this.selfRelationCount,
    required this.directedEdgeCount,
    required this.tagCount,
    required this.sourceRevision,
    required this.sourceUrl,
    required this.sourceSha256,
  });

  final String dataVersion;
  final int schemaVersion;
  final String releaseTag;
  final String archiveName;
  final Uri downloadUri;
  final int archiveSize;
  final String archiveSha256;
  final String databaseName;
  final int databaseSize;
  final String databaseSha256;
  final int sourcePairCount;
  final int selfRelationCount;
  final int directedEdgeCount;
  final int tagCount;
  final String sourceRevision;
  final String sourceUrl;
  final String sourceSha256;

  Map<String, dynamic> toJson() => {
    'manifestVersion': 1,
    'schemaVersion': schemaVersion,
    'dataVersion': dataVersion,
    'release': {
      'tag': releaseTag,
      'url': downloadUri.toString(),
      'prerelease': true,
      'makeLatest': false,
    },
    'archive': {
      'name': archiveName,
      'size': archiveSize,
      'sha256': archiveSha256,
    },
    'database': {
      'name': databaseName,
      'size': databaseSize,
      'sha256': databaseSha256,
    },
    'counts': {
      'sourcePairCount': sourcePairCount,
      'selfRelationCount': selfRelationCount,
      'directedEdgeCount': directedEdgeCount,
      'tagCount': tagCount,
    },
    'provenance': {
      'sourceRevision': sourceRevision,
      'sourceUrl': sourceUrl,
      'sourceSha256': sourceSha256,
    },
  };

  static CooccurrenceDataPackManifest parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['manifestVersion'] != 1) {
      throw const FormatException('Unsupported co-occurrence manifest');
    }
    final release = _map(decoded, 'release');
    final archive = _map(decoded, 'archive');
    final database = _map(decoded, 'database');
    final counts = _map(decoded, 'counts');
    final provenance = _map(decoded, 'provenance');
    final uri = Uri.parse(_string(release, 'url'));
    final releaseTag = _string(release, 'tag');
    final archiveName = _string(archive, 'name');
    final expectedPath =
        '/Aaalice233/Aaalice_NAI_Launcher/releases/download/'
        '$releaseTag/$archiveName';
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.path != expectedPath ||
        !releaseTag.startsWith('autocomplete-data-cooccurrence-') ||
        release['prerelease'] != true ||
        release['makeLatest'] != false) {
      throw const FormatException('Untrusted co-occurrence release URL');
    }
    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != 2 ||
        _string(database, 'name') != 'cooccurrence-v2.db') {
      throw const FormatException('Unsupported co-occurrence schema');
    }
    final manifest = CooccurrenceDataPackManifest(
      dataVersion: _string(decoded, 'dataVersion'),
      schemaVersion: schemaVersion!,
      releaseTag: releaseTag,
      archiveName: archiveName,
      downloadUri: uri,
      archiveSize: _positiveInt(archive, 'size'),
      archiveSha256: _sha256(archive, 'sha256'),
      databaseName: _string(database, 'name'),
      databaseSize: _positiveInt(database, 'size'),
      databaseSha256: _sha256(database, 'sha256'),
      sourcePairCount: _positiveInt(counts, 'sourcePairCount'),
      selfRelationCount: (counts['selfRelationCount'] as num?)?.toInt() ?? -1,
      directedEdgeCount: _positiveInt(counts, 'directedEdgeCount'),
      tagCount: _positiveInt(counts, 'tagCount'),
      sourceRevision: _string(provenance, 'sourceRevision'),
      sourceUrl: _string(provenance, 'sourceUrl'),
      sourceSha256: _sha256(provenance, 'sourceSha256'),
    );
    if (manifest.selfRelationCount < 0 ||
        manifest.directedEdgeCount !=
            manifest.sourcePairCount * 2 - manifest.selfRelationCount ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(manifest.sourceRevision)) {
      throw const FormatException('Invalid co-occurrence record counts');
    }
    final sourceUri = Uri.parse(manifest.sourceUrl);
    if (sourceUri.scheme != 'https' ||
        !sourceUri.path.contains(manifest.sourceRevision)) {
      throw const FormatException('Unpinned co-occurrence provenance URL');
    }
    return manifest;
  }

  static Map<String, dynamic> _map(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('Missing manifest object: $key');
    }
    return value;
  }

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing manifest string: $key');
    }
    return value;
  }

  static int _positiveInt(Map<String, dynamic> map, String key) {
    final value = (map[key] as num?)?.toInt() ?? 0;
    if (value <= 0) throw FormatException('Invalid manifest integer: $key');
    return value;
  }

  static String _sha256(Map<String, dynamic> map, String key) {
    final value = _string(map, key).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw FormatException('Invalid manifest SHA256: $key');
    }
    return value;
  }
}

typedef CooccurrenceManifestLoader =
    Future<CooccurrenceDataPackManifest> Function();
typedef ApplicationSupportDirectoryLoader = Future<Directory> Function();

class _CooccurrenceArchiveException extends FormatException {
  const _CooccurrenceArchiveException(super.message, [super.source]);
}

/// Owns the complete optional co-occurrence pack lifecycle and its read-only
/// query connection. Missing or damaged data always degrades to empty results.
class CooccurrenceDataPackService
    extends StateNotifier<CooccurrenceDataPackState> {
  CooccurrenceDataPackService({
    VerifiedResumableDownloader? downloader,
    CooccurrenceManifestLoader? manifestLoader,
    ApplicationSupportDirectoryLoader? supportDirectoryLoader,
    DatabaseFactory? databaseFactoryOverride,
  }) : _downloader = downloader ?? VerifiedResumableDownloader(dio: Dio()),
       _manifestLoader = manifestLoader ?? _loadBundledManifest,
       _supportDirectoryLoader =
           supportDirectoryLoader ?? _loadApplicationSupportDirectory,
       _databaseFactory = databaseFactoryOverride ?? databaseFactoryFfi,
       super(const CooccurrenceDataPackState());

  static const String _installMetadataName = 'install.json';

  final VerifiedResumableDownloader _downloader;
  final CooccurrenceManifestLoader _manifestLoader;
  final ApplicationSupportDirectoryLoader _supportDirectoryLoader;
  final DatabaseFactory _databaseFactory;

  CooccurrenceDataPackManifest? _manifest;
  Directory? _directory;
  Database? _database;
  Future<void>? _initialization;
  Future<void>? _activeInstall;
  CancelToken? _cancelToken;
  bool _switching = false;
  Completer<void>? _switchGate;
  int _activeQueries = 0;
  Completer<void>? _queriesDrained;
  Future<void>? _closing;
  bool _disposed = false;

  bool get isQueryReady => _database != null && !_disposed;
  String? get activeDataVersion => state.installedVersion;
  CooccurrenceDataPackManifest? get manifest => _manifest;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    try {
      final manifest = _manifest ??= await _manifestLoader();
      final support = await _supportDirectoryLoader();
      final directory = _directory ??= Directory(
        p.join(support.path, 'autocomplete', 'cooccurrence'),
      );
      await directory.create(recursive: true);
      await _recoverInstallMetadata(directory);
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.checking,
        totalBytes: manifest.archiveSize,
        availableVersion: manifest.dataVersion,
        clearError: true,
      );
      await _recoverInterruptedReplacement(directory, manifest);
      final installedManifest =
          await _readInstalledManifest(directory) ?? manifest;
      final target = _databaseFile(directory, installedManifest);
      if (!await target.exists()) {
        state = state.copyWith(
          status: CooccurrenceDataPackStatus.unavailable,
          downloadedBytes: await _partialLength(directory, manifest),
          clearInstalledVersion: true,
          relationCount: 0,
          diskBytes: 0,
        );
        return;
      }
      try {
        final database = await _validateAndOpen(target, installedManifest);
        await _replaceOpenDatabase(database);
        state = state.copyWith(
          status: installedManifest.dataVersion == manifest.dataVersion
              ? CooccurrenceDataPackStatus.ready
              : CooccurrenceDataPackStatus.updateAvailable,
          installedVersion: installedManifest.dataVersion,
          relationCount: installedManifest.sourcePairCount,
          diskBytes: await target.length(),
          downloadedBytes: manifest.archiveSize,
          clearError: true,
        );
      } catch (error, stack) {
        AppLogger.e(
          'Installed co-occurrence pack is invalid',
          error,
          stack,
          'CooccurrencePack',
        );
        await _deleteFile(target);
        await _deleteFile(_installMetadataFile(directory));
        state = state.copyWith(
          status: CooccurrenceDataPackStatus.error,
          clearInstalledVersion: true,
          relationCount: 0,
          diskBytes: 0,
          error: CooccurrenceDataPackError.databaseIntegrity,
          errorDetails: error.toString(),
        );
      }
    } catch (error, stack) {
      AppLogger.e(
        'Unable to initialize co-occurrence pack',
        error,
        stack,
        'CooccurrencePack',
      );
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.error,
        error: CooccurrenceDataPackError.manifest,
        errorDetails: error.toString(),
      );
    }
  }

  Future<void> install({bool force = false}) {
    final active = _activeInstall;
    if (active != null) return active;
    final operation = _install(force: force);
    _activeInstall = operation;
    return operation.whenComplete(() {
      if (identical(_activeInstall, operation)) _activeInstall = null;
    });
  }

  Future<void> repair() => install(force: true);

  Future<void> checkForUpdate() async {
    await initialize();
    final manifest = _manifest;
    if (manifest == null) return;
    if (_database == null) {
      state = state.copyWith(status: CooccurrenceDataPackStatus.unavailable);
    } else if (state.installedVersion == manifest.dataVersion) {
      state = state.copyWith(status: CooccurrenceDataPackStatus.ready);
    } else {
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.updateAvailable,
      );
    }
  }

  Future<void> _install({required bool force}) async {
    await initialize();
    final manifest = _manifest;
    final directory = _directory;
    if (manifest == null || directory == null) return;
    if (!force &&
        _database != null &&
        state.installedVersion == manifest.dataVersion) {
      state = state.copyWith(status: CooccurrenceDataPackStatus.ready);
      return;
    }

    final archive = File(p.join(directory.path, manifest.archiveName));
    final installing = File(
      p.join(directory.path, '${manifest.databaseName}.installing'),
    );
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(
      status: CooccurrenceDataPackStatus.downloading,
      totalBytes: manifest.archiveSize,
      downloadedBytes: await _partialLength(directory, manifest),
      bytesPerSecond: 0,
      clearError: true,
    );
    try {
      await _downloader.download(
        uri: manifest.downloadUri,
        targetFile: archive,
        expectedSize: manifest.archiveSize,
        expectedSha256: manifest.archiveSha256,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (_disposed) return;
          state = state.copyWith(
            status: CooccurrenceDataPackStatus.downloading,
            totalBytes: progress.totalBytes,
            downloadedBytes: progress.receivedBytes,
            bytesPerSecond: progress.bytesPerSecond,
          );
        },
      );
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.verifying,
        downloadedBytes: manifest.archiveSize,
        bytesPerSecond: 0,
      );
      await _deleteFile(installing);
      state = state.copyWith(status: CooccurrenceDataPackStatus.installing);
      await _decompressAndVerify(archive, installing, manifest);
      await _commitInstallation(installing, manifest);
      await _deleteFile(archive);
      await _deleteFile(File('${archive.path}.part'));
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.ready,
        installedVersion: manifest.dataVersion,
        relationCount: manifest.sourcePairCount,
        diskBytes: manifest.databaseSize,
        downloadedBytes: manifest.archiveSize,
        clearError: true,
      );
    } on VerifiedDownloadCancelledException {
      state = state.copyWith(
        status: _database == null
            ? CooccurrenceDataPackStatus.unavailable
            : CooccurrenceDataPackStatus.ready,
        downloadedBytes: await _partialLength(directory, manifest),
        bytesPerSecond: 0,
        clearError: true,
      );
    } catch (error, stack) {
      await _deleteFile(installing);
      final classifiedError = _classifyError(error);
      if (classifiedError == CooccurrenceDataPackError.archiveIntegrity ||
          classifiedError == CooccurrenceDataPackError.databaseIntegrity) {
        await _deleteFile(archive);
      }
      AppLogger.e(
        'Co-occurrence pack installation failed',
        error,
        stack,
        'CooccurrencePack',
      );
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.error,
        bytesPerSecond: 0,
        error: classifiedError,
        errorDetails: error.toString(),
      );
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('Paused by user');
  }

  Future<void> deleteData() async {
    cancelDownload();
    final active = _activeInstall;
    if (active != null) await active;
    await initialize();
    final directory = _directory;
    final manifest = _manifest;
    if (directory == null || manifest == null) return;
    await _beginSwitch();
    try {
      await _closeOpenDatabase();
      await _deleteFile(_databaseFile(directory, manifest));
      await _deleteFile(_backupFile(directory, manifest));
      await _deleteFile(
        File(p.join(directory.path, '${manifest.databaseName}.installing')),
      );
      await _deleteFile(File(p.join(directory.path, manifest.archiveName)));
      await _deleteFile(
        File(p.join(directory.path, '${manifest.archiveName}.part')),
      );
      await _deleteFile(_installMetadataFile(directory));
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.unavailable,
        clearInstalledVersion: true,
        downloadedBytes: 0,
        bytesPerSecond: 0,
        relationCount: 0,
        diskBytes: 0,
        clearError: true,
      );
    } finally {
      _endSwitch();
    }
  }

  Future<List<Map<String, Object?>>> queryRelatedTags(
    String tag, {
    required int limit,
    required int minCount,
  }) => _withDatabase(const [], (database) async {
    return database.rawQuery(
      '''
      SELECT target.name AS related_tag, edge.count AS count
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      JOIN tags target ON target.id = edge.target_tag_id
      WHERE source.name = ? COLLATE NOCASE AND edge.count >= ?
      ORDER BY edge.count DESC, edge.target_tag_id ASC
      LIMIT ?
      ''',
      [tag, minCount, limit],
    );
  });

  Future<int> queryPairCount() => _withDatabase(0, (database) async {
    final rows = await database.rawQuery(
      "SELECT value FROM metadata WHERE key = 'source_pair_count'",
    );
    return rows.isEmpty ? 0 : int.tryParse('${rows.single['value']}') ?? 0;
  });

  Future<int> queryRelatedTagCount(String tag) =>
      _withDatabase(0, (database) async {
        final rows = await database.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM tags source
          JOIN edges edge ON edge.source_tag_id = source.id
          WHERE source.name = ? COLLATE NOCASE
          ''',
          [tag],
        );
        return (rows.single['count'] as num?)?.toInt() ?? 0;
      });

  Future<int> queryPairCooccurrence(String tag1, String tag2) =>
      _withDatabase(0, (database) async {
        final rows = await database.rawQuery(
          '''
          SELECT edge.count AS count
          FROM tags source
          JOIN edges edge ON edge.source_tag_id = source.id
          JOIN tags target ON target.id = edge.target_tag_id
          WHERE source.name = ? COLLATE NOCASE
            AND target.name = ? COLLATE NOCASE
          LIMIT 1
          ''',
          [tag1, tag2],
        );
        return rows.isEmpty ? 0 : (rows.single['count'] as num?)?.toInt() ?? 0;
      });

  Future<int> querySummedCooccurrence(String tag) =>
      _withDatabase(0, (database) async {
        final rows = await database.rawQuery(
          '''
          SELECT COALESCE(SUM(edge.count), 0) AS total
          FROM tags source
          JOIN edges edge ON edge.source_tag_id = source.id
          WHERE source.name = ? COLLATE NOCASE
          ''',
          [tag],
        );
        return (rows.single['total'] as num?)?.toInt() ?? 0;
      });

  Future<T> _withDatabase<T>(
    T fallback,
    Future<T> Function(Database database) query,
  ) async {
    while (_switching) {
      await _switchGate!.future;
    }
    final database = _database;
    if (database == null || _disposed) return fallback;
    _activeQueries++;
    try {
      return await query(database);
    } catch (error, stack) {
      AppLogger.e(
        'Co-occurrence query failed; using online-only results',
        error,
        stack,
        'CooccurrencePack',
      );
      return fallback;
    } finally {
      _activeQueries--;
      if (_activeQueries == 0) {
        _queriesDrained?.complete();
        _queriesDrained = null;
      }
    }
  }

  Future<void> _decompressAndVerify(
    File archive,
    File output,
    CooccurrenceDataPackManifest manifest,
  ) async {
    var written = 0;
    final sink = output.openWrite(mode: FileMode.write);
    Object? decodeError;
    StackTrace? decodeStack;
    try {
      await for (final chunk in archive.openRead().transform(gzip.decoder)) {
        written += chunk.length;
        if (written > manifest.databaseSize) {
          throw const _CooccurrenceArchiveException(
            'Decompressed database exceeds manifest',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } catch (error, stack) {
      decodeError = error;
      decodeStack = stack;
    } finally {
      await sink.close();
    }
    if (decodeError != null) {
      await _deleteFile(output);
      if (decodeError is FileSystemException) {
        Error.throwWithStackTrace(decodeError, decodeStack!);
      }
      Error.throwWithStackTrace(
        _CooccurrenceArchiveException(
          'Unable to decompress co-occurrence archive',
          decodeError,
        ),
        decodeStack!,
      );
    }
    if (written != manifest.databaseSize) {
      await _deleteFile(output);
      throw _CooccurrenceArchiveException(
        'Decompressed database size mismatch: '
        'expected=${manifest.databaseSize} actual=$written',
      );
    }
    final hash = await VerifiedResumableDownloader.calculateSha256(output);
    if (!VerifiedResumableDownloader.equalsSha256(
      hash,
      manifest.databaseSha256,
    )) {
      await _deleteFile(output);
      throw _CooccurrenceArchiveException(
        'Decompressed database SHA256 mismatch: '
        'expected=${manifest.databaseSha256} actual=$hash',
      );
    }
    final database = await _validateAndOpen(output, manifest);
    await database.close();
  }

  Future<void> _commitInstallation(
    File installing,
    CooccurrenceDataPackManifest manifest,
  ) async {
    final directory = _directory!;
    final target = _databaseFile(directory, manifest);
    final backup = _backupFile(directory, manifest);
    final previousManifest = await _readInstalledManifest(directory);
    await _beginSwitch();
    try {
      await _closeOpenDatabase();
      await _deleteFile(backup);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await installing.rename(target.path);
        final database = await _validateAndOpen(target, manifest);
        _database = database;
        await _writeInstallMetadata(directory, manifest);
        await _deleteFile(backup);
      } catch (_) {
        await _closeOpenDatabase();
        await _deleteFile(target);
        if (await backup.exists()) {
          await backup.rename(target.path);
          final restoredManifest = previousManifest ?? manifest;
          _database = await _validateAndOpen(target, restoredManifest);
          if (previousManifest != null) {
            await _writeInstallMetadata(directory, previousManifest);
          }
        }
        rethrow;
      }
    } finally {
      _endSwitch();
    }
  }

  Future<Database> _validateAndOpen(
    File file,
    CooccurrenceDataPackManifest manifest,
  ) async {
    if (!await file.exists() || await file.length() != manifest.databaseSize) {
      throw const FormatException('Installed database size mismatch');
    }
    final actualSha256 = await VerifiedResumableDownloader.calculateSha256(
      file,
    );
    if (!VerifiedResumableDownloader.equalsSha256(
      actualSha256,
      manifest.databaseSha256,
    )) {
      throw FormatException(
        'Installed database SHA256 mismatch: '
        'expected=${manifest.databaseSha256} actual=$actualSha256',
      );
    }
    final header = await file
        .openRead(0, 16)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    if (ascii.decode(header.takeBytes(), allowInvalid: true) !=
        'SQLite format 3\u0000') {
      throw const FormatException('Installed file is not SQLite');
    }
    final database = await _databaseFactory.openDatabase(
      file.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final quickCheck = await database.rawQuery('PRAGMA quick_check');
      if (quickCheck.isEmpty || quickCheck.first.values.first != 'ok') {
        throw FormatException('SQLite quick_check failed: $quickCheck');
      }
      await _requireColumns(database, 'metadata', {'key', 'value'});
      await _requireColumns(database, 'tags', {'id', 'name'});
      await _requireColumns(database, 'edges', {
        'source_tag_id',
        'target_tag_id',
        'count',
      });
      final metadataRows = await database.query('metadata');
      final metadata = {
        for (final row in metadataRows) '${row['key']}': '${row['value']}',
      };
      final expected = <String, String>{
        'schema_version': '${manifest.schemaVersion}',
        'data_version': manifest.dataVersion,
        'source_revision': manifest.sourceRevision,
        'source_url': manifest.sourceUrl,
        'source_sha256': manifest.sourceSha256,
        'source_pair_count': '${manifest.sourcePairCount}',
        'self_relation_count': '${manifest.selfRelationCount}',
        'tag_count': '${manifest.tagCount}',
        'directed_edge_count': '${manifest.directedEdgeCount}',
      };
      for (final entry in expected.entries) {
        if (metadata[entry.key] != entry.value) {
          throw FormatException(
            'Metadata mismatch for ${entry.key}: '
            'expected=${entry.value} actual=${metadata[entry.key]}',
          );
        }
      }
      final actualTags = (await database.rawQuery(
        'SELECT COUNT(*) AS count FROM tags',
      )).single['count'];
      final actualEdges = (await database.rawQuery(
        'SELECT COUNT(*) AS count FROM edges',
      )).single['count'];
      if (actualTags != manifest.tagCount ||
          actualEdges != manifest.directedEdgeCount) {
        throw FormatException(
          'Database record count mismatch: tags=$actualTags edges=$actualEdges',
        );
      }
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> _replaceOpenDatabase(Database database) async {
    await _beginSwitch();
    try {
      await _closeOpenDatabase();
      _database = database;
    } finally {
      _endSwitch();
    }
  }

  Future<void> _beginSwitch() async {
    while (_switching) {
      await _switchGate!.future;
    }
    _switching = true;
    _switchGate = Completer<void>();
    if (_activeQueries > 0) {
      _queriesDrained = Completer<void>();
      await _queriesDrained!.future;
    }
  }

  void _endSwitch() {
    _switching = false;
    _switchGate?.complete();
    _switchGate = null;
  }

  Future<void> _closeOpenDatabase() async {
    final database = _database;
    _database = null;
    if (database != null) await database.close();
  }

  Future<void> _recoverInterruptedReplacement(
    Directory directory,
    CooccurrenceDataPackManifest manifest,
  ) async {
    final target = _databaseFile(directory, manifest);
    final backup = _backupFile(directory, manifest);
    final installing = File(
      p.join(directory.path, '${manifest.databaseName}.installing'),
    );
    await _deleteFile(installing);
    if (!await target.exists() && await backup.exists()) {
      await backup.rename(target.path);
      return;
    }
    if (!await target.exists() || !await backup.exists()) return;

    final installedManifest = await _readInstalledManifest(directory);
    final expected = installedManifest ?? manifest;
    try {
      final database = await _validateAndOpen(target, expected);
      await database.close();
      await _deleteFile(backup);
      return;
    } catch (_) {
      final backupDatabase = await _validateAndOpen(backup, expected);
      await backupDatabase.close();
      await _deleteFile(target);
      await backup.rename(target.path);
    }
  }

  Future<void> _writeInstallMetadata(
    Directory directory,
    CooccurrenceDataPackManifest manifest,
  ) async {
    final target = _installMetadataFile(directory);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');
    await temporary.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'schemaVersion': 1, 'manifest': manifest.toJson()}),
      encoding: utf8,
      flush: true,
    );
    await _deleteFile(backup);
    if (await target.exists()) await target.rename(backup.path);
    try {
      await temporary.rename(target.path);
      await _deleteFile(backup);
    } catch (_) {
      await _deleteFile(target);
      if (await backup.exists()) await backup.rename(target.path);
      rethrow;
    }
  }

  Future<void> _recoverInstallMetadata(Directory directory) async {
    final target = _installMetadataFile(directory);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');
    if (!await target.exists() && await backup.exists()) {
      await backup.rename(target.path);
    } else if (await target.exists()) {
      await _deleteFile(backup);
    }
    await _deleteFile(temporary);
  }

  Future<CooccurrenceDataPackManifest?> _readInstalledManifest(
    Directory directory,
  ) async {
    final file = _installMetadataFile(directory);
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
        return null;
      }
      final manifest = decoded['manifest'];
      if (manifest is! Map) return null;
      return CooccurrenceDataPackManifest.parse(jsonEncode(manifest));
    } catch (error) {
      AppLogger.w(
        'Ignoring invalid co-occurrence install metadata: $error',
        'CooccurrencePack',
      );
      return null;
    }
  }

  Future<int> _partialLength(
    Directory directory,
    CooccurrenceDataPackManifest manifest,
  ) async {
    final part = File(p.join(directory.path, '${manifest.archiveName}.part'));
    try {
      return await part.exists() ? await part.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _requireColumns(
    Database database,
    String table,
    Set<String> required,
  ) async {
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    final columns = rows.map((row) => '${row['name']}').toSet();
    if (!columns.containsAll(required)) {
      throw FormatException('Table $table is missing columns: $required');
    }
  }

  static CooccurrenceDataPackError _classifyError(Object error) {
    if (error is VerifiedDownloadException) {
      return switch (error.failure) {
        VerifiedDownloadFailure.diskFull => CooccurrenceDataPackError.diskFull,
        VerifiedDownloadFailure.sizeMismatch ||
        VerifiedDownloadFailure.checksumMismatch =>
          CooccurrenceDataPackError.archiveIntegrity,
        _ => CooccurrenceDataPackError.network,
      };
    }
    if (error is _CooccurrenceArchiveException) {
      return CooccurrenceDataPackError.archiveIntegrity;
    }
    if (error is FileSystemException) {
      return _isDiskFull(error)
          ? CooccurrenceDataPackError.diskFull
          : CooccurrenceDataPackError.install;
    }
    if (error is FormatException) {
      return CooccurrenceDataPackError.databaseIntegrity;
    }
    return CooccurrenceDataPackError.unknown;
  }

  static bool _isDiskFull(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 28 || code == 112 || code == 39;
  }

  static File _databaseFile(
    Directory directory,
    CooccurrenceDataPackManifest manifest,
  ) => File(p.join(directory.path, manifest.databaseName));

  static File _backupFile(
    Directory directory,
    CooccurrenceDataPackManifest manifest,
  ) => File(p.join(directory.path, '${manifest.databaseName}.backup'));

  static File _installMetadataFile(Directory directory) =>
      File(p.join(directory.path, _installMetadataName));

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLogger.w('Unable to remove ${file.path}: $error', 'CooccurrencePack');
    }
  }

  static Future<CooccurrenceDataPackManifest> _loadBundledManifest() async =>
      CooccurrenceDataPackManifest.parse(
        await rootBundle.loadString(cooccurrenceDataPackManifestAsset),
      );

  static Future<Directory> _loadApplicationSupportDirectory() =>
      getApplicationSupportDirectory();

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    cancelDownload();
    final activeInstall = _activeInstall;
    if (activeInstall != null) await activeInstall;
    _disposed = true;
    await _beginSwitch();
    try {
      await _closeOpenDatabase();
    } finally {
      _endSwitch();
    }
  }

  @override
  void dispose() {
    unawaited(
      close().whenComplete(() {
        super.dispose();
      }),
    );
  }
}
