import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/hive_storage_helper.dart';
import '../../core/utils/vibe_library_path_helper.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_file_storage_service.dart';
import 'vibe_library_hive_repository.dart';
import 'vibe_library_storage_protocol.dart';

typedef ProgressCallback = void Function(VibeLibraryMigrationProgress progress);

class VibeLibraryMigrationProgress {
  const VibeLibraryMigrationProgress({
    required this.stage,
    required this.current,
    required this.total,
    required this.message,
    required this.percentage,
  });

  final String stage;
  final int current;
  final int total;
  final String message;
  final double percentage;
}

class VibeLibraryMigrationResult {
  const VibeLibraryMigrationResult({
    required this.success,
    required this.exportedCount,
    required this.failedCount,
    this.error,
    this.backupPath,
  });

  final bool success;
  final int exportedCount;
  final int failedCount;
  final String? error;
  final String? backupPath;
}

class VibeLibraryMigrationService {
  VibeLibraryMigrationService({
    VibeFileStorageService? fileStorage,
    VibeLibraryRepositoryProtocol? repository,
  })  : _fileStorage = fileStorage ?? VibeFileStorageService(),
        _repository = repository ?? HiveVibeLibraryRepository();

  static const String _entriesBoxName = HiveVibeLibraryRepository.entriesBoxName;
  static const String _settingsBoxName = StorageKeys.settingsBox;
  static const int _targetSchemaVersion = 23;
  static const int _legacyTypeId = 20;
  static const String _schemaVersionKey = 'vibe_library_schema_version';
  static const String _migrationInProgressKey =
      'vibe_library_migration_in_progress';
  static const String _migrationBackupDirKey =
      'vibe_library_migration_backup_dir';
  static const String _tag = 'VibeLibraryMigration';

  final VibeFileStorageService _fileStorage;
  final VibeLibraryRepositoryProtocol _repository;
  static bool _localLock = false;

  Future<VibeLibraryMigrationResult> migrateIfNeeded({
    ProgressCallback? onProgress,
  }) async {
    // 若设置中残留“迁移进行中”但当前进程并未持锁，说明上次可能异常退出，需先清理孤立锁。
    final settingsBox = await _openSettingsBox();
    final inProgress = settingsBox.get(_migrationInProgressKey) == true;
    if (inProgress && !_localLock) {
      AppLogger.w('检测到上次迁移中断的孤立锁，正在恢复...', _tag);
      await settingsBox.put(_migrationInProgressKey, false);
      AppLogger.i('孤立锁已清除，允许重新迁移', _tag);
    }

    if (!await _acquireLock()) {
      return const VibeLibraryMigrationResult(
        success: false,
        exportedCount: 0,
        failedCount: 0,
        error: '迁移锁已被占用',
      );
    }

    final previousSchemaVersion = settingsBox.get(_schemaVersionKey);
    final attempt = _MigrationAttempt();

    try {
      if (!await _needsMigration()) {
        await _markCompleted();
        return const VibeLibraryMigrationResult(success: true, exportedCount: 0, failedCount: 0);
      }

      return await _executeMigration(onProgress, attempt);
    } catch (e, stackTrace) {
      AppLogger.e('Vibe 库迁移失败', e, stackTrace, _tag);
      // 主表会还原成旧格式，版本号留在新值会让它被当成已迁移
      if (settingsBox.get(_schemaVersionKey) != previousSchemaVersion) {
        if (previousSchemaVersion == null) {
          await settingsBox.delete(_schemaVersionKey);
        } else {
          await settingsBox.put(_schemaVersionKey, previousSchemaVersion);
        }
      }
      await _rollback(attempt);
      return VibeLibraryMigrationResult(
        success: false,
        exportedCount: 0,
        failedCount: 1,
        error: e.toString(),
        backupPath: attempt.backupPath,
      );
    } finally {
      await _releaseLock();
    }
  }

