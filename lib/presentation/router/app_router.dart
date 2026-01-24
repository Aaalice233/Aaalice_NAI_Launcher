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
import '../widgets/queue/replication_queue_bar.dart';
import '../providers/replication_queue_provider.dart';

part 'app_router.g.dart';

/// Navigator Keys for StatefulShellRoute branches
// ignore: unused_element
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _galleryKey = GlobalKey<NavigatorState>(debugLabel: 'gallery');
final _localGalleryKey = GlobalKey<NavigatorState>(debugLabel: 'localGallery');
final _onlineGalleryKey = GlobalKey<NavigatorState>(debugLabel: 'onlineGallery');
final _settingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
final _promptConfigKey = GlobalKey<NavigatorState>(debugLabel: 'promptConfig');

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
/// 使用 ref.watch + ValueNotifier 桥接认证状态到 GoRouter 的 refreshListenable
/// 注意：不要使用 ref.listen 在 provider 中，因为这会触发 AssertionError
/// ref.listen 只能在 ConsumerWidget 的 build 方法中使用
@riverpod
GoRouter appRouter(Ref ref) {
  // 使用 ref.watch 监听认证状态变化
  // 当状态变化时，provider 会重建，ValueNotifier 也会更新
  final authState = ref.watch(authNotifierProvider);

  // 创建 ValueNotifier 桥接到 GoRouter 的 refreshListenable
  final authStateNotifier = ValueNotifier<AuthStatus>(authState.status);

  // 当 provider 被销毁时清理
  ref.onDispose(() {
    authStateNotifier.dispose();
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
      // 登录页 - 使用自定义页面过渡动画
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 使用淡入淡出 + 轻微垂直位移的组合动画
            // 与 login_form_container.dart 保持一致的动画风格
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05), // 从下方 5% 处滑入
                  end: Offset.zero,
                ).animate(CurveTween(curve: Curves.easeOutCubic).animate(animation)),
                child: child,
              ),
            );
          },
        ),
      ),

      // 主页 Shell - 使用 StatefulShellRoute 实现混合保活
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          // Branch 0: 生成页 (首页) - 不保活
          StatefulShellBranch(
            navigatorKey: _homeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const GenerationScreen(),
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
                      child: child,
                    );
                  },
                ),
              ),
              GoRoute(
                path: AppRoutes.generation,
                name: 'generation',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const GenerationScreen(),
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
                      child: child,
                    );
                  },
                ),
              ),
            ],
          ),

          // Branch 1: 图库页（本地生成历史）- 不保活
          StatefulShellBranch(
            navigatorKey: _galleryKey,
            routes: [
              GoRoute(
                path: AppRoutes.gallery,
                name: 'gallery',
                builder: (context, state) => const GalleryScreen(),
              ),
            ],
          ),

          // Branch 2: 本地画廊 - 保活
          StatefulShellBranch(
            navigatorKey: _localGalleryKey,
            routes: [
              GoRoute(
                path: AppRoutes.localGallery,
                name: 'localGallery',
                builder: (context, state) => const LocalGalleryScreen(),
              ),
            ],
          ),

          // Branch 3: 在线画廊 - 保活
          StatefulShellBranch(
            navigatorKey: _onlineGalleryKey,
            routes: [
              GoRoute(
                path: AppRoutes.onlineGallery,
                name: 'onlineGallery',
                builder: (context, state) => const OnlineGalleryScreen(),
              ),
            ],
          ),

          // Branch 4: 设置页 - 不保活
          StatefulShellBranch(
            navigatorKey: _settingsKey,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),

          // Branch 5: 随机提示词配置页 - 不保活
          StatefulShellBranch(
            navigatorKey: _promptConfigKey,
            routes: [
              GoRoute(
                path: AppRoutes.promptConfig,
                name: 'promptConfig',
                builder: (context, state) => const PromptConfigScreen(),
              ),
            ],
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

/// 主布局 Shell - 包含导航 (StatefulShellRoute 版本)
/// 
/// 使用混合保活策略：
/// - 画廊页面（索引 2, 3）使用 Offstage 保活
/// - 其他页面不保活
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

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
    final currentIndex = widget.navigationShell.currentIndex;
    
    // 构建混合保活内容栈
    // - 索引 2 (localGallery) 和 3 (onlineGallery) 使用 Offstage 保活
    // - 其他索引不保活，切换时销毁重建
    final contentStack = IndexedStack(
      index: currentIndex,
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final isActive = index == currentIndex;
        
        // 画廊索引（2: localGallery, 3: onlineGallery）始终保持在树中
        // 通过 TickerMode 控制动画
        if (index == 2 || index == 3) {
          return TickerMode(
            enabled: isActive,
            child: child,
          );
        }
        
        // 其他索引：非活动时显示空容器（不保活）
        if (!isActive) {
          return const SizedBox.shrink();
        }
        return child;
      }).toList(),
    );
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端：使用侧边导航
        if (constraints.maxWidth >= 800) {
          return DesktopShell(
            navigationShell: widget.navigationShell,
            content: contentStack,
          );
        }

        // 移动端：使用底部导航
        return MobileShell(
          navigationShell: widget.navigationShell,
          content: contentStack,
        );
      },
    );
  }
}

/// 桌面端布局
class DesktopShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final Widget content;

  const DesktopShell({
    super.key,
    required this.navigationShell,
    required this.content,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    // 在主界面(0)、本地画廊(2)、在线画廊(3) Tab 显示队列悬浮栏
    final showQueueBar = currentIndex == 0 || currentIndex == 2 || currentIndex == 3;
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final hasQueueItems = !queueState.isEmpty;

    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏
          MainNavRail(navigationShell: navigationShell),

          // 主内容区
          Expanded(
            child: Stack(
              children: [
                content,
                // 队列悬浮栏（仅在特定 Tab 且有队列项时显示）
                if (showQueueBar && hasQueueItems)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ReplicationQueueBar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 移动端布局
class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final Widget content;

  const MobileShell({
    super.key,
    required this.navigationShell,
    required this.content,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    // 在主界面(0)、本地画廊(2)、在线画廊(3) Tab 显示队列悬浮栏
    final showQueueBar = currentIndex == 0 || currentIndex == 2 || currentIndex == 3;
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final hasQueueItems = !queueState.isEmpty;

    return Scaffold(
      body: Stack(
        children: [
          content,
          // 队列悬浮栏（仅在特定 Tab 且有队列项时显示）
          // 底部导航栏高度约 80px
          if (showQueueBar && hasQueueItems)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: ReplicationQueueBar(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(),
        onDestinationSelected: (index) => _onNavigate(index),
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

  /// 映射 branch index 到 mobile navigation index
  /// Branches: 0=home, 1=gallery, 2=localGallery, 3=onlineGallery, 4=settings, 5=promptConfig
  /// Mobile nav: 0=home, 1=gallery, 2=settings
  int _getSelectedIndex() {
    final branchIndex = navigationShell.currentIndex;
    if (branchIndex == 4) return 2; // settings
    if (branchIndex >= 1 && branchIndex <= 3) return 1; // any gallery
    return 0; // home
  }

  /// 映射 mobile navigation index 到 branch index
  void _onNavigate(int mobileIndex) {
    // Mobile nav: 0=home, 1=gallery, 2=settings
    // Map to branches: 0=home, 1=gallery, 4=settings
    int branchIndex;
    switch (mobileIndex) {
      case 1:
        branchIndex = 1; // gallery (本地生成历史)
        break;
      case 2:
        branchIndex = 4; // settings
        break;
      default:
        branchIndex = 0; // home
    }
    navigationShell.goBranch(branchIndex);
  }
}
