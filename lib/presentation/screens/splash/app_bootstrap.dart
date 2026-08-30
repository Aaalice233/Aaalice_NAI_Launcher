import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../app.dart';
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
    this.autoUpdateDelay = const Duration(seconds: 3),
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
  bool _hasCheckedFirstLaunch = false;
  bool _warmupCompletionNotified = false;

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

  @override
  Widget build(BuildContext context) {
    final warmupState = ref.watch(warmupNotifierProvider);

    // 预加载完成后显示主应用
    if (warmupState.isComplete && !_showMainApp) {
      // 延迟一帧后切换，确保动画流畅
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showMainApp) return;
        setState(() {
          _showMainApp = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _warmupCompletionNotified) return;
          _warmupCompletionNotified = true;
          ref.read(warmupNotifierProvider.notifier).startPostWarmupTasks();
          widget.onWarmupComplete?.call();
        });
      });
    }

    // 如果显示主应用，直接返回（NAILauncherApp 自带 MaterialApp）
    if (_showMainApp) {
      final mainAppBuilder = widget.mainAppBuilder;
      final mainApp = mainAppBuilder != null
          ? mainAppBuilder(context)
          : _MainAppWrapper(
              hasCheckedFirstLaunch: _hasCheckedFirstLaunch,
              onFirstLaunchChecked: () {
                _hasCheckedFirstLaunch = true;
              },
            );
      return AutomaticUpdateCheck(
        delay: widget.autoUpdateDelay,
        checkRunner: widget.autoUpdateCheckRunner,
        child: mainApp,
      );
    }

    // SplashScreen 需要 MaterialApp 提供基础上下文
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
    this.delay = const Duration(seconds: 3),
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
