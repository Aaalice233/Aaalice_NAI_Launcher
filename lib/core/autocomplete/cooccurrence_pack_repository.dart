import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/verified_resumable_downloader.dart';
import '../utils/app_logger.dart';
import 'cooccurrence_manifest_codec.dart';
import 'cooccurrence_sqlite_repository.dart';

class CooccurrenceArchiveException extends FormatException {
  const CooccurrenceArchiveException(super.message, [super.source]);
}

enum CooccurrenceInstallStage { downloading, verifying, installing }

class CooccurrencePackRepository {
  CooccurrencePackRepository({required VerifiedResumableDownloader downloader})
    : _downloader = downloader;

  static const _metadataName = 'install.json';
  final VerifiedResumableDownloader _downloader;
  Directory? _directory;

  Directory get directory => _directory!;

  Future<void> prepare(Directory supportDirectory) async {
    _directory ??= Directory(
      p.join(supportDirectory.path, 'autocomplete', 'cooccurrence'),
    );
    await directory.create(recursive: true);
    await _recoverMetadata();
  }

  File databaseFile(CooccurrenceDataPackManifest manifest) =>
      File(p.join(directory.path, manifest.databaseName));

  Future<int> partialLength(CooccurrenceDataPackManifest manifest) async {
    final part = File(p.join(directory.path, '${manifest.archiveName}.part'));
    try {
      return await part.exists() ? await part.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<CooccurrenceDataPackManifest?> readInstalledManifest() async {
    final file = _metadataFile;
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

  Future<void> recoverInterruptedReplacement(
    CooccurrenceDataPackManifest manifest,
    CooccurrenceSqliteRepository sqlite,
  ) async {
    final target = databaseFile(manifest);
    final backup = _backupFile(manifest);
    await _delete(_installingFile(manifest));
    if (!await target.exists() && await backup.exists()) {
      await backup.rename(target.path);
      return;
    }
    if (!await target.exists() || !await backup.exists()) return;
    final expected = await readInstalledManifest() ?? manifest;
    try {
      final database = await sqlite.validateAndOpen(target, expected);
      await database.close();
      await _delete(backup);
    } catch (_) {
      final database = await sqlite.validateAndOpen(backup, expected);
      await database.close();
      await _delete(target);
      await backup.rename(target.path);
    }
  }

  Future<void> install({
    required CooccurrenceDataPackManifest manifest,
    required CooccurrenceSqliteRepository sqlite,
    required CancelToken cancelToken,
    required void Function(CooccurrenceInstallStage stage) onStage,
    required void Function(VerifiedDownloadProgress progress) onProgress,
  }) async {
    final archive = File(p.join(directory.path, manifest.archiveName));
    final installing = _installingFile(manifest);
    onStage(CooccurrenceInstallStage.downloading);
    await _downloader.download(
      uri: manifest.downloadUri,
      targetFile: archive,
      expectedSize: manifest.archiveSize,
      expectedSha256: manifest.archiveSha256,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    onStage(CooccurrenceInstallStage.verifying);
    await _delete(installing);
    await _decompressAndVerify(archive, installing, manifest, sqlite);
    onStage(CooccurrenceInstallStage.installing);
    await _commit(installing, manifest, sqlite);
    await _delete(archive);
    await _delete(File('${archive.path}.part'));
  }

  Future<void> deleteData(
    CooccurrenceDataPackManifest manifest,
    CooccurrenceSqliteRepository sqlite,
  ) async {
    await sqlite.switchDatabase(() async {
      await _delete(databaseFile(manifest));
      await _delete(_backupFile(manifest));
      await _delete(_installingFile(manifest));
      await _delete(File(p.join(directory.path, manifest.archiveName)));
      await _delete(
        File(p.join(directory.path, '${manifest.archiveName}.part')),
      );
      await _delete(_metadataFile);
      return null;
    });
  }

  Future<void> removeInvalidInstallation(
    CooccurrenceDataPackManifest manifest,
  ) async {
    await _delete(databaseFile(manifest));
    await _delete(_metadataFile);
  }

  Future<void> discardFailedInstall(
    CooccurrenceDataPackManifest manifest, {
    required bool discardArchive,
  }) async {
    await _delete(_installingFile(manifest));
    if (discardArchive) {
      await _delete(File(p.join(directory.path, manifest.archiveName)));
    }
  }

  Future<void> _decompressAndVerify(
    File archive,
    File output,
    CooccurrenceDataPackManifest manifest,
    CooccurrenceSqliteRepository sqlite,
  ) async {
    var written = 0;
    final sink = output.openWrite(mode: FileMode.write);
    Object? failure;
    StackTrace? failureStack;
    try {
      await for (final chunk in archive.openRead().transform(gzip.decoder)) {
        written += chunk.length;
        if (written > manifest.databaseSize) {
          throw const CooccurrenceArchiveException(
            'Decompressed database exceeds manifest',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    } finally {
      await sink.close();
    }
    if (failure != null) {
      await _delete(output);
      if (failure is FileSystemException) {
        Error.throwWithStackTrace(failure, failureStack!);
      }
      Error.throwWithStackTrace(
        CooccurrenceArchiveException(
          'Unable to decompress co-occurrence archive',
          failure,
        ),
        failureStack!,
      );
    }
    if (written != manifest.databaseSize) {
      await _delete(output);
      throw CooccurrenceArchiveException(
        'Decompressed database size mismatch: '
        'expected=${manifest.databaseSize} actual=$written',
      );
    }
    final hash = await VerifiedResumableDownloader.calculateSha256(output);
    if (!VerifiedResumableDownloader.equalsSha256(
      hash,
      manifest.databaseSha256,
    )) {
      await _delete(output);
      throw CooccurrenceArchiveException(
        'Decompressed database SHA256 mismatch: '
        'expected=${manifest.databaseSha256} actual=$hash',
      );
    }
    final database = await sqlite.validateAndOpen(output, manifest);
    await database.close();
  }

  Future<void> _commit(
    File installing,
    CooccurrenceDataPackManifest manifest,
    CooccurrenceSqliteRepository sqlite,
  ) async {
    final target = databaseFile(manifest);
    final backup = _backupFile(manifest);
    final previousManifest = await readInstalledManifest();
    Object? replacementError;
    StackTrace? replacementStack;
    await sqlite.switchDatabase(() async {
      await _delete(backup);
      if (await target.exists()) await target.rename(backup.path);
      Database? replacementDatabase;
      try {
        await installing.rename(target.path);
        replacementDatabase = await sqlite.validateAndOpen(target, manifest);
        await _writeMetadata(manifest);
        await _delete(backup);
        return replacementDatabase;
      } catch (error, stack) {
        replacementError = error;
        replacementStack = stack;
        await replacementDatabase?.close();
        await _delete(target);
        if (await backup.exists()) {
          await backup.rename(target.path);
          final restored = previousManifest ?? manifest;
          final database = await sqlite.validateAndOpen(target, restored);
          if (previousManifest != null) await _writeMetadata(previousManifest);
          return database;
        }
        return null;
      }
    });
    if (replacementError != null) {
      Error.throwWithStackTrace(replacementError!, replacementStack!);
    }
  }

  Future<void> _writeMetadata(CooccurrenceDataPackManifest manifest) async {
    final target = _metadataFile;
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');
    await temporary.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'schemaVersion': 1, 'manifest': manifest.toJson()}),
      encoding: utf8,
      flush: true,
    );
    await _delete(backup);
    if (await target.exists()) await target.rename(backup.path);
    try {
      await temporary.rename(target.path);
      await _delete(backup);
    } catch (_) {
      await _delete(target);
      if (await backup.exists()) await backup.rename(target.path);
      rethrow;
    }
  }

  Future<void> _recoverMetadata() async {
    final target = _metadataFile;
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');
    if (!await target.exists() && await backup.exists()) {
      await backup.rename(target.path);
    } else if (await target.exists()) {
      await _delete(backup);
    }
    await _delete(temporary);
  }

  File get _metadataFile => File(p.join(directory.path, _metadataName));
  File _backupFile(CooccurrenceDataPackManifest manifest) =>
      File(p.join(directory.path, '${manifest.databaseName}.backup'));
  File _installingFile(CooccurrenceDataPackManifest manifest) =>
      File(p.join(directory.path, '${manifest.databaseName}.installing'));

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLogger.w('Unable to remove ${file.path}: $error', 'CooccurrencePack');
    }
  }
}