  Future<VibeLibraryMigrationResult> _executeMigration(
    ProgressCallback? onProgress,
    _MigrationAttempt attempt,
  ) async {
    // 迁移绕过仓库直接重建、删除或回滚主表，展示表必须从新主表重建
    await _repository.setDisplayCacheReady(false);
    onProgress?.call(const VibeLibraryMigrationProgress(
      stage: 'backup', current: 0, total: 1, message: '开始备份 Hive 数据', percentage: 0,
    ),);
    await _closeCurrentEntriesBox();
    attempt.backupPath = await _backupHiveFiles();
    onProgress?.call(const VibeLibraryMigrationProgress(
      stage: 'backup', current: 1, total: 1, message: 'Hive 数据备份完成', percentage: 0.15,
    ),);

    final (legacyEntries, currentCount) = await _readEntries(attempt);
    final total = legacyEntries.length;

    if (total == 0) {
      await _markCompleted();
      onProgress?.call(const VibeLibraryMigrationProgress(
        stage: 'verify', current: 1, total: 1, message: '无旧数据，迁移完成', percentage: 1,
      ),);
      return VibeLibraryMigrationResult(
        success: true,
        exportedCount: 0,
        failedCount: 0,
        backupPath: attempt.backupPath,
      );
    }

    await _convertEntriesInPlace(
      legacyEntries,
      expectedCount: currentCount + total,
      onProgress: onProgress,
      attempt: attempt,
    );

    await _markCompleted();
    onProgress?.call(const VibeLibraryMigrationProgress(
      stage: 'verify', current: 1, total: 1, message: '迁移完成', percentage: 1,
    ),);
    AppLogger.i('Vibe 库迁移完成，导出 $total 条', _tag);

    return VibeLibraryMigrationResult(
      success: true,
      exportedCount: total,
      failedCount: 0,
      backupPath: attempt.backupPath,
    );
  }

  Future<bool> _needsMigration() async {
    final settingsBox = await _openSettingsBox();
    final version = settingsBox.get(_schemaVersionKey);
    if (version is int && version >= _targetSchemaVersion) {
      return false;
    }

    final hivePath = await HiveStorageHelper.instance.getPath();
    final entriesHiveFile = File(p.join(hivePath, '$_entriesBoxName.hive'));
    if (!await entriesHiveFile.exists()) {
      return false;
    }
    return true;
  }

  Future<bool> _acquireLock() async {
    if (_localLock) {
      AppLogger.w('进程内迁移锁已占用', _tag);
      return false;
    }

    final settingsBox = await _openSettingsBox();
    final inProgress = settingsBox.get(_migrationInProgressKey) == true;
    if (inProgress) {
      AppLogger.w('设置中检测到迁移进行中标记，拒绝并发迁移', _tag);
      return false;
    }

    _localLock = true;
    await settingsBox.put(_migrationInProgressKey, true);
    return true;
  }

  Future<void> _releaseLock() async {
    _localLock = false;
    final settingsBox = await _openSettingsBox();
    await settingsBox.put(_migrationInProgressKey, false);
  }

  Future<String> _backupHiveFiles() async {
    final settingsBox = await _openSettingsBox();
    final hivePath = await HiveStorageHelper.instance.getPath();
    final backupRoot =
        Directory(p.join(hivePath, 'vibe_library_migration_backup'));
    if (!await backupRoot.exists()) {
      await backupRoot.create(recursive: true);
    }

    final backupDirName = DateTime.now().millisecondsSinceEpoch.toString();
    final backupDir = Directory(p.join(backupRoot.path, backupDirName));
    await backupDir.create(recursive: true);

    final targets = [
      '$_entriesBoxName.hive',
      '$_entriesBoxName.lock',
      '$_entriesBoxName.crc',
    ];

    for (final name in targets) {
      final src = File(p.join(hivePath, name));
      if (!await src.exists()) {
        continue;
      }
      final dst = File(p.join(backupDir.path, name));
      await src.copy(dst.path);
    }

    await settingsBox.put(_migrationBackupDirKey, backupDir.path);
    AppLogger.i('Hive 备份完成: ${backupDir.path}', _tag);
    return backupDir.path;
  }

