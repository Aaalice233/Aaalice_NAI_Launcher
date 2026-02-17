import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'datasources/cooccurrence_data_source.dart';
import 'datasources/danbooru_tag_data_source.dart';
import 'datasources/translation_data_source.dart';
import 'database_manager.dart';
import 'health_checker.dart';
import 'migration_engine.dart';
import 'services/cooccurrence_service.dart';
import 'services/completion_service.dart';
import 'services/translation_service.dart';

part 'database_providers.g.dart';

/// 数据库管理器 Provider (keepAlive)
///
/// 提供 DatabaseManager 单例实例
/// 在应用生命周期内保持存活
@Riverpod(keepAlive: true)
Future<DatabaseManager> databaseManager(Ref ref) async {
  // 初始化数据库管理器
  final manager = await DatabaseManager.initialize();
  
  // 监听 Riverpod 销毁事件
  ref.onDispose(() {
    // 注意：这里不调用 dispose()，因为 DatabaseManager 是单例
    // 应该在应用退出时统一释放
  });
  
  return manager;
}

/// 数据库初始化状态 Provider
///
/// 异步初始化完成标志
/// 用于监听数据库是否已完全初始化
@riverpod
Future<bool> databaseInitialized(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  
  // 等待初始化完成
  await manager.initialized;
  
  return manager.isInitialized;
}

/// 数据库初始化状态流 Provider
///
/// 提供实时的初始化状态变化
@riverpod
Stream<DatabaseInitState> databaseInitState(Ref ref) async* {
  final manager = await ref.watch(databaseManagerProvider.future);
  
  // 初始状态
  yield manager.state;
  
  // 监听状态变化（轮询方式）
  while (true) {
    await Future.delayed(const Duration(milliseconds: 100));
    yield manager.state;
    
    if (manager.isInitialized || manager.hasError) {
      break;
    }
  }
}

/// 数据库路径 Provider
///
/// 提供当前数据库文件路径
@riverpod
Future<String?> databasePath(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return manager.dbPath;
}

/// 数据库统计信息 Provider
///
/// 提供数据库统计信息（表大小、连接数等）
@riverpod
Future<Map<String, dynamic>> databaseStatistics(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return await manager.getStatistics();
}

/// 数据库健康状态 Provider
///
/// 提供最近一次健康检查结果
@riverpod
Future<HealthCheckResult> databaseHealth(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return await manager.quickHealthCheck();
}

/// 数据库后台检查完成状态 Provider
///
/// 指示后台完整检查是否已完成
@riverpod
Future<bool> databaseBackgroundCheckComplete(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  
  // 等待后台检查完成
  while (!manager.backgroundCheckCompleted) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  return true;
}

/// 迁移引擎 Provider
///
/// 提供 MigrationEngine 实例
@Riverpod(keepAlive: true)
MigrationEngine migrationEngine(Ref ref) {
  return MigrationEngine.instance;
}

/// 数据库当前版本 Provider
///
/// 提供当前数据库版本号
@riverpod
Future<int> databaseCurrentVersion(Ref ref) async {
  final engine = ref.watch(migrationEngineProvider);
  return await engine.getCurrentVersion();
}

/// 数据库目标版本 Provider
///
/// 提供目标数据库版本号
@riverpod
int databaseTargetVersion(Ref ref) {
  final engine = ref.watch(migrationEngineProvider);
  return engine.getTargetVersion();
}

/// 迁移历史 Provider
///
/// 提供已应用的迁移历史列表
@riverpod
Future<List<Map<String, dynamic>>> migrationHistory(Ref ref) async {
  final engine = ref.watch(migrationEngineProvider);
  return await engine.getMigrationHistory();
}

/// 数据库错误信息 Provider
///
/// 提供数据库初始化错误信息（如果有）
@riverpod
Future<String?> databaseError(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return manager.errorMessage;
}

// ============================================================================
// Phase 3: Service Layer Providers
// ============================================================================

/// 翻译数据源 Provider (keepAlive)
///
/// 异步初始化，等待数据库管理器就绪后设置连接
@Riverpod(keepAlive: true)
Future<TranslationDataSource> translationDataSource(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;

  final dataSource = TranslationDataSource();

  // 获取数据库连接并设置
  final db = await manager.acquireDatabase();
  dataSource.setDatabase(db);
  await dataSource.initialize();

  // 释放连接（DataSource 会保持自己的引用）
  await manager.releaseDatabase(db);

  ref.onDispose(() {
    dataSource.dispose();
  });

  return dataSource;
}

/// 共现数据源 Provider (keepAlive)
///
/// 异步初始化，等待数据库管理器就绪后设置连接
@Riverpod(keepAlive: true)
Future<CooccurrenceDataSource> cooccurrenceDataSource(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;

  final dataSource = CooccurrenceDataSource();

  // 获取数据库连接并设置
  final db = await manager.acquireDatabase();
  dataSource.setDatabase(db);

  // 设置翻译数据源引用（用于依赖关系）
  final translationDS = await ref.watch(translationDataSourceProvider.future);
  dataSource.setTranslationDataSource(translationDS);

  await dataSource.initialize();

  // 释放连接
  await manager.releaseDatabase(db);

  ref.onDispose(() {
    dataSource.dispose();
  });

  return dataSource;
}

/// Danbooru 标签数据源 Provider (keepAlive)
///
/// 异步初始化，等待数据库管理器就绪后设置连接
@Riverpod(keepAlive: true)
Future<DanbooruTagDataSource> danbooruTagDataSource(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;

  final dataSource = DanbooruTagDataSource();

  // 获取数据库连接并设置
  final db = await manager.acquireDatabase();
  dataSource.setDatabase(db);

  // 设置翻译数据源引用（用于依赖关系）
  final translationDS = await ref.watch(translationDataSourceProvider.future);
  dataSource.setTranslationDataSource(translationDS);

  await dataSource.initialize();

  // 释放连接
  await manager.releaseDatabase(db);

  ref.onDispose(() {
    dataSource.dispose();
  });

  return dataSource;
}

/// 翻译服务 Provider (keepAlive)
///
/// 提供 TranslationService 实例
/// 在应用生命周期内保持存活
@Riverpod(keepAlive: true)
Future<TranslationService> translationService(Ref ref) async {
  final dataSource = await ref.watch(translationDataSourceProvider.future);
  return TranslationService(dataSource);
}

/// 共现服务 Provider (keepAlive)
///
/// 提供 CooccurrenceService 实例
/// 在应用生命周期内保持存活
@Riverpod(keepAlive: true)
Future<CooccurrenceService> cooccurrenceService(Ref ref) async {
  final dataSource = await ref.watch(cooccurrenceDataSourceProvider.future);
  return CooccurrenceService(dataSource);
}

/// 补全服务 Provider (keepAlive)
///
/// 提供 CompletionService 实例
/// 在应用生命周期内保持存活
@Riverpod(keepAlive: true)
Future<CompletionService> completionService(Ref ref) async {
  final tagDataSource = await ref.watch(danbooruTagDataSourceProvider.future);
  final translationDataSource = await ref.watch(translationDataSourceProvider.future);
  return CompletionService(tagDataSource, translationDataSource);
}
