import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/app_logger.dart';
import 'quick_tag_cloud_parser.dart';

export '../../models/online_gallery/quick_tag_cloud_catalog.dart';
export '../../models/online_gallery/quick_tag_cloud_codex.dart';

typedef QuickTagCloudSupportDirectoryLoader = Future<Directory> Function();

class QuickTagCloudIntegrityException implements Exception {
  const QuickTagCloudIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'QuickTagCloudIntegrityException: $message';
}

/// Read-only client for the fixed QuickTagCloud catalog.
class QuickTagCloudRemoteCatalogService {
  QuickTagCloudRemoteCatalogService({
    Dio? dio,
    QuickTagCloudSupportDirectoryLoader? supportDirectoryLoader,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(minutes: 3),
               sendTimeout: const Duration(seconds: 15),
             ),
           ),
       _supportDirectoryLoader =
           supportDirectoryLoader ?? getApplicationSupportDirectory;

  static const String dataSourceUrl =
      'https://novelai.quicktagcloud.com/data-source.json';
  // Upstream permission requires this book to remain sourced from the
  // maintainer's live DreamGod endpoint instead of the hosted snapshot.
  static const Set<String> _directOnlyCodexIds = {'mengshen_r18'};

  final Dio _dio;
  final QuickTagCloudSupportDirectoryLoader _supportDirectoryLoader;
  final Map<String, Future<QuickTagCloudCodex>> _parsedCodexes = {};

  Future<QuickTagCloudCatalog> loadCatalog({CancelToken? cancelToken}) =>
      fetchCatalog(cancelToken: cancelToken);

  Future<QuickTagCloudCatalog> fetchCatalog({CancelToken? cancelToken}) async {
    try {
      final dataSourceJson = await _fetchJson(
        Uri.parse(dataSourceUrl),
        noStore: true,
        cancelToken: cancelToken,
      );
      final config = QuickTagCloudParser.parseDataSource(dataSourceJson);
      final pointerJson = await _fetchJson(
        _resolveDataPath(config.baseUrl, config.pointer),
        noStore: true,
        cancelToken: cancelToken,
      );
      final pointer = QuickTagCloudParser.parseReleasePointer(pointerJson);
      final manifestJson = await _fetchJson(
        _resolveDataPath(config.baseUrl, pointer.manifest),
        cancelToken: cancelToken,
      );
      final manifest = QuickTagCloudParser.parseManifest(
        manifestJson,
        expectedRelease: pointer.release,
        expectedContentHash: pointer.contentHash,
      );
      final releaseBase = _releaseBase(config, pointer.release);
      final responseBytes = await Future.wait([
        _fetchVerifiedReleaseBytes(
          releaseBase,
          manifest,
          'codexes.json',
          cancelToken: cancelToken,
        ),
        _fetchVerifiedReleaseBytes(
          releaseBase,
          manifest,
          'media.json',
          cancelToken: cancelToken,
        ),
      ]);
      final responses = await Future.wait([
        _decodeJsonAsync(
          responseBytes[0],
          'codexes.json',
          cancelToken: cancelToken,
        ),
        _decodeJsonAsync(
          responseBytes[1],
          'media.json',
          cancelToken: cancelToken,
        ),
      ]);
      final catalog = QuickTagCloudCatalog(
        config: config,
        pointer: pointer,
        manifest: manifest,
        codexes: QuickTagCloudParser.parseCodexes(responses[0]),
        media: QuickTagCloudParser.parseMedia(responses[1]),
      );
      await _saveCatalogSnapshot({
        'dataSource': dataSourceJson,
        'pointer': pointerJson,
        'manifest': manifestJson,
        'releaseFiles': {
          'codexes.json': base64Encode(responseBytes[0]),
          'media.json': base64Encode(responseBytes[1]),
        },
      });
      await _pruneReleaseCaches(catalog.release);
      return catalog;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      return _loadCatalogSnapshot(error);
    }
  }

  Future<QuickTagCloudCodex> loadCodex(
    QuickTagCloudCatalog catalog,
    QuickTagCloudCodexMeta meta, {
    CancelToken? cancelToken,
  }) => fetchCodex(catalog, meta, cancelToken: cancelToken);