  Future<(Map<Object, LegacyVibeLibraryEntryV20>, int)> _readEntries(
    _MigrationAttempt attempt,
  ) async {
    if (!Hive.isAdapterRegistered(_legacyTypeId)) {
      Hive.registerAdapter(LegacyVibeLibraryEntryV20Adapter());
    }
    if (!Hive.isAdapterRegistered(_targetSchemaVersion)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }

    try {
      final box = await Hive.openLazyBox<dynamic>(_entriesBoxName);
      try {
        final legacyEntries = <Object, LegacyVibeLibraryEntryV20>{};
        var currentCount = 0;
        for (final key in box.keys) {
          final entry = await box.get(key);
          if (entry is VibeLibraryEntry) {
            currentCount++;
          } else {
            legacyEntries[key as Object] = entry as LegacyVibeLibraryEntryV20;
          }
        }
        AppLogger.i('读取到旧条目 ${legacyEntries.length} 条', _tag);
        return (legacyEntries, currentCount);
      } finally {
        await box.close();
      }
    } catch (error, stackTrace) {
      if (_isUnknownTypeIdError(error)) {
        final errorText = error.toString();
        final typeId = RegExp(r'unknown typeId[^0-9]*(\d+)')
                .firstMatch(errorText)
                ?.group(1) ??
            'unknown';
        AppLogger.e(
          '检测到未知的 typeId 错误(typeId=$typeId)，备份并清理 corrupt 数据: $errorText',
          error,
          stackTrace,
          _tag,
        );

        final backupPath = await _backupCorruptHiveFiles();
        attempt.entriesMayHaveChanged = true;
        await _deleteCorruptHiveFiles();
        AppLogger.i('已备份 corrupt 文件到: $backupPath', _tag);
        return (<Object, LegacyVibeLibraryEntryV20>{}, 0);
      }
      rethrow;
    }
  }

  bool _isUnknownTypeIdError(Object error) {
    return error is HiveError &&
        error.toString().contains('unknown typeId');
  }

  Future<String> _backupCorruptHiveFiles() async {
    final hivePath = await HiveStorageHelper.instance.getPath();
    final backupRoot =
        Directory(p.join(hivePath, 'vibe_library_migration_backup'));
    if (!await backupRoot.exists()) {
      await backupRoot.create(recursive: true);
    }

    final backupDirName =
        'corrupt_${DateTime.now().millisecondsSinceEpoch}';
    final backupDir = Directory(p.join(backupRoot.path, backupDirName));
    await backupDir.create(recursive: true);

    final targets = [
      '$_entriesBoxName.hive',
      '$_entriesBoxName.lock',
      '$_entriesBoxName.crc',
    ];

    for (final name in targets) {
      final src = File(p.join(hivePath, name));
      if (!await src.exists()) {
        continue;
      }
      final dst = File(p.join(backupDir.path, name));
      await src.copy(dst.path);
    }

    return backupDir.path;
  }

