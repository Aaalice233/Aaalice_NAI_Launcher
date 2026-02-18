import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../presentation/providers/data_source_cache_provider.dart';
import '../../services/danbooru_tags_lazy_service.dart';
import '../../utils/app_logger.dart';
import '../connection_pool_lifecycle_manager.dart';
import '../database.dart';
import '../gate/database_access_gate.dart';
import '../operations/atomic_clear_operation.dart';
import '../state/database_state.dart';
import '../state/database_state_machine.dart';

part 'database_state_providers.g.dart';

/// 数据库状态机
@Riverpod(keepAlive: true)
DatabaseStateMachine databaseStateMachine(Ref ref) {
  final machine = DatabaseStateMachine();
  ref.onDispose(machine.dispose);
  return machine;
}

/// 连接池生命周期管理器
///
/// 关键修复：确保与 ConnectionPoolHolder 状态同步
@Riverpod(keepAlive: true)
ConnectionPoolLifecycleManager connectionPoolLifecycle(Ref ref) {
  final manager = ConnectionPoolLifecycleManager();

  // 步骤1: 首先同步状态（如果 Holder 已初始化）
  manager.syncWithHolder();

  // 步骤2: 尝试从 DatabaseManager 获取数据库路径进行初始化
  try {
    final dbManager = DatabaseManager.instance;
    if (dbManager.dbPath != null && manager.dbPath == null) {
      // 使用 scheduleMicrotask 避免阻塞 provider 创建
      Future.microtask(() async {
        try {
          await manager.initialize(
            dbPath: dbManager.dbPath!,
            maxConnections: 3,
          );
        } catch (e) {
          AppLogger.w(
            'Failed to initialize ConnectionPoolLifecycleManager: $e',
            'ConnectionPoolLifecycle',
          );
        }
      });
    }
  } catch (e) {
    // DatabaseManager 尚未初始化，syncWithHolder 已经处理了 Holder 已初始化的情况
  }

  ref.onDispose(manager.dispose);
  return manager;
}

/// 数据库访问门控
@Riverpod(keepAlive: true)
DatabaseAccessGate databaseAccessGate(Ref ref) {
  final stateMachine = ref.watch(databaseStateMachineProvider);
  return DatabaseAccessGate(stateMachine);
}

/// 原子清除操作
@Riverpod(keepAlive: true)
AtomicClearOperation atomicClearOperation(Ref ref) {
  return AtomicClearOperation(
    ref.watch(databaseStateMachineProvider),
    ref.watch(databaseAccessGateProvider),
    ref.watch(connectionPoolLifecycleProvider),
  );
}

/// 当前数据库状态流
@Riverpod(keepAlive: true)
Stream<DatabaseStateChange> databaseStateChanges(Ref ref) {
  final machine = ref.watch(databaseStateMachineProvider);
  return machine.stateChanges;
}

/// 数据库是否就绪
@riverpod
Future<bool> databaseIsReady(Ref ref) async {
  final machine = ref.watch(databaseStateMachineProvider);

  // 如果已经就绪，立即返回
  if (machine.isOperational) {
    return true;
  }

  // 等待就绪状态
  await machine.waitForReady(timeout: const Duration(seconds: 30));
  return true;
}

/// 数据库状态监控（用于 UI 显示）
@Riverpod(keepAlive: true)
class DatabaseStatusNotifier extends _$DatabaseStatusNotifier {
  @override
  DatabaseState build() {
    final machine = ref.watch(databaseStateMachineProvider);

    // 监听状态变化
    ref.listen(databaseStateChangesProvider, (previous, next) {
      next.whenData((change) {
        state = change.current;
      });
    });

    return machine.currentState;
  }

  /// 标记数据库已就绪（由 DatabaseManager 调用）
  void markReady() async {
    final machine = ref.read(databaseStateMachineProvider);
    if (machine.currentState != DatabaseState.ready) {
      await machine.transition(
        DatabaseStateEvent.markReady,
        reason: 'Database initialization completed',
      );
    }
  }

  /// 执行原子清除操作
  Future<ClearOperationResult> clearCache({
    required Future<void> Function()? serviceClearCallback,
  }) async {
    final operation = ref.read(atomicClearOperationProvider);
    final lifecycle = ref.read(connectionPoolLifecycleProvider);

    return operation.execute(
      clearTables: () async {
        // 关键修复：使用 lifecycleManager 获取连接
        // 由于 syncWithHolder() 确保了状态同步，现在可以正常使用
        final db = await lifecycle.acquireConnection();
        try {
          const tables = ['danbooru_tags', 'translations', 'cooccurrences'];
          final stats = <String, int>{};

          await db.execute('BEGIN TRANSACTION');
          try {
            for (final table in tables) {
              final countResult = await db.rawQuery(
                'SELECT COUNT(*) as count FROM $table',
              );
              final count =
                  (countResult.first['count'] as num?)?.toInt() ?? 0;

              await db.execute('DELETE FROM $table');
              stats[table] = count;
            }
            await db.execute('COMMIT');

            return stats;
          } catch (e) {
            await db.execute('ROLLBACK');
            rethrow;
          }
        } finally {
          await lifecycle.releaseConnection(db);
        }
      },
      preClear: serviceClearCallback,
      postClear: () async {
        // 清除完成后刷新 Provider
        // 关键：按依赖顺序失效 - 先失效数据源 Provider，再失效服务 Provider
        // 否则缓存的服务实例仍持有旧的数据源引用
        ref.invalidate(danbooruTagDataSourceProvider);
        ref.invalidate(danbooruTagsLazyServiceProvider);
        ref.invalidate(danbooruTagsCacheNotifierProvider);
        AppLogger.i(
          '[DatabaseStatusNotifier] Providers invalidated after clear: '
          'danbooruTagDataSourceProvider, danbooruTagsLazyServiceProvider, '
          'danbooruTagsCacheNotifierProvider',
          'DatabaseStatusNotifier',
        );
      },
      tablesToClear: const ['danbooru_tags', 'translations', 'cooccurrences'],
    );
  }
}
