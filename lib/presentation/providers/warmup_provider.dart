import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/proxy_service.dart';
import '../../core/network/system_proxy_http_overrides.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/services/cooccurrence_service.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/services/translation_lazy_service.dart';
import '../../core/services/unified_tag_database.dart';
import '../../core/services/warmup_metrics_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_auth_api_service.dart';
import '../../data/datasources/remote/nai_user_info_api_service.dart';
import '../../data/models/settings/proxy_settings.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/tag_translation_service.dart';
import '../screens/statistics/statistics_state.dart';
import 'auth_provider.dart';
import 'data_source_cache_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'proxy_settings_provider.dart';
import 'subscription_provider.dart';
import '../../data/services/vibe_library_migration_service.dart';

part 'warmup_provider.g.dart';

/// 预加载状态
class WarmupState {
  final WarmupProgress progress;
  final bool isComplete;
  final String? error;
  /// 子任务详细消息（如"下载中... 50%"）
  final String? subTaskMessage;

  const WarmupState({
    required this.progress,
    this.isComplete = false,
    this.error,
    this.subTaskMessage,
  });

  factory WarmupState.initial() => WarmupState(
        progress: WarmupProgress.initial(),
      );

  factory WarmupState.complete() => WarmupState(
        progress: WarmupProgress.complete(),
        isComplete: true,
      );

  WarmupState copyWith({
    WarmupProgress? progress,
    bool? isComplete,
    String? error,
    String? subTaskMessage,
  }) {
    return WarmupState(
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
      subTaskMessage: subTaskMessage ?? this.subTaskMessage,
    );
  }
}

/// 预加载状态 Notifier
@riverpod
class WarmupNotifier extends _$WarmupNotifier {
  late AppWarmupService _warmupService;
  late WarmupMetricsService _metricsService;
  StreamSubscription<WarmupProgress>? _subscription;

  @override
  WarmupState build() {
    // 注册生命周期回调
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // 初始化服务并开始预加载
    _warmupService = AppWarmupService();
    _metricsService = ref.read(warmupMetricsServiceProvider);
    _registerTasks();
    _startWarmup();

    return WarmupState.initial();
  }

