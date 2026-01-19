import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/localization_extension.dart';
import '../providers/auth_provider.dart' show authNotifierProvider, AuthStatus;
import '../providers/download_progress_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/generation/generation_screen.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/local_gallery/local_gallery_screen.dart';
import '../screens/online_gallery/online_gallery_screen.dart';
import '../screens/prompt_config/prompt_config_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/navigation/main_nav_rail.dart';

part 'app_router.g.dart';

/// 路由路径常量
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String home = '/';
  static const String generation = '/generation';
  static const String gallery = '/gallery';
  static const String localGallery = '/local-gallery';
  static const String onlineGallery = '/online-gallery';
  static const String settings = '/settings';
  static const String promptConfig = '/prompt-config';
}

/// 应用路由 Provider
///
/// 注意：使用 refreshListenable 而非 ref.watch 来监听认证状态，
/// 这样可以保持 GoRouter 实例稳定，避免每次状态变化都重建 Navigator 和 Overlay。
@riverpod
GoRouter appRouter(Ref ref) {
  // 使用 ValueNotifier 桥接 Riverpod 到 GoRouter 的 refreshListenable
  final authStateNotifier = ValueNotifier<bool>(false);

  // 监听认证状态变化，触发 GoRouter 刷新（但不会重建 GoRouter 实例）
  ref.listen(authNotifierProvider, (_, __) {
    authStateNotifier.value = !authStateNotifier.value;
  });

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,

    // 使用 refreshListenable 监听状态变化，触发 redirect 重新评估
    refreshListenable: authStateNotifier,

    // 重定向逻辑
    redirect: (context, state) {
      // 在 redirect 内部使用 ref.read 获取最新状态
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState.status == AuthStatus.loading || 
                        authState.status == AuthStatus.initial;
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // 正在加载中（检查自动登录），不重定向，等待认证状态确定
      if (isLoading) {
        return null;
      }

      // 未登录且不在登录页，重定向到登录页
      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      // 已登录且在登录页，重定向到首页
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home;
      }

      return null;
    },

    // 路由配置
    routes: [
      // 登录页
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => LoginScreen(),
      ),

      // 主页 Shell - 带底部导航的布局
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          // 生成页 (首页)
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const GenerationScreen(),
          ),
          GoRoute(
            path: AppRoutes.generation,
            name: 'generation',
            builder: (context, state) => const GenerationScreen(),
          ),

          // 图库页（本地生成历史）
          GoRoute(
            path: AppRoutes.gallery,
            name: 'gallery',
            builder: (context, state) => const GalleryScreen(),
          ),

          // 本地画廊（App生成的图片）
          GoRoute(
            path: AppRoutes.localGallery,
            name: 'localGallery',
            builder: (context, state) => const LocalGalleryScreen(),
          ),

          // 画廊页（在线图站浏览）
          GoRoute(
            path: AppRoutes.onlineGallery,
            name: 'onlineGallery',
            builder: (context, state) => const OnlineGalleryScreen(),
          ),

          // 设置页
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          // 随机提示词配置页
          GoRoute(
            path: AppRoutes.promptConfig,
            name: 'promptConfig',
            builder: (context, state) => const PromptConfigScreen(),
          ),
        ],
      ),
    ],

    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}

/// 主布局 Shell - 包含导航
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 在 Overlay 可用后初始化下载服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDownloadServices();
    });
  }

  void _initializeDownloadServices() async {
    if (_initialized) return;
    _initialized = true;

    // 现在 Overlay 已经准备好了，可以安全地初始化下载服务
    final downloadNotifier = ref.read(downloadProgressNotifierProvider.notifier);
    
    if (mounted) {
      downloadNotifier.setContext(context);
    }

    // 后台初始化标签数据
    await downloadNotifier.initializeTagData();
    
    // 下载共现标签数据（100MB）
    if (mounted) {
      downloadNotifier.downloadCooccurrenceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端：使用侧边导航
        if (constraints.maxWidth >= 800) {
          return DesktopShell(child: widget.child);
        }

        // 移动端：使用底部导航
        return MobileShell(child: widget.child);
      },
    );
  }
}

/// 桌面端布局
class DesktopShell extends StatelessWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏
          const MainNavRail(),

          // 主内容区
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 移动端布局
class MobileShell extends StatelessWidget {
  final Widget child;

  const MobileShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(context),
        onDestinationSelected: (index) => _onNavigate(context, index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: context.l10n.nav_generate,
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library),
            label: context.l10n.nav_gallery,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: context.l10n.nav_settings,
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == AppRoutes.gallery) return 1;
    if (location == AppRoutes.settings) return 2;
    return 0;
  }

  void _onNavigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.gallery);
        break;
      case 2:
        context.go(AppRoutes.settings);
        break;
    }
  }
}
