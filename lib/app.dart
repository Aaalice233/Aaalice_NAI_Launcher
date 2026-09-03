import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'core/autocomplete/cooccurrence_data_pack_provider.dart';
import 'core/cache/gallery_cache_manager.dart';
import 'core/cache/local_gallery_thumbnail_provider.dart';
import 'core/utils/app_logger.dart';
import 'core/platform/platform_capabilities.dart';
import 'core/services/desktop_app_shutdown_service.dart';
import 'core/services/interactive_work_gate.dart';
import 'core/shortcuts/default_shortcuts.dart';
import 'presentation/adaptive/interaction_policy.dart';
import 'presentation/adaptive/window_size_class.dart';
import 'presentation/router/app_router_config.dart';
import 'presentation/router/app_routes.dart';
import 'presentation/router/shell_panels_overlay.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/font_scale_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/cloud_sync/cloud_sync_provider_wiring.dart';
import 'presentation/providers/krita/krita_bridge_notifier.dart';
import 'presentation/providers/image_generation_provider.dart';
import 'presentation/providers/queue_execution_provider.dart';
import 'presentation/providers/subscription_provider.dart'
    hide anlasBalanceProvider;
import 'presentation/themes/app_theme.dart';
import 'presentation/widgets/common/desktop_window_frame.dart';
import 'presentation/widgets/shortcuts/shortcut_aware_widget.dart';
import 'presentation/widgets/shortcuts/shortcut_help_dialog.dart';

/// 全局副作用挂载层
///
/// 只负责启动需要常驻的 provider 监听，不让它们把根部 MaterialApp 一起拖着重建。
class AppBootstrapEffects extends ConsumerStatefulWidget {
  final Widget child;
  final ProviderListenable<dynamic>? anlasWatcher;
  final ProviderListenable<dynamic>? kritaBridge;
  final ProviderListenable<dynamic>? cooccurrenceDataPack;
  final Future<void> Function()? cloudSyncLifecycle;

  const AppBootstrapEffects({
    super.key,
    required this.child,
    this.anlasWatcher,
    this.kritaBridge,
    this.cooccurrenceDataPack,
    this.cloudSyncLifecycle,
  });

  @override
  ConsumerState<AppBootstrapEffects> createState() =>
      _AppBootstrapEffectsState();
}