  Future<QuickTagCloudCodex> fetchCodex(
    QuickTagCloudCatalog catalog,
    QuickTagCloudCodexMeta meta, {
    CancelToken? cancelToken,
  }) {
    if (meta.isExternal) {
      return _fetchExternalCodex(catalog, meta, cancelToken: cancelToken);
    }
    final path = _canonicalPath(meta.id);
    final key = '${catalog.release}:canonical:$path';
    Future<QuickTagCloudCodex> load() async {
      try {
        return _parseCodex(
          await _loadVerifiedCachedJson(
            catalog,
            path,
            cancelToken: cancelToken,
          ),
          meta,
          sourceRelease: catalog.release,
          cancelToken: cancelToken,
        );
      } catch (error) {
        if (_isCancellation(error)) rethrow;
        final previous = await _loadPreviousCatalog(
          catalog,
          meta,
          cancelToken: cancelToken,
        );
        final previousMeta = previous == null
            ? null
            : _findPreviousMeta(previous, meta);
        if (previous == null || previousMeta == null) rethrow;
        try {
          return _parseCodex(
            await _loadVerifiedCachedJson(
              previous,
              _canonicalPath(previousMeta.id),
              cancelToken: cancelToken,
            ),
            previousMeta,
            loadSource: QuickTagCloudCodexLoadSource.previousRelease,
            mediaOverride: previous.media,
            sourceRelease: previous.release,
            externalError: error,
            cancelToken: cancelToken,
          );
        } catch (fallbackError) {
          if (_isCancellation(fallbackError)) rethrow;
          throw error;
        }
      }
    }

    return cancelToken == null ? _remember(key, load) : load();
  }

  Future<QuickTagCloudCodex> fetchCodexById(
    QuickTagCloudCatalog catalog,
    String idOrAlias, {
    CancelToken? cancelToken,
  }) {
    final meta = catalog.findCodex(idOrAlias);
    if (meta == null) {
      throw ArgumentError.value(idOrAlias, 'idOrAlias', 'Unknown codex');
    }
    return fetchCodex(catalog, meta, cancelToken: cancelToken);
  }

  void clearMemoryCache() => _parsedCodexes.clear();

  Future<void> clearDiskCache() async {
    clearMemoryCache();
    final root = await _supportDirectoryLoader();
    final directory = Directory(
      p.join(root.path, 'online_gallery', 'quick_tag_cloud'),
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _pruneReleaseCaches(String currentRelease) async {
    try {
      final previous = await _loadPreviousCatalogSnapshot();
      final keep = {currentRelease, if (previous != null) previous.release};
      final directory = await _cacheDirectory();
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (QuickTagCloudParser.releasePattern.hasMatch(name) &&
            !keep.contains(name)) {
          await entity.delete(recursive: true);
        }
      }
    } catch (error, stack) {
      AppLogger.w(
        'Failed to prune old QuickTagCloud release caches: $error\n$stack',
        'QuickTagCloud',
      );
    }
  }

  Future<void> _saveCatalogSnapshot(Map<String, Object?> snapshot) async {
    final target = await _catalogSnapshotFile();
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      final currentBytes = await target.readAsBytes();
      final currentRelease = await _snapshotRelease(currentBytes, target.path);
      final nextPointer = snapshot['pointer'];
      final nextRelease = nextPointer is Map
          ? nextPointer['release']?.toString()
          : null;
      if (currentRelease != null &&
          nextRelease != null &&
          currentRelease != nextRelease) {
        await _replaceAtomically(
          await _previousCatalogSnapshotFile(),
          currentBytes,
        );
      }
    }
    await _writeCatalogSnapshot(target, snapshot);
  }

  Future<void> _savePreviousCatalogSnapshot(
    Map<String, Object?> snapshot,
  ) async {
    final target = await _previousCatalogSnapshotFile();
    await target.parent.create(recursive: true);
    await _writeCatalogSnapshot(target, snapshot);
  }

