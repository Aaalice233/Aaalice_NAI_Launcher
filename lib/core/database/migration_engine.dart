import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';

/// 迁移结果
class MigrationResult {
  final bool success;
  final int fromVersion;
  final int toVersion;
  final String message;
  final List<String> appliedMigrations;
  final Map<String, dynamic> details;

  const MigrationResult({
    required this.success,
    required this.fromVersion,
    required this.toVersion,
    required this.message,
    this.appliedMigrations = const [],
    this.details = const {},
  });

  factory MigrationResult.success({
    required int fromVersion,
    required int toVersion,
    required String message,
    List<String> appliedMigrations = const [],
    Map<String, dynamic> details = const {},
  }) {
    return MigrationResult(
      success: true,
      fromVersion: fromVersion,
      toVersion: toVersion,
      message: message,
      appliedMigrations: appliedMigrations,
      details: details,
    );
  }

  factory MigrationResult.failure({
    required int fromVersion,
    required int toVersion,
    required String message,
    List<String> appliedMigrations = const [],
    Map<String, dynamic> details = const {},
  }) {
    return MigrationResult(
      success: false,
      fromVersion: fromVersion,
      toVersion: toVersion,
      message: message,
      appliedMigrations: appliedMigrations,
      details: details,
    );
  }
}

/// 数据库迁移抽象类
abstract class Migration {
  /// 迁移版本号
  int get version;

  /// 迁移描述
  String get description;

  /// 执行迁移
  Future<void> up(Database db);

  /// 回滚迁移
  Future<void> down(Database db);
}

/// 数据库迁移引擎
///
/// 管理数据库版本控制和迁移：
/// - migrate(): 应用待处理的迁移
/// - rollback(): 回滚迁移
/// - 版本跟踪在 db_metadata 表中
class MigrationEngine {
  MigrationEngine._();

  static final MigrationEngine _instance = MigrationEngine._();

  /// 获取单例实例
  static MigrationEngine get instance => _instance;

  final List<Migration> _migrations = [];
  bool _initialized = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 获取已注册的迁移数量
  int get migrationCount => _migrations.length;

