import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'core/autocomplete/cooccurrence_data_pack_provider.dart';
import 'core/cache/gallery_cache_manager.dart';
import 'core/utils/app_logger.dart';
import 'core/platform/platform_capabilities.dart';
import 'core/services/desktop_app_shutdown_service.dart';
import 'core/shortcuts/default_shortcuts.dart';
import 'presentation/adaptive/window_size_class.dart';
import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/font_scale_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/background_refresh_provider.dart';
import 'presentation/providers/krita/krita_bridge_notifier.dart';
import 'presentation/providers/image_generation_provider.dart';
import 'presentation/providers/queue_execution_provider.dart';
import 'presentation/providers/subscription_provider.dart'
    hide anlasBalanceProvider;
import 'presentation/themes/app_theme.dart';
import 'presentation/widgets/shortcuts/shortcut_aware_widget.dart';
import 'presentation/widgets/shortcuts/shortcut_help_dialog.dart';

/// 全局副作用挂载层
///
/// 只负责启动需要常驻的 provider 监听，不让它们把根部 MaterialApp 一起拖着重建。
class AppBootstrapEffects extends ConsumerStatefulWidget {
  final Widget child;
  final ProviderListenable<dynamic>? anlasWatcher;
  final ProviderListenable<dynamic>? backgroundRefresh;
  final ProviderListenable<dynamic>? kritaBridge;
  final ProviderListenable<dynamic>? cooccurrenceDataPack;

  const AppBootstrapEffects({
    super.key,
    required this.child,
    this.anlasWatcher,
    this.backgroundRefresh,
    this.kritaBridge,
    this.cooccurrenceDataPack,
  });

  @override
  ConsumerState<AppBootstrapEffects> createState() =>
      _AppBootstrapEffectsState();
}

class _AppBootstrapEffectsState extends ConsumerState<AppBootstrapEffects>
    with WidgetsBindingObserver {
  ProviderSubscription<dynamic>? _anlasWatcherSubscription;
  ProviderSubscription<dynamic>? _backgroundRefreshSubscription;
  ProviderSubscription<dynamic>? _kritaBridgeSubscription;
  ProviderSubscription<dynamic>? _cooccurrenceDataPackSubscription;
  bool _queuePausedForBackground = false;

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
      _backgroundRefreshSubscription = ref.listenManual(
        widget.backgroundRefresh ?? backgroundRefreshNotifierProvider,
        (_, __) {},
      );
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
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    ref
        .read(subscriptionNotifierProvider.notifier)
        .setAppForeground(isForeground);

    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeQueueAfterBackground());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_persistAndPauseForBackground());
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
    _backgroundRefreshSubscription?.close();
    _kritaBridgeSubscription?.close();
    _cooccurrenceDataPackSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        final isVisible = ref.read(queueManagementVisibleProvider);
        ref.read(queueManagementVisibleProvider.notifier).state = !isVisible;
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
                child: LargestDisplayFeatureSubScreen(child: child!),
              ),
            );
          },
        ),
      ),
    );
  }
}
