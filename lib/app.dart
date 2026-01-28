import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/themes/app_theme.dart';

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

    return MaterialApp.router(
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
    );
  }
}
