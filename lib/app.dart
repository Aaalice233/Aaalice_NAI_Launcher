import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/storage/backup_service.dart';
import 'core/utils/app_logger.dart';
import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/backup_settings_provider.dart';
import 'presentation/themes/app_theme.dart';

/// NAI Launcher 主应用
/// 预加载已在 SplashScreen 完成
class NAILauncherApp extends ConsumerStatefulWidget {
  const NAILauncherApp({super.key});

  @override
  ConsumerState<NAILauncherApp> createState() => _NAILauncherAppState();
}

class _NAILauncherAppState extends ConsumerState<NAILauncherApp>
    with WidgetsBindingObserver {
  Timer? _backupCheckTimer;
  DateTime? _lastBackupCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 延迟初始化自动备份调度器，确保应用已完全加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBackupScheduler();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backupCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用从后台恢复时检查是否需要备份
    if (state == AppLifecycleState.resumed) {
      _checkAndTriggerBackup();
    }
  }

  /// 初始化自动备份调度器
  void _initializeBackupScheduler() {
    final backupSettings = ref.read(backupSettingsNotifierProvider);

    if (!backupSettings.autoBackupEnabled) {
      return;
    }

    // 初始检查
    _checkAndTriggerBackup();

    // 设置定时检查（每30分钟检查一次）
    _backupCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndTriggerBackup(),
    );

    AppLogger.i(
      'Auto-backup scheduler initialized (interval: ${backupSettings.backupIntervalHours}h)',
      'NAILauncherApp',
    );
  }

  /// 检查并触发自动备份
  Future<void> _checkAndTriggerBackup() async {
    // 防止重复检查（5分钟内只检查一次）
    if (_lastBackupCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastBackupCheck!);
      if (timeSinceLastCheck < const Duration(minutes: 5)) {
        return;
      }
    }

    _lastBackupCheck = DateTime.now();

    try {
      final backupService = ref.read(backupServiceProvider);
      final shouldBackup = await backupService.shouldAutoBackup();

      if (shouldBackup) {
        AppLogger.i('Triggering auto-backup...', 'NAILauncherApp');
        final result = await backupService.createAutoBackup();

        if (result.success) {
          AppLogger.i(
            'Auto-backup completed: ${result.filePath}',
            'NAILauncherApp',
          );
        } else {
          AppLogger.w(
            'Auto-backup failed: ${result.error}',
            'NAILauncherApp',
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error during auto-backup check', e, stackTrace, 'NAILauncherApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeNotifierProvider);
    final fontType = ref.watch(fontNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NAI Launcher',
      debugShowCheckedModeBanner: false,

      // 主题 (空字符串表示使用系统默认字体)
      theme: AppTheme.getTheme(
        themeType,
        Brightness.light,
        fontFamily: fontType.fontFamily.isEmpty ? null : fontType.fontFamily,
      ),
      darkTheme: AppTheme.getTheme(
        themeType,
        Brightness.dark,
        fontFamily: fontType.fontFamily.isEmpty ? null : fontType.fontFamily,
      ),
      themeMode: ThemeMode.dark, // 默认深色模式

      // 国际化
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // 路由
      routerConfig: router,
    );
  }
}
