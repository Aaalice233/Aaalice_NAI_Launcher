import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'core/shortcuts/default_shortcuts.dart';
import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/queue_execution_provider.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/widgets/shortcuts/shortcut_aware_widget.dart';
import 'presentation/widgets/shortcuts/shortcut_help_dialog.dart';

/// NAI Launcher 主应用
/// 预加载已在 SplashScreen 完成
class NAILauncherApp extends ConsumerWidget {
  const NAILauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeNotifierProvider);
    final fontType = ref.watch(fontNotifierProvider);
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
      ShortcutIds.minimizeToTray: () {
        windowManager.hide();
      },
      ShortcutIds.quitApp: () {
        windowManager.close();
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

    return GlobalShortcuts(
      shortcuts: globalShortcuts,
      child: MaterialApp.router(
        title: 'NAI Launcher',
        debugShowCheckedModeBanner: false,

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
      ),
    );
  }
}
