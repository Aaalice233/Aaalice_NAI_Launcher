import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../app.dart';
import '../../../core/services/update_check_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/first_launch_detector.dart';
import '../../../core/windowing/windows_native_window_state.dart';
import '../../providers/locale_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/warmup_provider.dart';
import '../../widgets/common/desktop_window_frame.dart';
import 'splash_screen.dart';

typedef AutomaticUpdateCheckRunner = Future<void> Function(WidgetRef ref);

/// 应用启动引导器
/// 管理预加载流程和页面切换
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({
    super.key,
    this.mainAppBuilder,
    this.onWarmupComplete,
    this.autoUpdateDelay = const Duration(seconds: 10),
    this.autoUpdateCheckRunner,
  });

  @visibleForTesting
  final WidgetBuilder? mainAppBuilder;
  final VoidCallback? onWarmupComplete;

  @visibleForTesting
  final Duration autoUpdateDelay;

  @visibleForTesting
  final AutomaticUpdateCheckRunner? autoUpdateCheckRunner;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool _showMainApp = false;
  bool _showSplashOverlay = true;
  bool _hasCheckedFirstLaunch = false;
  bool _mainAppMountScheduled = false;
  bool _warmupCompletionNotified = false;
  Widget? _mountedMainApp;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isWindows) {
      unawaited(_synchronizeWindowsViewMetrics());
    }
  }

  Future<void> _synchronizeWindowsViewMetrics() async {
    try {
      await const WindowsNativeWindowStatePlatform().synchronizeViewMetrics();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to synchronize Windows view metrics after hot reload',
        error,
        stackTrace,
        'AppBootstrap',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLogger.i(
        'Splash first frame rendered; starting warmup',
        'AppBootstrap',
      );
      ref.read(warmupNotifierProvider.notifier).start();
    });
  }

  void _scheduleMainAppMount() {
    if (_mainAppMountScheduled) return;
    _mainAppMountScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showMainApp) return;
      setState(() {
        _showMainApp = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showSplashOverlay) return;
        setState(() {
          _showSplashOverlay = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _warmupCompletionNotified) return;
          _warmupCompletionNotified = true;
          AppLogger.i('Main application first frame rendered', 'AppBootstrap');
          widget.onWarmupComplete?.call();
        });
      });
    });
  }

  Widget _buildSplash() {
    final locale = ref.watch(localeNotifierProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => DesktopWindowFrame(child: child!),
      home: const SplashScreen(key: ValueKey('splash')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warmupState = ref.watch(warmupNotifierProvider);

    if (warmupState.isComplete && !_showMainApp) {
      _scheduleMainAppMount();
    }

    if (!_showMainApp) {
      return _buildSplash();
    }

    // Cache the complete mounted subtree. Recreating this widget while merely
    // removing Splash would update and rebuild the entire router hierarchy.
    final mountedMainApp = _mountedMainApp ??= AutomaticUpdateCheck(
      delay: widget.autoUpdateDelay,
      checkRunner: widget.autoUpdateCheckRunner,
      child:
          widget.mainAppBuilder?.call(context) ??
          _MainAppWrapper(
            hasCheckedFirstLaunch: _hasCheckedFirstLaunch,
            onFirstLaunchChecked: () {
              _hasCheckedFirstLaunch = true;
            },
          ),
    );
    // Keep the root and both child identities stable while hiding Splash.
    // Removing the overlay would relayout the complete router tree; returning
    // mountedMainApp directly would additionally remount it.
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        mountedMainApp,
        Opacity(
          key: const ValueKey('splash_overlay'),
          opacity: _showSplashOverlay ? 1 : 0,
          child: TickerMode(
            enabled: _showSplashOverlay,
            child: IgnorePointer(
              ignoring: !_showSplashOverlay,
              child: ExcludeSemantics(
                excluding: !_showSplashOverlay,
                child: _buildSplash(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 主应用显示后常驻执行自动更新检测。
///
/// 该职责位于 [AppBootstrap] 层，而不是具体主应用构建器内，因此测试、
/// 替代入口和生产入口都不会绕过自动检测。
@visibleForTesting
class AutomaticUpdateCheck extends ConsumerStatefulWidget {
  const AutomaticUpdateCheck({
    super.key,
    required this.child,
    this.delay = const Duration(seconds: 10),
    this.checkRunner,
  });

  final Widget child;
  final Duration delay;

  @visibleForTesting
  final AutomaticUpdateCheckRunner? checkRunner;

  @override
  ConsumerState<AutomaticUpdateCheck> createState() =>
      _AutomaticUpdateCheckState();
}

class _AutomaticUpdateCheckState extends ConsumerState<AutomaticUpdateCheck>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _startupCheckCompleted = false;
  bool _running = false;

  bool get _isForeground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule(widget.delay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule(widget.delay);
    } else {
      _timer?.cancel();
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    if (!mounted || !_isForeground || _running) return;
    _running = true;
    try {
      final checkRunner = widget.checkRunner;
      if (checkRunner != null) {
        await checkRunner(ref);
        return;
      }

      // 检测只读取发布元数据；不能等待交互/动画完全停止，否则持续使用
      // 应用时可能一直没有更新提示。安装包仍由用户显式触发下载。
      final provider = automaticUpdateCheckProvider(
        onStartup: !_startupCheckCompleted,
      );
      ref.invalidate(provider);
      await ref.read(provider.future);
      _startupCheckCompleted = true;
    } catch (error, stackTrace) {
      AppLogger.w('Auto update check failed: $error', 'AppBootstrap');
      AppLogger.d('$stackTrace', 'AppBootstrap');
    } finally {
      _running = false;
      if (mounted && _isForeground) {
        _schedule(UpdateCheckService.failedCheckRetryInterval);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 主应用包装器，用于在应用启动后触发首次启动检测
class _MainAppWrapper extends ConsumerStatefulWidget {
  final bool hasCheckedFirstLaunch;
  final VoidCallback onFirstLaunchChecked;

  const _MainAppWrapper({
    required this.hasCheckedFirstLaunch,
    required this.onFirstLaunchChecked,
  });

  @override
  ConsumerState<_MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends ConsumerState<_MainAppWrapper> {
  @override
  void initState() {
    super.initState();

    // 在应用启动后检查首次启动
    if (!widget.hasCheckedFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFirstLaunch();
      });
    }
  }

  Future<void> _checkFirstLaunch() async {
    if (!mounted) return;

    widget.onFirstLaunchChecked();

    // 执行首次启动检测和同步
    await ref.read(firstLaunchNotifierProvider.notifier).checkAndSync(context);
  }

  @override
  Widget build(BuildContext context) {
    return const NAILauncherApp(key: ValueKey('main'));
  }
}
