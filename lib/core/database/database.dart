/// 新数据库架构导出文件
///
/// 提供统一的数据库访问接口，包括：
/// - 基础设施层：DatabaseManager, ConnectionPool, HealthChecker 等
/// - 数据源层：TranslationDataSource, CooccurrenceDataSource, DanbooruTagDataSource
/// - 服务层：TranslationService, CooccurrenceService, CompletionService
///
/// 使用示例：
/// ```dart
/// import 'package:nai_launcher/core/database/database.dart';
///
/// // 获取数据库管理器
/// final manager = await ref.watch(databaseManagerProvider.future);
///
/// // 获取标签数量
/// final completionService = await ref.watch(completionServiceProvider.future);
/// final count = await completionService.getTagCount();
///
/// // 检查数据库健康状态
/// final health = await manager.quickHealthCheck();
/// if (health.isCorrupted) {
///   await manager.recover();
/// }
/// ```
library;

// ============================================================================
// Infrastructure
// ============================================================================

export 'database_manager.dart'
    show
        DatabaseManager,
        DatabaseInitState;

export 'database_providers.dart'
    show
        databaseManagerProvider,
        databaseInitializedProvider,
        databaseInitStateProvider,
        databasePathProvider,
        databaseStatisticsProvider,
        databaseHealthProvider,
        databaseBackgroundCheckCompleteProvider,
        migrationEngineProvider,
        databaseCurrentVersionProvider,
        databaseTargetVersionProvider,
        migrationHistoryProvider,
        databaseErrorProvider,
        translationDataSourceProvider,
        cooccurrenceDataSourceProvider,
        danbooruTagDataSourceProvider,
        translationServiceProvider,
        cooccurrenceServiceProvider,
        completionServiceProvider;

export 'connection_pool.dart'
    show
        ConnectionPool;

export 'health_checker.dart'
    show
        HealthChecker,
        HealthCheckResult,
        HealthStatus;

export 'recovery_manager.dart'
    show
        RecoveryManager,
        RecoveryResult;

export 'migration_engine.dart'
    show
        MigrationEngine,
        Migration,
        MigrationResult;

export 'data_source_registry.dart'
    show
        DataSourceRegistry;

export 'data_source.dart'
    show
        DataSource;

// ============================================================================
// DataSources
// ============================================================================

export 'datasources/datasources.dart';

// ============================================================================
// Services
// ============================================================================

export 'services/services.dart';
