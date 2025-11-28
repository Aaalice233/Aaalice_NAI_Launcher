import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/generation/generation_screen.dart';
import '../screens/gallery/gallery_screen.dart';
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
  static const String settings = '/settings';
}

/// 应用路由 Provider
@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,

    // 重定向逻辑
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

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
        builder: (context, state) => const LoginScreen(),
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

          // 画廊页
          GoRoute(
            path: AppRoutes.gallery,
            name: 'gallery',
            builder: (context, state) => const GalleryScreen(),
          ),

          // 设置页
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
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
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端：使用侧边导航
        if (constraints.maxWidth >= 800) {
          return DesktopShell(child: child);
        }

        // 移动端：使用底部导航
        return MobileShell(child: child);
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '生成',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '画廊',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
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
