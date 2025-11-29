import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'core/constants/storage_keys.dart';
import 'presentation/screens/splash/app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();

  // 预先打开 Hive boxes (确保 LocalStorageService 可用)
  await Hive.openBox(StorageKeys.settingsBox);
  await Hive.openBox(StorageKeys.historyBox);
  await Hive.openBox(StorageKeys.tagCacheBox);
  await Hive.openBox(StorageKeys.galleryBox);

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
    const ProviderScope(
      child: AppBootstrap(),
    ),
  );
}