  Future<void> _writeCatalogSnapshot(
    File target,
    Map<String, Object?> snapshot,
  ) async {
    final bytes = await Isolate.run(() {
      final payloadJson = jsonEncode(snapshot);
      final envelope = <String, Object?>{
        'schemaVersion': 1,
        'payloadSha256': sha256.convert(utf8.encode(payloadJson)).toString(),
        'payload': snapshot,
      };
      return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    });
    await _replaceAtomically(target, bytes);
  }

  Future<String?> _snapshotRelease(List<int> bytes, String source) async {
    try {
      final snapshot = await _decodeCatalogSnapshot(bytes, source);
      if (snapshot['pointer'] is! Map) return null;
      return (snapshot['pointer'] as Map)['release']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<QuickTagCloudCatalog> _loadCatalogSnapshot(Object refreshError) async {
    final current = await _loadSnapshotFile(
      _catalogSnapshotFile(),
      refreshError: refreshError,
    );
    if (current != null) return current;
    final previous = await _loadSnapshotFile(
      _previousCatalogSnapshotFile(),
      refreshError: refreshError,
    );
    if (previous != null) return previous;
    throw refreshError;
  }

  Future<QuickTagCloudCatalog?> _loadPreviousCatalogSnapshot() =>
      _loadSnapshotFile(_previousCatalogSnapshotFile());

  Future<QuickTagCloudCatalog?> _loadPreviousCatalog(
    QuickTagCloudCatalog current,
    QuickTagCloudCodexMeta currentMeta, {
    CancelToken? cancelToken,
  }) async {
    final cached = await _loadPreviousCatalogSnapshot();
    if (cached != null && _findPreviousMeta(cached, currentMeta) != null) {
      return cached;
    }
    final release = current.pointer.previousRelease;
    if (release.isEmpty || release == current.release) return null;

    try {
      final releaseBase = _releaseBase(current.config, release);
      final manifestJson = await _fetchJson(
        releaseBase.resolve('manifest.json'),
        cancelToken: cancelToken,
      );
      final manifest = QuickTagCloudParser.parseManifest(
        manifestJson,
        expectedRelease: release,
      );
      final responseBytes = await Future.wait([
        _fetchVerifiedReleaseBytes(
          releaseBase,
          manifest,
          'codexes.json',
          cancelToken: cancelToken,
        ),
        _fetchVerifiedReleaseBytes(
          releaseBase,
          manifest,
          'media.json',
          cancelToken: cancelToken,
        ),
      ]);
      final responses = await Future.wait([
        _decodeJsonAsync(
          responseBytes[0],
          'codexes.json',
          cancelToken: cancelToken,
        ),
        _decodeJsonAsync(
          responseBytes[1],
          'media.json',
          cancelToken: cancelToken,
        ),
      ]);
      final pointer = QuickTagCloudReleasePointer(
        schemaVersion: 1,
        release: release,
        manifest: 'releases/$release/manifest.json',
        contentHash: manifest.contentHash,
      );
      final previous = QuickTagCloudCatalog(
        config: current.config,
        pointer: pointer,
        manifest: manifest,
        codexes: QuickTagCloudParser.parseCodexes(responses[0]),
        media: QuickTagCloudParser.parseMedia(responses[1]),
        isOffline: true,
      );
      await _savePreviousCatalogSnapshot({
        'dataSource': {
          'schemaVersion': current.config.schemaVersion,
          'baseUrl': current.config.baseUrl.toString(),
          'pointer': current.config.pointer,
        },
        'pointer': {
          'schemaVersion': pointer.schemaVersion,
          'release': pointer.release,
          'manifest': pointer.manifest,
          'contentHash': pointer.contentHash,
        },
        'manifest': manifestJson,
        'releaseFiles': {
          'codexes.json': base64Encode(responseBytes[0]),
          'media.json': base64Encode(responseBytes[1]),
        },
      });
      return previous;
    } catch (error) {
      if (_isCancellation(error)) rethrow;
      return null;
    }
  }

  QuickTagCloudCodexMeta? _findPreviousMeta(
    QuickTagCloudCatalog previous,
    QuickTagCloudCodexMeta current,
  ) {
    for (final candidate in [current.id, ...current.aliases]) {
      final match = previous.findCodex(candidate);
      if (match != null) return match;
    }
    final identities = {current.id, ...current.aliases};
    for (final candidate in previous.codexes) {
      if (candidate.aliases.any(identities.contains)) return candidate;
    }
    return null;
  }

  bool _requiresDirectSource(QuickTagCloudCodexMeta meta) =>
      _directOnlyCodexIds.contains(meta.id) ||
      meta.aliases.any(_directOnlyCodexIds.contains);

  Future<QuickTagCloudCatalog?> _loadSnapshotFile(
    Future<File> fileFuture, {
    Object? refreshError,
  }) async {
    try {
      final snapshotFile = await fileFuture;
      await _recoverInterruptedReplace(snapshotFile);
      if (!await snapshotFile.exists()) return null;
      final json = await _decodeCatalogSnapshot(
        await snapshotFile.readAsBytes(),
        snapshotFile.path,
      );
      final config = QuickTagCloudParser.parseDataSource(json['dataSource']);
      final pointer = QuickTagCloudParser.parseReleasePointer(json['pointer']);
      final manifest = QuickTagCloudParser.parseManifest(
        json['manifest'],
        expectedRelease: pointer.release,
        expectedContentHash: pointer.contentHash,
      );
      final codexesBytes = _verifiedSnapshotFile(
        json,
        manifest,
        'codexes.json',
      );
      final mediaBytes = _verifiedSnapshotFile(json, manifest, 'media.json');
      final decoded = await Future.wait([
        _decodeJsonAsync(codexesBytes, 'snapshot codexes.json'),
        _decodeJsonAsync(mediaBytes, 'snapshot media.json'),
      ]);
      return QuickTagCloudCatalog(
        config: config,
        pointer: pointer,
        manifest: manifest,
        codexes: QuickTagCloudParser.parseCodexes(decoded[0]),
        media: QuickTagCloudParser.parseMedia(decoded[1]),
        isOffline: true,
        refreshError: refreshError,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _decodeCatalogSnapshot(
    List<int> bytes,
    String source,
  ) => Isolate.run(() {
    Object? envelope;
    try {
      envelope = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (error) {
      throw FormatException('Invalid QuickTagCloud JSON at $source: $error');
    }
    if (envelope is! Map || envelope['schemaVersion'] != 1) {
      throw FormatException('Invalid QuickTagCloud snapshot at $source');
    }
    final payload = envelope['payload'];
    final expectedHash = envelope['payloadSha256']?.toString() ?? '';
    if (payload is! Map ||
        !QuickTagCloudParser.sha256Pattern.hasMatch(expectedHash)) {
      throw FormatException(
        'Invalid QuickTagCloud snapshot envelope at $source',
      );
    }
    final actualHash = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    if (actualHash != expectedHash) {
      throw QuickTagCloudIntegrityException(
        'Catalog snapshot does not match its integrity hash: $source',
      );
    }
    return Map<String, dynamic>.from(payload);
  });

  Uint8List _verifiedSnapshotFile(
    Map<String, dynamic> snapshot,
    QuickTagCloudReleaseManifest manifest,
    String path,
  ) {
    final releaseFiles = snapshot['releaseFiles'];
    if (releaseFiles is! Map) {
      throw const FormatException(
        'QuickTagCloud snapshot has no verified release files',
      );
    }
    final encoded = releaseFiles[path];
    if (encoded is! String || encoded.isEmpty) {
      throw FormatException('QuickTagCloud snapshot is missing $path');
    }
    final bytes = base64Decode(encoded);
    _verify(bytes, manifest.requireFile(path));
    return bytes;
  }

  Future<Directory> _cacheDirectory() async {
    final root = await _supportDirectoryLoader();
    return Directory(p.join(root.path, 'online_gallery', 'quick_tag_cloud'));
  }

  Future<File> _catalogSnapshotFile() async {
    final directory = await _cacheDirectory();
    return File(p.join(directory.path, 'catalog_snapshot.json'));
  }

  Future<File> _previousCatalogSnapshotFile() async {
    final root = await _supportDirectoryLoader();
    return File(
      p.join(
        root.path,
        'online_gallery',
        'quick_tag_cloud',
        'catalog_snapshot.previous.json',
      ),
    );
  }

  Future<QuickTagCloudCodex> _fetchExternalCodex(
    QuickTagCloudCatalog catalog,
    QuickTagCloudCodexMeta meta, {
    CancelToken? cancelToken,
  }) {
    final key = '${catalog.release}:external:${meta.id}:${meta.dataUrl}';
    Future<QuickTagCloudCodex> load() async {
      try {
        final data = await _fetchJson(
          _externalUri(meta.dataUrl),
          noStore: true,
          cancelToken: cancelToken,
        );
        return _parseCodex(
          data,
          meta,
          loadSource: QuickTagCloudCodexLoadSource.external,
          sourceRelease: catalog.release,
          cancelToken: cancelToken,
        );
      } catch (error) {
        if (_isCancellation(error) ||
            meta.fallbackDataUrl.isEmpty ||
            _requiresDirectSource(meta)) {
          rethrow;
        }
        final fallbackPath = _fallbackReleasePath(meta.fallbackDataUrl);
        return _parseCodex(
          await _loadVerifiedCachedJson(
            catalog,
            fallbackPath,
            cancelToken: cancelToken,
          ),
          meta,
          loadSource: QuickTagCloudCodexLoadSource.fallback,
          sourceRelease: catalog.release,
          externalError: error,
          cancelToken: cancelToken,
        );
      }
    }

    return cancelToken == null ? _remember(key, load) : load();
  }

  Future<QuickTagCloudCodex> _parseCodex(
    Object? data,
    QuickTagCloudCodexMeta meta, {
    QuickTagCloudCodexLoadSource loadSource =
        QuickTagCloudCodexLoadSource.canonical,
    QuickTagCloudMediaConfig? mediaOverride,
    String sourceRelease = '',
    Object? externalError,
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final entryCount = data is Map && data['entries'] is List
        ? (data['entries'] as List).length
        : 0;
    if (entryCount < 500) {
      return QuickTagCloudParser.parseCodex(
        data,
        meta,
        loadSource: loadSource,
        mediaOverride: mediaOverride,
        sourceRelease: sourceRelease,
        externalError: externalError?.toString(),
      );
    }
    final request = _CodexParseRequest(
      data: data,
      meta: meta,
      loadSource: loadSource,
      mediaOverride: mediaOverride,
      sourceRelease: sourceRelease,
      externalError: externalError?.toString(),
    );
    final codex = await _parseCodexInIsolate(request, cancelToken: cancelToken);
    _throwIfCancelled(cancelToken);
    return codex;
  }

  Future<QuickTagCloudCodex> _remember(
    String key,
    Future<QuickTagCloudCodex> Function() loader,
  ) {
    final existing = _parsedCodexes.remove(key);
    if (existing != null) {
      _parsedCodexes[key] = existing;
      return existing;
    }
    final pending = loader();
    _parsedCodexes[key] = pending;
    while (_parsedCodexes.length > 4) {
      _parsedCodexes.remove(_parsedCodexes.keys.first);
    }
    pending.then<void>(
      (codex) {
        if ((codex.loadSource == QuickTagCloudCodexLoadSource.fallback ||
                codex.loadSource ==
                    QuickTagCloudCodexLoadSource.previousRelease) &&
            identical(_parsedCodexes[key], pending)) {
          _parsedCodexes.remove(key);
        }
      },
      onError: (Object _, StackTrace __) {
        if (identical(_parsedCodexes[key], pending)) _parsedCodexes.remove(key);
      },
    );
    return pending;
  }

  Future<Object?> _loadVerifiedCachedJson(
    QuickTagCloudCatalog catalog,
    String path, {
    CancelToken? cancelToken,
  }) async {
    final metadata = catalog.manifest.requireFile(path);
    final root = await _supportDirectoryLoader();
    final cacheRoot = Directory(
      p.join(root.path, 'online_gallery', 'quick_tag_cloud', catalog.release),
    );
    final target = File(
      p.normalize(p.joinAll([cacheRoot.path, ...path.split('/')])),
    );
    if (!p.isWithin(p.normalize(cacheRoot.path), target.path)) {
      throw const FormatException(
        'QuickTagCloud cache path escaped its release root',
      );
    }
    await _recoverInterruptedReplace(target);
    if (await target.exists()) {
      final cached = await target.readAsBytes();
      if (_matches(cached, metadata)) {
        return _decodeJsonAsync(cached, target.path, cancelToken: cancelToken);
      }
    }

    final bytes = await _fetchBytes(
      catalog.releaseBaseUrl.resolve(_encodeRelativePath(path)),
      cancelToken: cancelToken,
    );
    _verify(bytes, metadata);
    await target.parent.create(recursive: true);
    await _replaceAtomically(target, bytes);
    return _decodeJsonAsync(bytes, target.path, cancelToken: cancelToken);
  }

  Future<Uint8List> _fetchVerifiedReleaseBytes(
    Uri releaseBase,
    QuickTagCloudReleaseManifest manifest,
    String path, {
    CancelToken? cancelToken,
  }) async {
    final metadata = manifest.requireFile(path);
    final bytes = await _fetchBytes(
      releaseBase.resolve(_encodeRelativePath(path)),
      cancelToken: cancelToken,
    );
    _verify(bytes, metadata);
    return bytes;
  }

  Future<Object?> _fetchJson(
    Uri url, {
    bool noStore = false,
    CancelToken? cancelToken,
  }) async {
    final bytes = await _fetchBytes(
      url,
      noStore: noStore,
      cancelToken: cancelToken,
    );
    return _decodeJsonAsync(bytes, url.toString(), cancelToken: cancelToken);
  }

  Future<Uint8List> _fetchBytes(
    Uri url, {
    bool noStore = false,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      url.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: noStore
            ? const {'Cache-Control': 'no-store', 'Pragma': 'no-cache'}
            : null,
        extra: noStore ? const {'quickTagCloudCache': 'no-store'} : null,
      ),
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    if (data is Map || data is List) {
      return Uint8List.fromList(utf8.encode(jsonEncode(data)));
    }
    throw FormatException('QuickTagCloud returned no data for $url');
  }

  Object? _decodeJson(List<int> bytes, String source) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException catch (error) {
      throw FormatException('Invalid QuickTagCloud JSON at $source: $error');
    }
  }

  Future<Object?> _decodeJsonAsync(
    List<int> bytes,
    String source, {
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    if (bytes.length < 256 * 1024) return _decodeJson(bytes, source);
    return _decodeJsonInIsolate(
      Uint8List.fromList(bytes),
      source,
      cancelToken: cancelToken,
    );
  }

  Future<QuickTagCloudCodex> _parseCodexInIsolate(
    _CodexParseRequest request, {
    CancelToken? cancelToken,
  }) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_parseCodexIsolateEntry, (
      port.sendPort,
      request,
    ));
    try {
      final message = await _awaitIsolateMessage(port, cancelToken);
      if (message is List && message.length >= 2 && message.first == true) {
        return message[1] as QuickTagCloudCodex;
      }
      throw FormatException(
        'Invalid QuickTagCloud codex: '
        '${message is List && message.length >= 2 ? message[1] : message}',
      );
    } finally {
      isolate.kill(priority: Isolate.immediate);
      port.close();
    }
  }

  Future<Object?> _decodeJsonInIsolate(
    Uint8List bytes,
    String source, {
    CancelToken? cancelToken,
  }) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_decodeJsonIsolateEntry, (
      port.sendPort,
      bytes,
    ));
    try {
      final message = await _awaitIsolateMessage(port, cancelToken);
      if (message is List && message.length >= 2 && message.first == true) {
        return message[1];
      }
      throw FormatException(
        'Invalid QuickTagCloud JSON at $source: '
        '${message is List && message.length >= 2 ? message[1] : message}',
      );
    } finally {
      isolate.kill(priority: Isolate.immediate);
      port.close();
    }
  }

  Future<Object?> _awaitIsolateMessage(
    ReceivePort port,
    CancelToken? cancelToken,
  ) {
    if (cancelToken == null) return port.first;
    return Future.any([
      port.first,
      cancelToken.whenCancel.then<Object?>((error) => throw error),
    ]);
  }

  void _verify(List<int> bytes, QuickTagCloudManifestFile metadata) {
    if (!_matches(bytes, metadata)) {
      throw QuickTagCloudIntegrityException(
        '${metadata.path} does not match manifest size/sha256',
      );
    }
  }

  bool _matches(List<int> bytes, QuickTagCloudManifestFile metadata) =>
      bytes.length == metadata.size &&
      sha256.convert(bytes).toString() == metadata.sha256;

  Future<void> _replaceAtomically(File target, List<int> bytes) async {
    await _recoverInterruptedReplace(target);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.$stamp.downloading');
    final backup = File('${target.path}.$stamp.backup');
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete();
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _recoverInterruptedReplace(File target) async {
    final parent = target.parent;
    if (!await parent.exists()) return;
    final base = p.basename(target.path);
    final pattern = RegExp('^${RegExp.escape(base)}\\.(\\d+)\\.backup\$');
    final backups = <File>[];
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is File && pattern.hasMatch(p.basename(entity.path))) {
        backups.add(entity);
      }
    }
    if (backups.isEmpty) return;
    backups.sort((left, right) => left.path.compareTo(right.path));
    if (!await target.exists()) {
      final latest = backups.removeLast();
      await latest.rename(target.path);
    }
    for (final backup in backups) {
      if (await backup.exists()) await backup.delete();
    }
  }

  Uri _releaseBase(QuickTagCloudDataSourceConfig config, String release) =>
      _resolveDataPath(config.baseUrl, 'releases/$release/');

  Uri _resolveDataPath(Uri baseUrl, String path) {
    final base = Uri.parse(
      '${baseUrl.toString().replaceFirst(RegExp(r'/+$'), '')}/',
    );
    return base.resolve(_encodeRelativePath(path));
  }

  String _canonicalPath(String id) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\')) {
      throw FormatException('Invalid QuickTagCloud codex id: $id');
    }
    return QuickTagCloudParser.cleanRelativePath('$id.json');
  }

