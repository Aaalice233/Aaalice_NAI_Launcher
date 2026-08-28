import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/verified_resumable_downloader.dart';
import '../utils/app_logger.dart';
import 'cooccurrence_manifest_codec.dart';
import 'cooccurrence_pack_repository.dart';
import 'cooccurrence_sqlite_repository.dart';

export 'cooccurrence_data_pack_protocol.dart';
export 'cooccurrence_manifest_codec.dart';

import 'cooccurrence_data_pack_protocol.dart';

const cooccurrenceDataPackManifestAsset =
    'assets/data/cooccurrence_data_pack_manifest.json';

/// Compatibility facade and Riverpod orchestrator for the optional data pack.
class CooccurrenceDataPackService
    extends StateNotifier<CooccurrenceDataPackState> {
  CooccurrenceDataPackService({
    VerifiedResumableDownloader? downloader,
    CooccurrenceManifestLoader? manifestLoader,
    ApplicationSupportDirectoryLoader? supportDirectoryLoader,
    DatabaseFactory? databaseFactoryOverride,
  }) : _manifestLoader = manifestLoader ?? _loadBundledManifest,
       _supportDirectoryLoader =
           supportDirectoryLoader ?? getApplicationSupportDirectory,
       _sqlite = CooccurrenceSqliteRepository(
         databaseFactoryOverride ?? databaseFactoryFfi,
       ),
       _pack = CooccurrencePackRepository(
         downloader: downloader ?? VerifiedResumableDownloader(dio: Dio()),
       ),
       super(const CooccurrenceDataPackState());

  final CooccurrenceManifestLoader _manifestLoader;
  final ApplicationSupportDirectoryLoader _supportDirectoryLoader;
  final CooccurrenceSqliteRepository _sqlite;
  final CooccurrencePackRepository _pack;

  CooccurrenceDataPackManifest? _manifest;
  Future<void>? _initialization;
  Future<void>? _activeInstall;
  CancelToken? _cancelToken;
  Future<void>? _closing;
  bool _disposed = false;

  bool get isQueryReady => _sqlite.isReady && !_disposed;
  String? get activeDataVersion => state.installedVersion;
  CooccurrenceDataPackManifest? get manifest => _manifest;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    try {
      final manifest = _manifest ??= await _manifestLoader();
      await _pack.prepare(await _supportDirectoryLoader());
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.checking,
        totalBytes: manifest.archiveSize,
        availableVersion: manifest.dataVersion,
        clearError: true,
      );
      await _pack.recoverInterruptedReplacement(manifest, _sqlite);
      final installedManifest = await _pack.readInstalledManifest() ?? manifest;
      final target = _pack.databaseFile(installedManifest);
      if (!await target.exists()) {
        state = state.copyWith(
          status: CooccurrenceDataPackStatus.unavailable,
          downloadedBytes: await _pack.partialLength(manifest),
          clearInstalledVersion: true,
          relationCount: 0,
          diskBytes: 0,
        );
        return;
      }
      try {
        final database = await _sqlite.validateAndOpen(
          target,
          installedManifest,
        );
        await _sqlite.replaceWith(database);
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
        await _pack.removeInvalidInstallation(installedManifest);
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
    state = state.copyWith(
      status: !_sqlite.isReady
          ? CooccurrenceDataPackStatus.unavailable
          : state.installedVersion == manifest.dataVersion
          ? CooccurrenceDataPackStatus.ready
          : CooccurrenceDataPackStatus.updateAvailable,
    );
  }

  Future<void> _install({required bool force}) async {
    await initialize();
    final manifest = _manifest;
    if (manifest == null || _disposed) return;
    if (!force &&
        _sqlite.isReady &&
        state.installedVersion == manifest.dataVersion) {
      state = state.copyWith(status: CooccurrenceDataPackStatus.ready);
      return;
    }
    final token = CancelToken();
    _cancelToken = token;
    state = state.copyWith(
      status: CooccurrenceDataPackStatus.downloading,
      totalBytes: manifest.archiveSize,
      downloadedBytes: await _pack.partialLength(manifest),
      bytesPerSecond: 0,
      clearError: true,
    );
    try {
      await _pack.install(
        manifest: manifest,
        sqlite: _sqlite,
        cancelToken: token,
        onStage: (stage) {
          if (_disposed) return;
          state = state.copyWith(
            status: switch (stage) {
              CooccurrenceInstallStage.downloading =>
                CooccurrenceDataPackStatus.downloading,
              CooccurrenceInstallStage.verifying =>
                CooccurrenceDataPackStatus.verifying,
              CooccurrenceInstallStage.installing =>
                CooccurrenceDataPackStatus.installing,
            },
            downloadedBytes: stage == CooccurrenceInstallStage.downloading
                ? null
                : manifest.archiveSize,
            bytesPerSecond: stage == CooccurrenceInstallStage.downloading
                ? null
                : 0,
          );
        },
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
        status: CooccurrenceDataPackStatus.ready,
        installedVersion: manifest.dataVersion,
        relationCount: manifest.sourcePairCount,
        diskBytes: manifest.databaseSize,
        downloadedBytes: manifest.archiveSize,
        clearError: true,
      );
    } on VerifiedDownloadCancelledException {
      state = state.copyWith(
        status: _sqlite.isReady
            ? CooccurrenceDataPackStatus.ready
            : CooccurrenceDataPackStatus.unavailable,
        downloadedBytes: await _pack.partialLength(manifest),
        bytesPerSecond: 0,
        clearError: true,
      );
    } catch (error, stack) {
      final classified = _classifyError(error);
      await _pack.discardFailedInstall(
        manifest,
        discardArchive:
            classified == CooccurrenceDataPackError.archiveIntegrity ||
            classified == CooccurrenceDataPackError.databaseIntegrity,
      );
      AppLogger.e(
        'Co-occurrence pack installation failed',
        error,
        stack,
        'CooccurrencePack',
      );
      state = state.copyWith(
        status: CooccurrenceDataPackStatus.error,
        bytesPerSecond: 0,
        error: classified,
        errorDetails: error.toString(),
      );
    } finally {
      if (identical(_cancelToken, token)) _cancelToken = null;
    }
  }

  void cancelDownload() => _cancelToken?.cancel('Paused by user');

  Future<void> deleteData() async {
    cancelDownload();
    if (_activeInstall != null) await _activeInstall;
    await initialize();
    final manifest = _manifest;
    if (manifest == null) return;
    await _pack.deleteData(manifest, _sqlite);
    state = state.copyWith(
      status: CooccurrenceDataPackStatus.unavailable,
      clearInstalledVersion: true,
      downloadedBytes: 0,
      bytesPerSecond: 0,
      relationCount: 0,
      diskBytes: 0,
      clearError: true,
    );
  }

  Future<List<Map<String, Object?>>> queryRelatedTags(
    String tag, {
    required int limit,
    required int minCount,
  }) => _sqlite.queryRelatedTags(tag, limit: limit, minCount: minCount);

  Future<int> queryPairCount() => _sqlite.queryPairCount();
  Future<int> queryRelatedTagCount(String tag) =>
      _sqlite.queryRelatedTagCount(tag);
  Future<int> queryPairCooccurrence(String first, String second) =>
      _sqlite.queryPairCooccurrence(first, second);
  Future<int> querySummedCooccurrence(String tag) =>
      _sqlite.querySummedCooccurrence(tag);

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    cancelDownload();
    if (_activeInstall != null) await _activeInstall;
    _disposed = true;
    await _sqlite.close();
  }

  @override
  void dispose() {
    unawaited(close().whenComplete(super.dispose));
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
    if (error is CooccurrenceArchiveException) {
      return CooccurrenceDataPackError.archiveIntegrity;
    }
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      return code == 28 || code == 112 || code == 39
          ? CooccurrenceDataPackError.diskFull
          : CooccurrenceDataPackError.install;
    }
    if (error is FormatException) {
      return CooccurrenceDataPackError.databaseIntegrity;
    }
    return CooccurrenceDataPackError.unknown;
  }

  static Future<CooccurrenceDataPackManifest> _loadBundledManifest() async =>
      CooccurrenceDataPackManifest.parse(
        await rootBundle.loadString(cooccurrenceDataPackManifestAsset),
      );
}
