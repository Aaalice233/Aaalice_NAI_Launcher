/// 数据库架构导出文件 (V2)
///
/// 提供统一的数据库访问接口，包括：
/// - 基础设施层：DatabaseManager, ConnectionPoolHolder 等
/// - 数据源层：TranslationDataSource, CooccurrenceDataSource, DanbooruTagDataSource
/// - 服务层：TranslationService, CooccurrenceService, CompletionService
///
/// V2 架构关键改进：
/// - ConnectionPool 不再是单例，支持重建
/// - DatabaseManager 通过 ConnectionPoolHolder 获取连接
/// - recover() 后自动使用新的有效连接
///
/// 使用示例：
/// ```dart
/// import 'package:nai_launcher/core/database/database.dart';
///
/// // 获取数据库管理器
/// final manager = await ref.watch(databaseManagerProvider.future);
///
/// // 检查数据库健康状态
/// final health = await manager.quickHealthCheck();
/// if (health.isCorrupted) {
///   await manager.recover(); // 自动重建 ConnectionPool
/// }
/// ```
library;

// ============================================================================
// Infrastructure (V2)
// ============================================================================

export 'database_manager.dart'
    show
        DatabaseManager,
        DatabaseInitState;

export 'database_providers.dart'
    show
        databaseManagerProvider,
        databaseInitializedProvider,
        databaseStatisticsProvider;

export 'connection_pool_holder.dart'
    show
        ConnectionPoolHolder;

export 'connection_pool.dart'
    show
        ConnectionPool;

export 'data_source.dart'
    show
        DataSource,
        BaseDataSource,
        DataSourceState,
        DataSourceType,
        DataSourceHealth,
        DataSourceInfo,
        HealthStatus;

export 'data_source_types.dart'
    show
        HealthCheckResult;

// ============================================================================
// DataSources
// ============================================================================

export 'datasources/danbooru_tag_data_source.dart'
    show
        DanbooruTagRecord,
        TagCategory,
        TagSearchMode;

// ============================================================================
// Services
// ============================================================================

export 'services/services.dart';
