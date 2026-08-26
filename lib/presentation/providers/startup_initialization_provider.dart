import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/database/database_providers.dart';
import '../../core/network/proxy_service.dart';
import '../../core/network/system_proxy_http_overrides.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/shortcuts/shortcut_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/hive_startup_box_opener.dart';
import '../../core/utils/hive_storage_helper.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/gallery/scan_state_manager.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/vibe_library_migration_service.dart';

/// 可替换的启动关键任务边界，便于验证 Splash 与真实初始化的时序。
class StartupInitializationTasks {
  const StartupInitializationTasks({
    required this.initializeRuntimeConfiguration,
    required this.runDataMigration,
    required this.initializeDatabase,
    required this.initializeCriticalServices,
    this.enablePostWarmupTasks = true,
  });

  final Future<void> Function() initializeRuntimeConfiguration;
  final Future<MigrationResult> Function(
    void Function(String stage, double progress) onProgress,
  )
  runDataMigration;
  final Future<void> Function() initializeDatabase;
  final Future<void> Function() initializeCriticalServices;
  final bool enablePostWarmupTasks;
}

final startupInitializationTasksProvider = Provider<StartupInitializationTasks>(
  (ref) {
    MigrationResult? completedMigration;
    return StartupInitializationTasks(
      initializeRuntimeConfiguration: () async {
        final settingsBox = Hive.box(StorageKeys.settingsBox);
        final fileLoggingEnabled =
            settingsBox.get(
              StorageKeys.fileLoggingEnabled,
              defaultValue: false,
            ) ==
            true;
        await AppLogger.setFileLoggingEnabled(fileLoggingEnabled);

        try {
          VideoPlayerMediaKit.ensureInitialized(
            windows: Platform.isWindows,
            macOS: Platform.isMacOS,
          );
        } catch (error, stackTrace) {
          AppLogger.e(
            'Video player initialization failed; continuing startup',
            error,
            stackTrace,
            'Warmup',
          );
        }

        _configureSystemProxy(settingsBox);
      },
      runDataMigration: (onProgress) async {
        final cached = completedMigration;
        if (cached != null) return cached;

        final migrationService = DataMigrationService.instance;
        migrationService.onProgress = onProgress;
        try {
          final result = await migrationService.migrateAll();
          final vibeResult = await VibeLibraryMigrationService()
              .migrateIfNeeded();
          if (!vibeResult.success) {
            throw StateError('Vibe 库迁移失败: ${vibeResult.error ?? '未知错误'}');
          }
          if (result.isSuccess) {
            completedMigration = result;
          }
          return result;
        } finally {
          migrationService.onProgress = null;
        }
      },
      initializeDatabase: () async {
        final manager = await ref.read(databaseManagerProvider.future);
        await manager.initialized;

        try {
          final stats = await manager.getCoreAssetStatistics();
          final translationCount = stats['translations'] ?? 0;
          AppLogger.i(
            '核心数据库状态: translations=$translationCount；'
                '可选共现数据包将在进入主页后初始化',
            'Warmup',
          );
          if (translationCount == 0) {
            AppLogger.w('核心翻译数据为空，请检查数据库', 'Warmup');
          }
        } catch (error, stackTrace) {
          // 资产验证属于数据库初始化契约；失败时不能把健康标记的半成品留给重试。
          try {
            await manager.dispose();
          } catch (cleanupError, cleanupStackTrace) {
            AppLogger.e(
              '数据库验证失败后的清理也失败',
              cleanupError,
              cleanupStackTrace,
              'Warmup',
            );
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
      initializeCriticalServices: () async {
        final hivePath = await HiveStorageHelper.instance.getPath();
        await Future.wait([
          _openHiveBoxIfNeeded(StorageKeys.historyBox, hivePath: hivePath),
          _openHiveBoxIfNeeded(StorageKeys.tagCacheBox, hivePath: hivePath),
          _openHiveBoxIfNeeded(StorageKeys.galleryBox, hivePath: hivePath),
          _openHiveBoxIfNeeded(
            StorageKeys.localFavoritesBox,
            hivePath: hivePath,
          ),
          _openHiveBoxIfNeeded(StorageKeys.tagsBox, hivePath: hivePath),
          _openHiveBoxIfNeeded(StorageKeys.searchIndexBox, hivePath: hivePath),
          _openHiveBoxIfNeeded(
            StorageKeys.statisticsCacheBox,
            hivePath: hivePath,
          ),
          _openHiveBoxIfNeeded(StorageKeys.collectionsBox, hivePath: hivePath),
          _openHiveBoxIfNeeded<String>(
            StorageKeys.replicationQueueBox,
            hivePath: hivePath,
          ),
          _openHiveBoxIfNeeded<String>(
            StorageKeys.queueExecutionStateBox,
            hivePath: hivePath,
          ),
          ImageMetadataService().initialize(),
          ScanStateManager.instance.initialize(),
          ShortcutStorage().init(),
        ]);
        await CollectionRepository.instance.initialize();
      },
    );
  },
);

void _configureSystemProxy(Box<dynamic> settingsBox) {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;

  final proxyEnabled =
      settingsBox.get(StorageKeys.proxyEnabled, defaultValue: true) as bool;
  if (!proxyEnabled) {
    AppLogger.d('Proxy disabled by user settings', 'NETWORK');
    return;
  }

  final proxyMode =
      settingsBox.get(StorageKeys.proxyMode, defaultValue: 'auto') as String;
  String? proxyAddress;
  if (proxyMode == 'manual') {
    final host = settingsBox.get(StorageKeys.proxyManualHost) as String?;
    final port = settingsBox.get(StorageKeys.proxyManualPort) as int?;
    if (host != null && host.isNotEmpty && port != null && port > 0) {
      proxyAddress = '$host:$port';
    }
  } else {
    proxyAddress = ProxyService.getSystemProxyAddress();
  }

  if (proxyAddress != null && proxyAddress.isNotEmpty) {
    HttpOverrides.global = SystemProxyHttpOverrides('PROXY $proxyAddress');
    AppLogger.i('Applied proxy: $proxyAddress (mode: $proxyMode)', 'NETWORK');
  } else {
    AppLogger.w(
      'Proxy enabled but no proxy address available (mode: $proxyMode)',
      'NETWORK',
    );
  }
}

Future<void> _openHiveBoxIfNeeded<E>(
  String name, {
  required String hivePath,
}) async {
  if (!Hive.isBoxOpen(name)) {
    await HiveStartupBoxOpener.openBox<E>(name, hivePath: hivePath);
  }
}