class _AppBootstrapEffectsState extends ConsumerState<AppBootstrapEffects>
    with WidgetsBindingObserver {
  ProviderSubscription<dynamic>? _anlasWatcherSubscription;
  ProviderSubscription<dynamic>? _kritaBridgeSubscription;
  ProviderSubscription<dynamic>? _cooccurrenceDataPackSubscription;
  bool _queuePausedForBackground = false;
  bool _cloudSyncLifecycleRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _anlasWatcherSubscription = ref.listenManual(
        widget.anlasWatcher ?? anlasBalanceWatcherProvider,
        (_, __) {},
      );
      final usesTestOverrides =
          widget.kritaBridge != null || widget.cooccurrenceDataPack != null;
      if (usesTestOverrides) {
        _mountInjectedEffects();
      } else {
        unawaited(_mountProductionIdleEffects());
      }
      unawaited(
        _restoreCloudBackupConnection(
          minimumDelay: const Duration(seconds: 10),
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    ref
        .read(subscriptionNotifierProvider.notifier)
        .setAppForeground(isForeground);
    LocalGalleryThumbnailProvider.setAppForeground(isForeground);

    if (state == AppLifecycleState.resumed) {
      InteractiveWorkGate.instance.markInteraction();
      unawaited(_resumeQueueAfterBackground());
      unawaited(_restoreCloudBackupConnection());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_persistAndPauseForBackground());
    }
  }

  void _mountInjectedEffects() {
    if (widget.kritaBridge != null ||
        PlatformCapabilities.current.supportsKritaBridge) {
      _kritaBridgeSubscription = ref.listenManual(
        widget.kritaBridge ?? kritaBridgeNotifierProvider,
        (_, __) {},
      );
    }
    _cooccurrenceDataPackSubscription = ref.listenManual(
      widget.cooccurrenceDataPack ?? cooccurrenceDataPackStartupProvider,
      (_, __) {},
    );
  }

  Future<void> _mountProductionIdleEffects() async {
    await _runProductionIdleEffect(
      'Krita bridge',
      minimumDelay: const Duration(seconds: 10),
      action: () async {
        if (!mounted || !PlatformCapabilities.current.supportsKritaBridge) {
          return;
        }
        _kritaBridgeSubscription = ref.listenManual(
          kritaBridgeNotifierProvider,
          (_, __) {},
        );
      },
    );
    await _runProductionIdleEffect(
      'co-occurrence data pack',
      action: () async {
        if (!mounted) return;
        _cooccurrenceDataPackSubscription = ref.listenManual(
          cooccurrenceDataPackStartupProvider,
          (_, __) {},
        );
        await ref.read(cooccurrenceDataPackStartupProvider.future);
      },
    );
  }

  Future<void> _runProductionIdleEffect(
    String name, {
    Duration minimumDelay = Duration.zero,
    required Future<void> Function() action,
  }) async {
    try {
      await InteractiveWorkGate.instance.runWhenIdle(
        minimumDelay: minimumDelay,
        priority: InteractiveWorkPriority.maintenance,
        action: action,
      );
    } catch (error, stackTrace) {
      AppLogger.e('$name initialization failed', error, stackTrace, 'Startup');
    }
  }

  Future<void> _persistAndPauseForBackground() async {
    final queueState = ref.read(queueExecutionNotifierProvider);
    if (!_queuePausedForBackground &&
        (queueState.isRunning || queueState.isReady)) {
      _queuePausedForBackground = true;
      await ref.read(queueExecutionNotifierProvider.notifier).pause();
    }

    await ref
        .read(generationParamsNotifierProvider.notifier)
        .saveGenerationState();
    if (ref.exists(imageGenerationNotifierProvider)) {
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .flushGenerationHistory();
    }
  }

  Future<void> _resumeQueueAfterBackground() async {
    if (!_queuePausedForBackground) return;
    _queuePausedForBackground = false;
    await ref.read(queueExecutionNotifierProvider.notifier).resume();
  }

  Future<void> _restoreCloudBackupConnection({
    Duration minimumDelay = Duration.zero,
  }) async {
    if (_cloudSyncLifecycleRunning) return;
    _cloudSyncLifecycleRunning = true;
    try {
      final override = widget.cloudSyncLifecycle;
      if (override != null) {
        await override();
        return;
      }

      await InteractiveWorkGate.instance.runWhenIdle(
        minimumDelay: minimumDelay,
        action: () async {
          if (!mounted) return;
          await ref
              .read(cloudSyncApplicationServiceProvider)
              .restorePersisted();
        },
      );
    } catch (error) {
      AppLogger.w(
        'Cloud backup connection restore failed: $error',
        'CloudSync',
      );
    } finally {
      _cloudSyncLifecycleRunning = false;
    }
  }

  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    unawaited(
      GalleryCacheManager().clearL1MemoryCache().catchError((Object error) {
        AppLogger.w(
          'Failed to release gallery memory after system pressure: $error',
          'AppLifecycle',
        );
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anlasWatcherSubscription?.close();
    _kritaBridgeSubscription?.close();
    _cooccurrenceDataPackSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      InteractiveActivityObserver(child: widget.child);
}

/// NAI Launcher 主应用
/// 预加载已在 SplashScreen 完成
class NAILauncherApp extends ConsumerWidget {
  const NAILauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeNotifierProvider);
    final fontType = ref.watch(fontNotifierProvider);
    final fontScale = ref.watch(fontScaleNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);
    final router = ref.watch(appRouterProvider);

    // 定义全局快捷键映射
    final globalShortcuts = <String, VoidCallback>{
      // 页面导航快捷键
      ShortcutIds.navigateToGeneration: () {
        router.go(AppRoutes.generation);
      },
      ShortcutIds.navigateToLocalGallery: () {
        router.go(AppRoutes.localGallery);
      },
      ShortcutIds.navigateToOnlineGallery: () {
        router.go(AppRoutes.onlineGallery);
      },
      ShortcutIds.navigateToRandomConfig: () {
        router.go(AppRoutes.promptConfig);
      },
      ShortcutIds.navigateToTagLibrary: () {
        router.go(AppRoutes.tagLibraryPage);
      },
      ShortcutIds.navigateToStatistics: () {
        router.go(AppRoutes.statistics);
      },
      ShortcutIds.navigateToSettings: () {
        router.go(AppRoutes.settings);
      },
      ShortcutIds.navigateToVibeLibrary: () {
        router.go(AppRoutes.vibeLibrary);
      },

      // 全局应用快捷键
      ShortcutIds.showShortcutHelp: () {
        ShortcutHelpDialog.show(context);
      },
      if (PlatformCapabilities.current.supportsDesktopWindowControls) ...{
        ShortcutIds.minimizeToTray: () {
          windowManager.hide();
        },
        ShortcutIds.quitApp: () {
          unawaited(DesktopAppShutdownService.shutdownAndExit(0));
        },
      },
      ShortcutIds.toggleQueue: () {
        final activePanel = ref.read(shellPanelProvider);
        ref.read(shellPanelProvider.notifier).state =
            activePanel == ShellPanel.queue ? null : ShellPanel.queue;
      },
      ShortcutIds.toggleQueuePause: () {
        final executionState = ref.read(queueExecutionNotifierProvider);
        if (executionState.isPaused) {
          ref.read(queueExecutionNotifierProvider.notifier).resume();
        } else if (executionState.isRunning || executionState.isReady) {
          ref.read(queueExecutionNotifierProvider.notifier).pause();
        }
      },
      ShortcutIds.toggleTheme: () {
        ref.read(themeNotifierProvider.notifier).nextTheme();
      },
    };

    return AppBootstrapEffects(
      child: GlobalShortcuts(
        shortcuts: globalShortcuts,
        child: MaterialApp.router(
          title: 'NAI Launcher',
          debugShowCheckedModeBanner: false,
          restorationScopeId: 'nai_launcher',

          // 主题 (fontFamily 为空时使用主题原生字体)
          theme: AppTheme.getTheme(
            themeType,
            Brightness.light,
            fontConfig: fontType.fontFamily.isEmpty ? null : fontType,
          ),
          darkTheme: AppTheme.getTheme(
            themeType,
            Brightness.dark,
            fontConfig: fontType.fontFamily.isEmpty ? null : fontType,
          ),
          themeMode: ThemeMode.dark, // 默认深色模式
          // 国际化
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

          // 路由
          routerConfig: router,

          // 字体缩放全局应用
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final platformScale = mediaQuery.textScaler.scale(16) / 16;
            final effectiveScale = (platformScale * fontScale)
                .clamp(0.8, 3.0)
                .toDouble();
            final brightness = Theme.of(context).brightness;
            final iconBrightness = brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: iconBrightness,
                statusBarBrightness: brightness,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: iconBrightness,
                systemNavigationBarContrastEnforced: false,
              ),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(effectiveScale),
                ),
                child: InteractionPolicyScope(
                  initialPolicy: PlatformCapabilities.current.isMobile
                      ? InteractionPolicy.touchFirst
                      : InteractionPolicy.neutral,
                  child: DesktopWindowFrame(
                    child: LargestDisplayFeatureSubScreen(child: child!),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