  /// 注册所有预加载任务
  void _registerTasks() {
    // ==== 第0步：数据迁移（串行，最先执行）====
    // 在应用启动早期执行数据迁移，确保所有数据都在正确位置
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_dataMigration',
        weight: 2,
        timeout: const Duration(seconds: 60), // 迁移最多等待60秒
        task: () async {
          AppLogger.i('开始数据迁移阶段...', 'Warmup');
          final migrationService = DataMigrationService.instance;

          // 设置进度回调
          migrationService.onProgress = (stage, progress) {
            final percentage = (progress * 100).toInt();
            state = state.copyWith(
              subTaskMessage: '$stage ($percentage%)',
            );
          };

          // 执行迁移
          final result = await migrationService.migrateAll();

          // 清除进度回调
          migrationService.onProgress = null;

          // Vibe 库 schema 迁移
          try {
            final vibeResult = await VibeLibraryMigrationService().migrateIfNeeded();
            if (vibeResult.success) {
              AppLogger.i('Vibe 库迁移完成，导出 ${vibeResult.exportedCount} 条', 'Warmup');
            } else {
              AppLogger.w('Vibe 库迁移失败: ${vibeResult.error}', 'Warmup');
            }
          } catch (e) {
            AppLogger.w('Vibe 库迁移异常: $e', 'Warmup');
          }

          state = state.copyWith(subTaskMessage: null);

          if (result.isSuccess) {
            AppLogger.i('数据迁移完成: $result', 'Warmup');
          } else {
            AppLogger.w('数据迁移部分失败: ${result.error}', 'Warmup');
            // 迁移失败不阻塞启动，继续执行
          }
        },
      ),
    );

    // ==== 第1步：网络环境检测（串行）====
    // 注意：此任务使用 Duration.zero 表示无超时，会循环等待直到网络可用
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_networkCheck',
        weight: 1,
        timeout: Duration.zero, // 无超时，一直等待
        task: () async {
          await _checkNetworkEnvironment();
        },
      ),
    );

    // ==== 第1组：基础UI服务（并行执行）====
    // 这些任务相互独立，可以并行执行
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'basicUI',
        parallel: true,
        tasks: [
          // 配置图片缓存
          WarmupTask(
            name: 'warmup_imageCache',
            weight: 1,
            task: () async {
              PaintingBinding.instance.imageCache.maximumSize = 500;
              PaintingBinding.instance.imageCache.maximumSizeBytes =
                  100 * 1024 * 1024; // 100MB
              // 触发缓存管理器初始化
              // ignore: unused_local_variable
              final cacheManager = DanbooruImageCacheManager.instance;
              AppLogger.i(
                'Image cache configured: max=500, maxBytes=100MB',
                'Warmup',
              );
            },
          ),
          // 预加载字体
          WarmupTask(
            name: 'warmup_fonts',
            weight: 1,
            task: () async {
              final fontConfig = ref.read(fontNotifierProvider);
              if (fontConfig.source == FontSource.google &&
                  fontConfig.fontFamily.isNotEmpty) {
                try {
                  await GoogleFonts.pendingFonts([
                    GoogleFonts.getFont(fontConfig.fontFamily),
                  ]);
                  AppLogger.i(
                    'Preloaded Google Font: ${fontConfig.fontFamily}',
                    'Warmup',
                  );
                } catch (e) {
                  AppLogger.w('Font preload failed: $e', 'Warmup');
                }
              } else {
                AppLogger.i('Using system font, skip preload', 'Warmup');
              }
            },
          ),
          // 预热图片编辑器
          WarmupTask(
            name: 'warmup_imageEditor',
            weight: 1,
            task: () async {
              try {
                final recorder = ui.PictureRecorder();
                final canvas = ui.Canvas(recorder);
                final paint = ui.Paint()..color = const ui.Color(0xFF000000);
                canvas.drawCircle(ui.Offset.zero, 10, paint);
                final picture = recorder.endRecording();
                final image = await picture.toImage(50, 50);
                image.dispose();
                picture.dispose();
                AppLogger.i('Image editor canvas warmed up', 'Warmup');
              } catch (e) {
                AppLogger.w('Image editor warmup failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // ==== 第2组前：初始化统一数据库（串行，阻塞后续数据服务）====
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_initUnifiedDatabase',
        weight: 2,
        timeout: const Duration(seconds: 30),
        task: () async {
          AppLogger.i('Initializing unified tag database...', 'Warmup');
          // 初始化统一数据库
          final db = ref.read(unifiedTagDatabaseProvider);
          await db.initialize();
          AppLogger.i('Unified tag database initialized', 'Warmup');
        },
      ),
    );

    // ==== 第2组：数据服务（并行执行）====
    // 注意：三个任务相互独立，可以并行执行
    // - translationService 在 Provider 中自动获取 tagDataService
    // - tagDataService 独立初始化
    // - promptConfig 独立加载
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'dataServices',
        parallel: true,
        tasks: [
          // 加载标签翻译服务
          WarmupTask(
            name: 'warmup_loadingTranslation',
            weight: 2,
            timeout: const Duration(seconds: 30),
            task: () async {
              final translationService = ref.read(tagTranslationServiceProvider);
              await translationService.load();
            },
          ),
          // 加载随机提示词配置
          WarmupTask(
            name: 'warmup_loadingPromptConfig',
            weight: 1,
            timeout: const Duration(seconds: 20),
            task: () async {
              final notifier = ref.read(promptConfigNotifierProvider.notifier);
              await notifier.whenLoaded.timeout(const Duration(seconds: 15));
            },
          ),
        ],
      ),
    );

    // ==== 第3组：网络服务（并行执行）====
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'networkServices',
        parallel: true,
        tasks: [
          // 初始化网络连接状态
          WarmupTask(
            name: 'warmup_network',
            weight: 1,
            timeout: AppWarmupService.networkTimeout,
            task: () async {
              AppLogger.i('Network service warmup started', 'Warmup');
              try {
                await Future.delayed(const Duration(milliseconds: 100))
                    .timeout(AppWarmupService.networkTimeout);
                AppLogger.i('Network service warmup completed', 'Warmup');
              } on TimeoutException {
                AppLogger.w('Network service warmup timed out', 'Warmup');
              } catch (e) {
                AppLogger.w('Network service warmup failed: $e', 'Warmup');
              }
            },
          ),
          // 初始化 Danbooru 认证状态
          WarmupTask(
            name: 'warmup_danbooruAuth',
            weight: 1,
            task: () async {
              ref.read(danbooruAuthProvider);
              AppLogger.i('Danbooru auth provider initialized', 'Warmup');
            },
          ),
          // 预加载订阅信息
          WarmupTask(
            name: 'warmup_subscription',
            weight: 2,
            timeout: const Duration(seconds: 10),
            task: () async {
              try {
                final authState = ref.read(authNotifierProvider);
                if (authState.isAuthenticated) {
                  AppLogger.i('Preloading subscription info...', 'Warmup');

                  // 首先尝试获取订阅信息
                  await ref
                      .read(subscriptionNotifierProvider.notifier)
                      .fetchSubscription()
                      .timeout(const Duration(seconds: 4));

                  // 检查是否成功
                  final subState = ref.read(subscriptionNotifierProvider);
                  if (subState.isError) {
                    // 如果失败，可能是网络问题，刷新网络服务后重试一次
                    AppLogger.w('Subscription preload failed, refreshing network and retrying...', 'Warmup');

                    // 刷新网络服务 Provider
                    ref.invalidate(dioClientProvider);
                    ref.invalidate(naiUserInfoApiServiceProvider);
                    await Future.delayed(const Duration(milliseconds: 200));

                    // 重试
                    await ref
                        .read(subscriptionNotifierProvider.notifier)
                        .fetchSubscription()
                        .timeout(const Duration(seconds: 4));
                  }

                  AppLogger.i('Subscription preloaded successfully', 'Warmup');
                } else {
                  AppLogger.i('User not authenticated, skip subscription preload', 'Warmup');
                }
              } catch (e) {
                AppLogger.w('Subscription preload failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // ==== 第4组：缓存服务（并行执行）====
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'cacheServices',
        parallel: true,
        tasks: [
          // 预初始化数据源缓存服务
          WarmupTask(
            name: 'warmup_dataSourceCache',
            weight: 1,
            timeout: const Duration(seconds: 3),
            task: () async {
              try {
                AppLogger.i('Preloading data source cache services...', 'Warmup');
                ref.read(hFTranslationCacheNotifierProvider);
                ref.read(danbooruTagsCacheNotifierProvider);
                AppLogger.i('Data source cache services preloaded', 'Warmup');
              } catch (e) {
                AppLogger.w('Data source cache preload failed: $e', 'Warmup');
              }
            },
          ),
          // 本地图库文件计数
          WarmupTask(
            name: 'warmup_galleryFileCount',
            weight: 1,
            timeout: const Duration(seconds: 3),
            task: () async {
              try {
                AppLogger.i('Counting gallery files...', 'Warmup');
                final repo = LocalGalleryRepository.instance;
                final files = await repo.getAllImageFiles();
                AppLogger.i('Gallery file count: ${files.length}', 'Warmup');
              } catch (e) {
                AppLogger.w('Gallery file count failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // ==== 串行任务：统计数据（最耗时，需要独立执行）====
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_statistics',
        weight: 3,
        timeout: const Duration(seconds: 10),
        task: () async {
          try {
            final notifier = ref.read(statisticsNotifierProvider.notifier);
            await notifier.preloadForWarmup();
          } catch (e) {
            AppLogger.w('Statistics preload failed: $e', 'Warmup');
          }
        },
      ),
    );

    // ==== 第5组：数据源懒加载初始化（并行执行）====
    // 三个数据源并行初始化，每个只加载热数据到内存
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'dataSourceInitialization',
        parallel: true,
        tasks: [
          // 共现数据懒加载初始化
          WarmupTask(
            name: 'warmup_cooccurrenceInit',
            weight: 3,
            timeout: const Duration(seconds: 180),
            task: () async {
              try {
                AppLogger.i('Initializing cooccurrence data...', 'Warmup');
                final service = ref.read(cooccurrenceServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '共现: $msg');
                  AppLogger.d(
                    'Cooccurrence init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initializeLazy();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Cooccurrence data initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Cooccurrence initialization failed: $e', 'Warmup');
              }
            },
          ),
          // 翻译数据懒加载初始化（首次使用时会下载数据）
          WarmupTask(
            name: 'warmup_translationInit',
            weight: 3,
            timeout: const Duration(seconds: 60),
            task: () async {
              try {
                AppLogger.i('Initializing translation data...', 'Warmup');
                final service = ref.read(translationLazyServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '翻译: $msg');
                  AppLogger.d(
                    'Translation init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initialize();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Translation data initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Translation initialization failed: $e', 'Warmup');
              }
            },
          ),
          // Danbooru 标签懒加载初始化（首次使用时会下载数据）
          WarmupTask(
            name: 'warmup_danbooruTagsInit',
            weight: 3,
            timeout: const Duration(seconds: 120),
            task: () async {
              try {
                AppLogger.i('Initializing Danbooru tags...', 'Warmup');
                final service = ref.read(danbooruTagsLazyServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '标签: $msg');
                  AppLogger.d(
                    'Danbooru tags init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initialize();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Danbooru tags initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Danbooru tags initialization failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // 注意：画师数据同步已从启动时移除，改为登录成功后触发
    // 这样可以确保用户有网络连接且已登录后再进行同步
    // 同步逻辑现在位于 auth_provider.dart 的登录成功回调中
  }

  /// 开始预加载
  void _startWarmup() {
    _subscription = _warmupService.run().listen(
      (progress) {
        // 保存指标数据
        if (progress.isComplete && progress.metrics != null) {
          _metricsService.saveSession(progress.metrics!).catchError((e) {
            AppLogger.e('Failed to save warmup metrics: $e', 'Warmup');
          });
        }

        state = state.copyWith(
          progress: progress,
          isComplete: progress.isComplete,
        );
      },
      onError: (error) {
        state = state.copyWith(
          error: error.toString(),
        );
      },
      onDone: () {
        if (!state.isComplete) {
          state = WarmupState.complete();
        }
      },
    );
  }

  /// 重试预加载
  void retry() {
    _subscription?.cancel();
    state = WarmupState.initial();
    _startWarmup();
  }

  /// 确保网络服务 Provider 已完全重建
  /// 
  /// 在代理配置变化后调用，通过监听 Provider 状态确保新的 DioClient 实例已创建
  /// 避免自动登录使用旧的网络配置导致连接失败
  Future<void> _ensureNetworkProvidersReady() async {
    AppLogger.i('Waiting for network providers to rebuild...', 'Warmup');

    // 方法1：通过读取 Provider 触发重建并等待完成
    // 使用 listen 获取最新的 Provider 实例，确保已重建
    // 读取 dioClientProvider 确保 DioClient 已重建
    ref.read(dioClientProvider);
    final authApiService = ref.read(naiAuthApiServiceProvider);

    // 验证 DioClient 是否使用了新的代理配置
    // 通过发送一个简单的请求来验证连接是否正常工作
    try {
      // 发送一个轻量级的请求来预热连接
      await authApiService.validateToken('').timeout(
        const Duration(seconds: 2),
        onTimeout: () => {}, // 超时也没关系，只是验证连接可用
      );
    } catch (e) {
      // 预期会失败（token为空），但连接层应该正常工作
      // 如果是连接错误，说明 Provider 还未准备好
      if (e.toString().contains('connection') ||
          e.toString().contains('SocketException')) {
        AppLogger.w('Network providers not ready yet, waiting...', 'Warmup');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    AppLogger.i('Network providers ready', 'Warmup');
  }

  /// 检查网络环境
  /// 以能否访问 NovelAI 官网为准，如果无法访问则循环等待
  /// 当检测到代理配置变化时，会刷新网络服务 Provider
  Future<void> _checkNetworkEnvironment() async {
    String? lastProxyAddress;

    while (true) {
      // 获取当前代理配置
      final proxySettings = ref.read(proxySettingsNotifierProvider);
      final currentProxyAddress = proxySettings.effectiveProxyAddress;

      // 检测代理配置是否发生变化
      if (currentProxyAddress != lastProxyAddress) {
        lastProxyAddress = currentProxyAddress;
        AppLogger.i('Proxy configuration changed to: $currentProxyAddress, refreshing network services', 'Warmup');

        // 更新全局 HttpOverrides，确保所有基于 dart:io.HttpClient 的请求都使用新代理
        if (currentProxyAddress != null && currentProxyAddress.isNotEmpty) {
          HttpOverrides.global = SystemProxyHttpOverrides('PROXY $currentProxyAddress');
          AppLogger.i('Updated HttpOverrides.global with proxy: $currentProxyAddress', 'Warmup');
        } else {
          HttpOverrides.global = null;
          AppLogger.i('Cleared HttpOverrides.global (no proxy)', 'Warmup');
        }

        // 刷新网络服务 Provider，确保使用最新的代理配置
        ref.invalidate(dioClientProvider);
        ref.invalidate(naiAuthApiServiceProvider);
        ref.invalidate(naiUserInfoApiServiceProvider);

        // 等待 Provider 重建
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 1. 首先尝试直接访问 NovelAI（无需代理）
      AppLogger.i('Testing direct connection to NovelAI...', 'Warmup');
      state = state.copyWith(
        subTaskMessage: '正在检测网络连接...',
      );

      final directResult = await ProxyService.testNovelAIConnection();

      if (directResult.success) {
        // 直接连接成功，无需代理
        AppLogger.i('Direct connection to NovelAI successful: ${directResult.latencyMs}ms', 'Warmup');
        state = state.copyWith(
          subTaskMessage: '网络连接正常 (${directResult.latencyMs}ms)',
        );
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(subTaskMessage: null);

        // 网络就绪后，如果用户未登录或正在加载，触发自动登录重试
        final authState = ref.read(authNotifierProvider);
        if (authState.status == AuthStatus.unauthenticated ||
            authState.status == AuthStatus.loading) {
          AppLogger.i('Network ready but user not authenticated (status: ${authState.status}), triggering auto-login retry', 'Warmup');

          // 确保网络服务 Provider 已完全重建后再触发自动登录
          // 避免使用旧的 DioClient 实例导致连接失败
          await _ensureNetworkProvidersReady();
          await ref.read(authNotifierProvider.notifier).retryAutoLogin();
        }
        break;
      }

      // 2. 直接连接失败，尝试使用代理
      AppLogger.w('Direct connection failed: ${directResult.errorMessage}', 'Warmup');

      // 如果代理未启用，提示用户开启VPN或启用代理
      if (!proxySettings.enabled) {
        AppLogger.w('Proxy is disabled, waiting for user to enable', 'Warmup');
        state = state.copyWith(
          subTaskMessage: '无法连接到 NovelAI，请开启VPN或启用代理设置',
        );
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      // 获取代理地址
      final proxyAddress = proxySettings.effectiveProxyAddress;

      if (proxyAddress == null || proxyAddress.isEmpty) {
        // 代理启用但没有配置
        if (proxySettings.mode == ProxyMode.auto) {
          AppLogger.w('Auto proxy mode but no system proxy detected', 'Warmup');
          state = state.copyWith(
            subTaskMessage: '已启用代理但未检测到系统代理，请开启VPN',
          );
        } else {
          AppLogger.w('Manual proxy mode but configuration incomplete', 'Warmup');
          state = state.copyWith(
            subTaskMessage: '手动代理配置不完整，请检查设置',
          );
        }
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      // 3. 测试通过代理访问 NovelAI
      AppLogger.i('Testing NovelAI connection via proxy: $proxyAddress', 'Warmup');
      state = state.copyWith(
        subTaskMessage: '正在通过代理检测网络...',
      );

      final proxyResult = await ProxyService.testNovelAIConnection(proxyAddress: proxyAddress);

      if (proxyResult.success) {
        // 代理连接成功
        AppLogger.i('NovelAI connection via proxy successful: ${proxyResult.latencyMs}ms', 'Warmup');
        state = state.copyWith(
          subTaskMessage: '网络连接正常 (${proxyResult.latencyMs}ms)',
        );
        await Future.delayed(const Duration(milliseconds: 500));
        state = state.copyWith(subTaskMessage: null);

        // 网络就绪后，如果用户未登录或正在加载，触发自动登录重试
        final authState = ref.read(authNotifierProvider);
        if (authState.status == AuthStatus.unauthenticated ||
            authState.status == AuthStatus.loading) {
          AppLogger.i('Network ready but user not authenticated (status: ${authState.status}), triggering auto-login retry', 'Warmup');

          // 确保网络服务 Provider 已完全重建后再触发自动登录
          // 避免使用旧的 DioClient 实例导致连接失败
          await _ensureNetworkProvidersReady();
          await ref.read(authNotifierProvider.notifier).retryAutoLogin();
        }
        break;
      }

      // 4. 代理也失败，显示错误并等待
      AppLogger.w('NovelAI connection via proxy failed: ${proxyResult.errorMessage}', 'Warmup');
      state = state.copyWith(
        subTaskMessage: '网络连接失败: ${proxyResult.errorMessage}，请检查VPN',
      );
      await Future.delayed(const Duration(seconds: 2));
      // 循环重试
    }
  }
}
