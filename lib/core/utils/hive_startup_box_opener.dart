import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'app_logger.dart';

class HiveStartupBoxOpenResult {
  const HiveStartupBoxOpenResult({
    required this.name,
    required this.recovered,
    this.backupDirectory,
  });

  final String name;
  final bool recovered;
  final String? backupDirectory;
}

class HiveStartupBoxOpener {
  HiveStartupBoxOpener._();

  static const recoveryBackupDirectoryName = 'hive_recovery_backup';
  static const _tag = 'HiveStartup';

  static Future<HiveStartupBoxOpenResult> openBox<E>(
    String name, {
    String? hivePath,
    Future<void> Function()? openBoxOverride,
  }) async {
    if (Hive.isBoxOpen(name)) {
      return HiveStartupBoxOpenResult(name: name, recovered: false);
    }

    try {
      await _openBox<E>(name, openBoxOverride: openBoxOverride);
      return HiveStartupBoxOpenResult(name: name, recovered: false);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to open Hive box "$name"; attempting file recovery',
        error,
        stackTrace,
        _tag,
      );

      final backupDirectory = await _backupAndRemoveBoxFiles(
        name,
        hivePath: hivePath,
      );
      if (backupDirectory == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      try {
        await _openBox<E>(name, openBoxOverride: openBoxOverride);
        AppLogger.w(
          'Recovered Hive box "$name" from backup at $backupDirectory',
          _tag,
        );
        return HiveStartupBoxOpenResult(
          name: name,
          recovered: true,
          backupDirectory: backupDirectory,
        );
      } catch (retryError, retryStackTrace) {
        AppLogger.e(
          'Failed to reopen recovered Hive box "$name"',
          retryError,
          retryStackTrace,
          _tag,
        );
        Error.throwWithStackTrace(retryError, retryStackTrace);
      }
    }
  }

  static Future<void> _openBox<E>(
    String name, {
    required Future<void> Function()? openBoxOverride,
  }) async {
    if (openBoxOverride != null) {
      await openBoxOverride();
      return;
    }
    await Hive.openBox<E>(name);
  }

  static Future<String?> _backupAndRemoveBoxFiles(
    String name, {
    required String? hivePath,
  }) async {
    if (hivePath == null || hivePath.isEmpty) {
      return null;
    }

    final hiveDir = Directory(hivePath);
    if (!await hiveDir.exists()) {
      return null;
    }

    final boxFiles = await hiveDir
        .list()
        .where((entity) => entity is File && _isBoxRelatedFile(name, entity))
        .cast<File>()
        .toList();
    if (boxFiles.isEmpty) {
      return null;
    }

    final backupDir = Directory(
      p.join(hivePath, recoveryBackupDirectoryName, _backupDirectoryName(name)),
    );
    await backupDir.create(recursive: true);

    for (final file in boxFiles) {
      final target = p.join(backupDir.path, p.basename(file.path));
      await file.rename(target);
    }

    return backupDir.path;
  }

  static bool _isBoxRelatedFile(String name, FileSystemEntity entity) {
    final fileName = p.basename(entity.path);
    return fileName == '$name.hive' ||
        fileName == '$name.lock' ||
        fileName == '$name.crc' ||
        fileName == '$name.hive.lock' ||
        fileName == '$name.hive.crc';
  }

  static String _backupDirectoryName(String name) {
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return '${name}_$timestamp';
  }
}