  String _fallbackReleasePath(String value) {
    final match = RegExp(r'^/?data/(.+)$').firstMatch(value);
    if (match == null) {
      throw FormatException(
        'QuickTagCloud fallbackDataUrl must point into this release: $value',
      );
    }
    return QuickTagCloudParser.cleanRelativePath(match.group(1)!);
  }

  Uri _externalUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('Invalid QuickTagCloud external dataUrl: $value');
    }
    return uri;
  }

  String _encodeRelativePath(String path) {
    final trailingSlash = path.endsWith('/');
    final cleaned = trailingSlash ? path.substring(0, path.length - 1) : path;
    final safe = QuickTagCloudParser.cleanRelativePath(cleaned);
    final encoded = safe.split('/').map(Uri.encodeComponent).join('/');
    return trailingSlash ? '$encoded/' : encoded;
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    final error = cancelToken?.cancelError;
    if (error != null) throw error;
  }

  bool _isCancellation(Object error) =>
      error is DioException && CancelToken.isCancel(error);
}

class _CodexParseRequest {
  const _CodexParseRequest({
    required this.data,
    required this.meta,
    required this.loadSource,
    required this.mediaOverride,
    required this.sourceRelease,
    required this.externalError,
  });

  final Object? data;
  final QuickTagCloudCodexMeta meta;
  final QuickTagCloudCodexLoadSource loadSource;
  final QuickTagCloudMediaConfig? mediaOverride;
  final String sourceRelease;
  final String? externalError;
}

void _parseCodexIsolateEntry((SendPort, _CodexParseRequest) message) {
  final (sendPort, request) = message;
  try {
    final codex = QuickTagCloudParser.parseCodex(
      request.data,
      request.meta,
      loadSource: request.loadSource,
      mediaOverride: request.mediaOverride,
      sourceRelease: request.sourceRelease,
      externalError: request.externalError,
    );
    Isolate.exit(sendPort, [true, codex]);
  } catch (error, stackTrace) {
    Isolate.exit(sendPort, [false, '$error\n$stackTrace']);
  }
}

void _decodeJsonIsolateEntry((SendPort, Uint8List) message) {
  final (sendPort, bytes) = message;
  try {
    Isolate.exit(sendPort, [true, jsonDecode(utf8.decode(bytes))]);
  } catch (error, stackTrace) {
    Isolate.exit(sendPort, [false, '$error\n$stackTrace']);
  }
}
