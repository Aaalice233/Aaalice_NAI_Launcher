import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
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
      return const NAILauncherApp(key: ValueKey('main'));
    }

    // SplashScreen 需要 MaterialApp 提供基础上下文
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(key: ValueKey('splash')),
    );
  }
}