  Future<void> _deleteCorruptHiveFiles() async {
    final hivePath = await HiveStorageHelper.instance.getPath();
    final targets = [
      '$_entriesBoxName.hive',
      '$_entriesBoxName.lock',
      '$_entriesBoxName.crc',
    ];

    for (final name in targets) {
      final file = File(p.join(hivePath, name));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String> _exportEntry(LegacyVibeLibraryEntryV20 entry) async {
    final vibePath = await VibeLibraryPathHelper.instance.getPath();
    await VibeLibraryPathHelper.instance.ensurePathExists(vibePath);

    final vibe = VibeReference(
      displayName:
          entry.vibeDisplayName.isEmpty ? entry.name : entry.vibeDisplayName,
      vibeEncoding: entry.vibeEncoding,
      thumbnail: entry.vibeThumbnail,
      rawImageData: entry.rawImageData,
      strength: entry.strength,
      infoExtracted: entry.infoExtracted,
      sourceType: _resolveSourceType(entry.sourceTypeIndex),
    );

    return entry.sourceTypeIndex == VibeSourceType.naiv4vibebundle.index
        ? _fileStorage.saveBundleToFile([vibe], bundleName: entry.name)
        : _fileStorage.saveVibeToFile(vibe, customName: entry.name);
  }

  Future<void> _convertEntriesInPlace(
    Map<Object, LegacyVibeLibraryEntryV20> legacyEntries, {
    required int expectedCount,
    required ProgressCallback? onProgress,
    required _MigrationAttempt attempt,
  }) async {
    final box = await Hive.openLazyBox<dynamic>(
      _entriesBoxName,
      // 逐条覆盖会不断触发自动压缩，每次都重写整个文件；改为结束后压缩一次
      compactionStrategy: (_, _) => false,
    );
    try {
      await _convertLegacyEntries(box, legacyEntries, onProgress, attempt);
      onProgress?.call(
        const VibeLibraryMigrationProgress(
          stage: 'rebuild',
          current: 0,
          total: 1,
          message: '整理 Hive box',
          percentage: 0.8,
        ),
      );
      final actualCount = box.length;
      if (actualCount != expectedCount) {
        throw StateError(
          '重建后条目数量不一致: expected=$expectedCount, actual=$actualCount',
        );
      }
      await box.compact();
    } finally {
      await box.close();
    }
    onProgress?.call(
      const VibeLibraryMigrationProgress(
        stage: 'rebuild',
        current: 1,
        total: 1,
        message: 'Hive box 整理完成',
        percentage: 0.95,
      ),
    );
  }

  Future<void> _convertLegacyEntries(
    LazyBox<dynamic> box,
    Map<Object, LegacyVibeLibraryEntryV20> legacyEntries,
    ProgressCallback? onProgress,
    _MigrationAttempt attempt,
  ) async {
    final total = legacyEntries.length;
    final obsoleteKeys = legacyEntries.keys.toSet();
    var index = 0;
    for (final old in legacyEntries.values) {
      onProgress?.call(
        VibeLibraryMigrationProgress(
          stage: 'export',
          current: index + 1,
          total: total,
          message: '导出条目 ${index + 1}/$total: ${old.name}',
          percentage: 0.15 + (0.6 * index / total),
        ),
      );
      final filePath = await _exportEntry(old);
      attempt.createdFiles.add(filePath);
      final mapped = _mapEntry(old, filePath);
      attempt.entriesMayHaveChanged = true;
      await box.put(mapped.id, mapped);
      obsoleteKeys.remove(mapped.id);
      index++;
    }
    await box.deleteAll(obsoleteKeys);
    onProgress?.call(
      VibeLibraryMigrationProgress(
        stage: 'export',
        current: total,
        total: total,
        message: '导出完成，共 $total 条',
        percentage: 0.75,
      ),
    );
  }

  VibeLibraryEntry _mapEntry(LegacyVibeLibraryEntryV20 old, String filePath) {
    return VibeLibraryEntry(
      id: old.id,
      name: old.name,
      vibeDisplayName: old.vibeDisplayName,
      vibeEncoding: old.vibeEncoding,
      vibeThumbnail: old.vibeThumbnail,
      rawImageData: old.rawImageData,
      strength: old.strength,
      infoExtracted: old.infoExtracted,
      sourceTypeIndex: old.sourceTypeIndex,
      categoryId: old.categoryId,
      tags: old.tags,
      isFavorite: old.isFavorite,
      usedCount: old.usedCount,
      lastUsedAt: old.lastUsedAt,
      createdAt: old.createdAt ?? DateTime.now(),
      thumbnail: old.thumbnail,
      filePath: filePath,
    );
  }

  Future<void> _rollback(_MigrationAttempt attempt) async {
    AppLogger.w('开始回滚 Vibe 库迁移', _tag);

    final backupPath = attempt.backupPath;
    if (attempt.entriesMayHaveChanged && backupPath != null) {
      await _restoreFromBackup(backupPath);
    }

    for (final filePath in attempt.createdFiles) {
      await _fileStorage.deleteVibeFile(filePath);
    }

    final settingsBox = await _openSettingsBox();
    await settingsBox.put(_migrationInProgressKey, false);
    AppLogger.w('Vibe 库迁移已回滚', _tag);
  }

  Future<void> _closeCurrentEntriesBox() async {
    if (Hive.isBoxOpen(_entriesBoxName)) {
      await Hive.lazyBox<VibeLibraryEntry>(_entriesBoxName).close();
    }
  }

  Future<void> _restoreFromBackup(String backupDirPath) async {
    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) return;

    final hivePath = await HiveStorageHelper.instance.getPath();
    await for (final entity in backupDir.list(recursive: false)) {
      if (entity is! File) continue;

      final restoredPath = p.join(hivePath, p.basename(entity.path));
      final temporaryFile = File('$restoredPath.restore');
      try {
        await entity.copy(temporaryFile.path);
        await temporaryFile.rename(restoredPath);
      } on FileSystemException {
        if (await temporaryFile.exists()) await temporaryFile.delete();
        rethrow;
      }
    }
  }

  Future<void> _markCompleted() async {
    final settingsBox = await _openSettingsBox();
    await settingsBox.put(_schemaVersionKey, _targetSchemaVersion);
    await settingsBox.put(_migrationInProgressKey, false);
  }

  Future<Box<dynamic>> _openSettingsBox() async {
    if (Hive.isBoxOpen(_settingsBoxName)) {
      return Hive.box(_settingsBoxName);
    }
    return Hive.openBox(_settingsBoxName);
  }

  VibeSourceType _resolveSourceType(int sourceTypeIndex) {
    if (sourceTypeIndex < 0 ||
        sourceTypeIndex >= VibeSourceType.values.length) {
      return VibeSourceType.rawImage;
    }
    return VibeSourceType.values[sourceTypeIndex];
  }
}

class _MigrationAttempt {
  String? backupPath;
  bool entriesMayHaveChanged = false;
  final createdFiles = <String>[];
}

class LegacyVibeLibraryEntryV20 {
  LegacyVibeLibraryEntryV20({
    required this.id,
    required this.name,
    required this.vibeDisplayName,
    required this.vibeEncoding,
    required this.vibeThumbnail,
    required this.rawImageData,
    required this.strength,
    required this.infoExtracted,
    required this.sourceTypeIndex,
    required this.categoryId,
    required this.tags,
    required this.isFavorite,
    required this.usedCount,
    required this.lastUsedAt,
    required this.createdAt,
    required this.thumbnail,
  });