  /// 初始化迁移引擎
  ///
  /// 创建 db_metadata 表（如果不存在）
  Future<void> initialize() async {
    if (_initialized) return;

    final db = await ConnectionPoolHolder.instance.acquire();
    try {
      // 创建元数据表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS db_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // 初始化版本号
      await _setVersion(db, 0);

      _initialized = true;
      AppLogger.i('MigrationEngine initialized', 'MigrationEngine');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize MigrationEngine', e, stack, 'MigrationEngine');
      rethrow;
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 注册迁移
  ///
  /// [migration] 要注册的迁移
  void registerMigration(Migration migration) {
    // 检查版本号是否已存在
    if (_migrations.any((m) => m.version == migration.version)) {
      throw ArgumentError(
        'Migration with version ${migration.version} already registered',
      );
    }

    _migrations.add(migration);
    _migrations.sort((a, b) => a.version.compareTo(b.version));

    AppLogger.d(
      'Registered migration v${migration.version}: ${migration.description}',
      'MigrationEngine',
    );
  }

  /// 批量注册迁移
  ///
  /// [migrations] 要注册的迁移列表
  void registerMigrations(List<Migration> migrations) {
    for (final migration in migrations) {
      registerMigration(migration);
    }
  }

  /// 获取当前数据库版本
  Future<int> getCurrentVersion() async {
    final db = await ConnectionPoolHolder.instance.acquire();
    try {
      return await _getVersion(db);
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 获取目标版本（最新迁移版本）
  int getTargetVersion() {
    if (_migrations.isEmpty) return 0;
    return _migrations.map((m) => m.version).reduce((a, b) => a > b ? a : b);
  }

  /// 执行迁移
  ///
  /// 应用所有待处理的迁移，直到目标版本
  ///
  /// [targetVersion] 目标版本，默认为最新版本
  /// 返回：迁移结果
  Future<MigrationResult> migrate({int? targetVersion}) async {
    if (!_initialized) {
      await initialize();
    }

    final currentVersion = await getCurrentVersion();
    final target = targetVersion ?? getTargetVersion();

    AppLogger.i(
      'Starting migration from v$currentVersion to v$target',
      'MigrationEngine',
    );

    if (currentVersion == target) {
      return MigrationResult.success(
        fromVersion: currentVersion,
        toVersion: target,
        message: 'Database is already at version $target',
      );
    }

    if (currentVersion > target) {
      return MigrationResult.failure(
        fromVersion: currentVersion,
        toVersion: target,
        message: 'Cannot migrate to older version (current: $currentVersion, target: $target)',
      );
    }

    final appliedMigrations = <String>[];
    final db = await ConnectionPoolHolder.instance.acquire();

    try {
      // 获取需要应用的迁移
      final pendingMigrations = _migrations
          .where((m) => m.version > currentVersion && m.version <= target)
          .toList();

      for (final migration in pendingMigrations) {
        AppLogger.i(
          'Applying migration v${migration.version}: ${migration.description}',
          'MigrationEngine',
        );

        try {
          await migration.up(db);
          await _setVersion(db, migration.version);
          appliedMigrations.add('v${migration.version}');

          AppLogger.i(
            'Successfully applied migration v${migration.version}',
            'MigrationEngine',
          );
        } catch (e, stack) {
          AppLogger.e(
            'Failed to apply migration v${migration.version}',
            e,
            stack,
            'MigrationEngine',
          );
          return MigrationResult.failure(
            fromVersion: currentVersion,
            toVersion: migration.version,
            message: 'Migration v${migration.version} failed: $e',
            appliedMigrations: appliedMigrations,
            details: {'error': e.toString(), 'migration': migration.version},
          );
        }
      }

      AppLogger.i(
        'Migration completed successfully (v$currentVersion -> v$target)',
        'MigrationEngine',
      );

      return MigrationResult.success(
        fromVersion: currentVersion,
        toVersion: target,
        message: 'Migration completed successfully',
        appliedMigrations: appliedMigrations,
        details: {'migrationsApplied': pendingMigrations.length},
      );
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 回滚迁移
  ///
  /// 回滚到指定版本
  ///
  /// [targetVersion] 目标版本
  /// 返回：回滚结果
  Future<MigrationResult> rollback(int targetVersion) async {
    if (!_initialized) {
      await initialize();
    }

    final currentVersion = await getCurrentVersion();

    AppLogger.i(
      'Starting rollback from v$currentVersion to v$targetVersion',
      'MigrationEngine',
    );

    if (currentVersion == targetVersion) {
      return MigrationResult.success(
        fromVersion: currentVersion,
        toVersion: targetVersion,
        message: 'Database is already at version $targetVersion',
      );
    }

    if (currentVersion < targetVersion) {
      return MigrationResult.failure(
        fromVersion: currentVersion,
        toVersion: targetVersion,
        message: 'Cannot rollback to newer version (current: $currentVersion, target: $targetVersion)',
      );
    }

    final appliedMigrations = <String>[];
    final db = await ConnectionPoolHolder.instance.acquire();

    try {
      // 获取需要回滚的迁移（按版本降序）
      final migrationsToRollback = _migrations
          .where((m) => m.version > targetVersion && m.version <= currentVersion)
          .toList()
        ..sort((a, b) => b.version.compareTo(a.version));

      for (final migration in migrationsToRollback) {
        AppLogger.i(
          'Rolling back migration v${migration.version}: ${migration.description}',
          'MigrationEngine',
        );

        try {
          await migration.down(db);
          final previousVersion = _getPreviousVersion(migration.version);
          await _setVersion(db, previousVersion);
          appliedMigrations.add('v${migration.version}');

          AppLogger.i(
            'Successfully rolled back migration v${migration.version}',
            'MigrationEngine',
          );
        } catch (e, stack) {
          AppLogger.e(
            'Failed to rollback migration v${migration.version}',
            e,
            stack,
            'MigrationEngine',
          );
          return MigrationResult.failure(
            fromVersion: currentVersion,
            toVersion: migration.version,
            message: 'Rollback v${migration.version} failed: $e',
            appliedMigrations: appliedMigrations,
            details: {'error': e.toString(), 'migration': migration.version},
          );
        }
      }

      AppLogger.i(
        'Rollback completed successfully (v$currentVersion -> v$targetVersion)',
        'MigrationEngine',
      );

      return MigrationResult.success(
        fromVersion: currentVersion,
        toVersion: targetVersion,
        message: 'Rollback completed successfully',
        appliedMigrations: appliedMigrations,
        details: {'migrationsRolledBack': migrationsToRollback.length},
      );
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 获取迁移历史
  ///
  /// 返回：已应用的迁移版本列表
  Future<List<Map<String, dynamic>>> getMigrationHistory() async {
    final currentVersion = await getCurrentVersion();

    return _migrations.map((m) => {
      'version': m.version,
      'description': m.description,
      'applied': m.version <= currentVersion,
    },).toList();
  }

  /// 获取数据库版本（内部方法）
  Future<int> _getVersion(Database db) async {
    try {
      final result = await db.query(
        'db_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['version'],
      );

      if (result.isEmpty) return 0;
      return int.tryParse(result.first['value'] as String) ?? 0;
    } catch (e) {
      // 表可能不存在
      return 0;
    }
  }

  /// 设置数据库版本（内部方法）
  Future<void> _setVersion(Database db, int version) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'db_metadata',
      {
        'key': 'version',
        'value': version.toString(),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取前一个版本号
  int _getPreviousVersion(int currentVersion) {
    final previousMigrations = _migrations
        .where((m) => m.version < currentVersion)
        .toList();

    if (previousMigrations.isEmpty) return 0;
    return previousMigrations.map((m) => m.version).reduce((a, b) => a > b ? a : b);
  }

  /// 重置迁移引擎
  void reset() {
    _migrations.clear();
    _initialized = false;
    AppLogger.d('MigrationEngine reset', 'MigrationEngine');
  }
}
