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
import 'splash_screen.dart';

/// 应用启动引导器
/// 管理预加载流程和页面切换
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  bool _showMainApp = false;
  bool _hasCheckedFirstLaunch = false;

  @override
  Widget build(BuildContext context) {
    final warmupState = ref.watch(warmupNotifierProvider);

    // 预加载完成后显示主应用
    if (warmupState.isComplete && !_showMainApp) {
      // 延迟一帧后切换，确保动画流畅
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showMainApp = true;
          });
        }
      });
    }

    // 如果显示主应用，直接返回（NAILauncherApp 自带 MaterialApp）
    if (_showMainApp) {
      return _MainAppWrapper(
        hasCheckedFirstLaunch: _hasCheckedFirstLaunch,
        onFirstLaunchChecked: () {
          _hasCheckedFirstLaunch = true;
        },
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
      home: const SplashScreen(key: ValueKey('splash')),
    );
  }
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
  Timer? _autoUpdateTimer;
  @override
  void initState() {
    super.initState();

    // 在应用启动后检查首次启动
    if (!widget.hasCheckedFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkFirstLaunch();
      });
    }

    // 延迟3秒后执行自动更新检查（不阻塞启动）
    _scheduleAutoUpdateCheck();
  }

  /// 调度自动更新检查。
  ///
  /// 这里只更新全局状态；主界面中的持久提示负责展示，避免从
  /// `MaterialApp.router` 外层 context 弹窗导致提示静默失败。
  void _scheduleAutoUpdateCheck({Duration delay = const Duration(seconds: 3)}) {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer(delay, _runAutoUpdateCheck);
  }

  Future<void> _runAutoUpdateCheck() async {
    try {
      if (!mounted) return;
      await ref.read(updateCheckServiceReadyProvider.future);
      if (!mounted) return;
      final notifier = ref.read(updateStateProvider.notifier);
      await notifier.initialize();
      final updateState = ref.read(updateStateProvider);
      if (!mounted ||
          updateState.hasDownloadedUpdate ||
          updateState.hasNewVersion) {
        return;
      }

      final shouldCheck = await ref.read(checkUpdateOnStartupProvider.future);
      if (!shouldCheck || !mounted) return;
      await notifier.checkForUpdates();
    } catch (error, stackTrace) {
      AppLogger.w('Auto update check failed: $error', 'AppBootstrap');
      AppLogger.d('$stackTrace', 'AppBootstrap');
    } finally {
      if (mounted) {
        _scheduleAutoUpdateCheck(
          delay: UpdateCheckService.failedCheckRetryInterval,
        );
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    if (!mounted) return;

    widget.onFirstLaunchChecked();

    // 执行首次启动检测和同步
    await ref.read(firstLaunchNotifierProvider.notifier).checkAndSync(context);
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const NAILauncherApp(key: ValueKey('main'));
  }
}