  final String id;
  final String name;
  final String vibeDisplayName;
  final String vibeEncoding;
  final Uint8List? vibeThumbnail;
  final Uint8List? rawImageData;
  final double strength;
  final double infoExtracted;
  final int sourceTypeIndex;
  final String? categoryId;
  final List<String> tags;
  final bool isFavorite;
  final int usedCount;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final Uint8List? thumbnail;
}

class LegacyVibeLibraryEntryV20Adapter
    extends TypeAdapter<LegacyVibeLibraryEntryV20> {
  @override
  final int typeId = 20;

  @override
  LegacyVibeLibraryEntryV20 read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return LegacyVibeLibraryEntryV20(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      vibeDisplayName: fields[2] as String? ?? '',
      vibeEncoding: fields[3] as String? ?? '',
      vibeThumbnail: fields[4] as Uint8List?,
      rawImageData: fields[5] as Uint8List?,
      strength: (fields[6] as num?)?.toDouble() ?? 0.6,
      infoExtracted: (fields[7] as num?)?.toDouble() ?? 0.7,
      sourceTypeIndex: fields[8] as int? ?? 3,
      categoryId: fields[9] as String?,
      tags: (fields[10] as List?)?.cast<String>() ?? const [],
      isFavorite: fields[11] as bool? ?? false,
      usedCount: fields[12] as int? ?? 0,
      lastUsedAt: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime?,
      thumbnail: fields[15] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, LegacyVibeLibraryEntryV20 obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.vibeDisplayName)
      ..writeByte(3)
      ..write(obj.vibeEncoding)
      ..writeByte(4)
      ..write(obj.vibeThumbnail)
      ..writeByte(5)
      ..write(obj.rawImageData)
      ..writeByte(6)
      ..write(obj.strength)
      ..writeByte(7)
      ..write(obj.infoExtracted)
      ..writeByte(8)
      ..write(obj.sourceTypeIndex)
      ..writeByte(9)
      ..write(obj.categoryId)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.isFavorite)
      ..writeByte(12)
      ..write(obj.usedCount)
      ..writeByte(13)
      ..write(obj.lastUsedAt)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.thumbnail);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LegacyVibeLibraryEntryV20Adapter &&
            runtimeType == other.runtimeType &&
            typeId == other.typeId;
  }
}
