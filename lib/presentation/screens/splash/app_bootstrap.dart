import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../app.dart';
import '../../../core/services/interactive_work_gate.dart';
import '../../../core/services/update_check_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/first_launch_detector.dart';
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

class _AutomaticUpdateCheckState extends ConsumerState<AutomaticUpdateCheck> {
  Timer? _timer;
  bool _startupCheckCompleted = false;

  @override
  void initState() {
    super.initState();
    InteractiveWorkGate.instance.markInteraction();
    _schedule(widget.delay);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  Future<void> _run() async {
    try {
      if (!mounted) return;
      final checkRunner = widget.checkRunner;
      if (checkRunner != null) {
        await checkRunner(ref);
        return;
      }

      // 更新检查可能继续下载并校验发布资产。进入统一空闲队列，避免与
      // 云恢复、缓存维护和后台刷新同时争抢 UI isolate。
      await InteractiveWorkGate.instance.runWhenIdle(
        action: () async {
          if (!mounted) return;
          final provider = automaticUpdateCheckProvider(
            onStartup: !_startupCheckCompleted,
          );
          ref.invalidate(provider);
          await ref.read(provider.future);
          _startupCheckCompleted = true;
        },
      );
    } catch (error, stackTrace) {
      AppLogger.w('Auto update check failed: $error', 'AppBootstrap');
      AppLogger.d('$stackTrace', 'AppBootstrap');
    } finally {
      if (mounted) {
        _schedule(UpdateCheckService.failedCheckRetryInterval);
      }
    }
  }

  @override
  void dispose() {
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
