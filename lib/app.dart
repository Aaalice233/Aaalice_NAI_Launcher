import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/themes/app_theme.dart';

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

      // 主题 (空字符串表示使用系统默认字体)
      theme: AppTheme.getTheme(themeType, Brightness.light,
          fontFamily: fontType.fontFamily.isEmpty ? null : fontType.fontFamily),
      darkTheme: AppTheme.getTheme(themeType, Brightness.dark,
          fontFamily: fontType.fontFamily.isEmpty ? null : fontType.fontFamily),
      themeMode: ThemeMode.dark, // 默认深色模式

      // 国际化
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 路由
      routerConfig: router,
    );
  }
}
