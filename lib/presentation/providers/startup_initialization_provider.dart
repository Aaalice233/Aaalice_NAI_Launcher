import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/database/database_providers.dart';
import '../../core/services/avatar_image_cache.dart';
import '../../core/network/proxy_service.dart';
import '../../core/network/system_proxy_http_overrides.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/shortcuts/shortcut_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/hive_startup_box_opener.dart';
import '../../core/utils/hive_storage_helper.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/datasources/local/random_tag_library_data_source.dart';
import '../../data/datasources/local/tag_group_cache_service.dart';
import '../../data/repositories/collection_repository.dart';
import '../../data/services/gallery/gallery_album_import_coordinator.dart';
import '../../data/services/gallery/scan_state_manager.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/vibe_library_migration_service.dart';
import '../../data/services/wordlist_service.dart';
import 'account_manager_provider.dart';
import 'auth_provider.dart';
import 'character_prompt_provider.dart';
import 'fixed_tags_provider.dart';
import 'gallery_album_provider.dart';
import 'gallery_category_provider.dart';
import 'image_generation_provider.dart';
import 'layout_state_provider.dart';
import 'local_gallery_provider.dart';
import 'online_gallery_provider.dart';
import 'precise_ref_library_provider.dart';
import 'random_preset_provider.dart';
import 'tag_library_page_provider.dart';
import 'tag_library_provider.dart';
import 'vibe_library_provider.dart';
import '../agent_chat/providers/agent_chat_notifier.dart';
import '../screens/statistics/statistics_state.dart';

/// 可替换的启动关键任务边界，便于验证 Splash 与真实初始化的时序。
class StartupInitializationTasks {
  const StartupInitializationTasks({
    required this.initializeRuntimeConfiguration,
    required this.runDataMigration,
    required this.initializeDatabase,
    required this.initializeCriticalServices,
    required this.initializeMainShellData,
    required this.runDeferredDataMaintenance,
  });

  final Future<void> Function() initializeRuntimeConfiguration;
  final Future<MigrationResult> Function(
    void Function(String stage, double progress) onProgress,
  )
  runDataMigration;
  final Future<void> Function() initializeDatabase;
  final Future<void> Function() initializeCriticalServices;
  final Future<void> Function() initializeMainShellData;
  final Future<void> Function() runDeferredDataMaintenance;
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
          final platform = PlatformCapabilities.operatingSystem;
          VideoPlayerMediaKit.ensureInitialized(
            windows: platform.isWindows,
            macOS: platform.isMacOS,
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
      initializeMainShellData: () async {
        // 这些数据直接决定主页首帧和左侧导航首次点击的内容，必须在
        // Splash 期间真实加载完成，而不是在主页上方做事件循环探测。
        final accountManager = ref.read(
          accountManagerNotifierProvider.notifier,
        );
        final accountLoad = accountManager.whenLoaded;
        final localGalleryInitialization = ref
            .read(localGalleryNotifierProvider.notifier)
            .initialize();
        final categoryInitialization = ref
            .read(galleryCategoryNotifierProvider.notifier)
            .whenLoaded();
        final albumInitialization = ref
            .read(galleryAlbumNotifierProvider.notifier)
            .whenLoaded();
        final vibeInitialization = ref
            .read(vibeLibraryNotifierProvider.notifier)
            .initialize();
        final preciseRefInitialization = ref
            .read(preciseRefLibraryNotifierProvider.notifier)
            .initialize();
        final layoutState = ref.read(layoutStateNotifierProvider);
        final rightPanelTab = ref
            .read(localStorageServiceProvider)
            .getSetting<int>(StorageKeys.rightPanelTab);
        final agentChatInitialization =
            layoutState.rightPanelExpanded &&
                (rightPanelTab == null || rightPanelTab == 0)
            ? ref.read(agentChatNotifierProvider.notifier).ensureInitialized()
            : Future<void>.value();
        final statisticsInitialization = ref
            .read(statisticsNotifierProvider.notifier)
            .preloadForWarmup();
        final generationStateRestore = ref
            .read(generationParamsNotifierProvider.notifier)
            .restoreGenerationState();
        final generationHistoryRestore = ref
            .read(imageGenerationNotifierProvider.notifier)
            .ensureGenerationHistoryRestored();
        final randomPresetLoad = ref
            .read(randomPresetNotifierProvider.notifier)
            .whenLoaded;
        final tagLibraryLoad = ref
            .read(tagLibraryNotifierProvider.notifier)
            .whenLoaded;
        final officialWordlists = ref.read(officialWordlistDataProvider.future);
        final randomTagLibrary = ref.read(randomTagLibraryDataProvider.future);
        final tagGroupCache = ref.read(tagGroupCacheServiceProvider).init();

        // 这些包含同步本地解码；提前创建可避免首次切页时集中占用 UI isolate。
        ref.read(fixedTagsNotifierProvider);
        ref.read(tagLibraryPageNotifierProvider);
        ref.read(characterPromptNotifierProvider);
        ref.read(onlineGalleryNotifierProvider);

        await accountLoad;
        final avatarPreload = AvatarImageCache.instance.preload(
          ref
              .read(accountManagerNotifierProvider)
              .accounts
              .map((account) => account.avatarPath)
              .whereType<String>()
              .where((path) => path.isNotEmpty),
        );
        final authInitialization = ref
            .read(authNotifierProvider.notifier)
            .whenInitialized;

        await Future.wait([
          localGalleryInitialization,
          categoryInitialization,
          albumInitialization,
          vibeInitialization,
          preciseRefInitialization,
          agentChatInitialization,
          statisticsInitialization,
          generationStateRestore,
          generationHistoryRestore,
          randomPresetLoad,
          tagLibraryLoad,
          officialWordlists,
          randomTagLibrary,
          tagGroupCache,
          avatarPreload,
          authInitialization,
        ]);
      },
      runDeferredDataMaintenance: () async {
        // 索引未就绪的成员路径会进入 pending，由扫描协调器后续补绑。
        await GalleryAlbumImportCoordinator(
          dataSource: GalleryDataSource(),
          localStorage: LocalStorageService(),
        ).importIfNeeded();
      },
    );
  },
);

void _configureSystemProxy(Box<dynamic> settingsBox) {
  if (!PlatformCapabilities.operatingSystem.isDesktop) return;

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
