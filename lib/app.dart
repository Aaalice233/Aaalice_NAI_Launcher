import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/tag_data_service.dart';
import 'data/services/tag_translation_service.dart';
import 'presentation/router/app_router.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/download_progress_provider.dart';
import 'presentation/themes/app_theme.dart';

class NAILauncherApp extends ConsumerStatefulWidget {
  const NAILauncherApp({super.key});

  @override
  ConsumerState<NAILauncherApp> createState() => _NAILauncherAppState();
}

class _NAILauncherAppState extends ConsumerState<NAILauncherApp> {
  @override
  void initState() {
    super.initState();
    // 预加载翻译数据（不需要 Overlay）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadTranslations();
    });
  }

  Future<void> _preloadTranslations() async {
    // 初始化 TagTranslationService（加载内置数据）
    final translationService = ref.read(tagTranslationServiceProvider);
    await translationService.load();

    // 关联 TagDataService 到 TagTranslationService
    final tagDataService = ref.read(tagDataServiceProvider);
    translationService.setTagDataService(tagDataService);
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
