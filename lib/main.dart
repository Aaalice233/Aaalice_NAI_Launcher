import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'core/constants/storage_keys.dart';
import 'core/utils/app_logger.dart';
import 'data/datasources/local/nai_tags_data_source.dart';
import 'presentation/screens/splash/app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  await AppLogger.init();

  // 初始化 Hive
  await Hive.initFlutter();

  // 预先打开 Hive boxes (确保 LocalStorageService 可用)
  await Hive.openBox(StorageKeys.settingsBox);
  await Hive.openBox(StorageKeys.historyBox);
  await Hive.openBox(StorageKeys.tagCacheBox);
  await Hive.openBox(StorageKeys.galleryBox);

  // 后台预加载 NAI 标签数据（不阻塞启动）
  final container = ProviderContainer();
  Future.microtask(() async {
    try {
      await container.read(naiTagsDataSourceProvider).loadData();
      AppLogger.d('NAI tags preloaded successfully', 'Main');
    } catch (e) {
      AppLogger.w('NAI tags preload failed: $e', 'Main');
      // 预加载失败不影响应用启动
    }
  });

  // 桌面端窗口配置
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1400, 900),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'NAI Launcher',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppBootstrap(),
    ),
  );
}
