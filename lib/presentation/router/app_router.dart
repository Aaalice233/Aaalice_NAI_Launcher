import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/shortcuts/default_shortcuts.dart';
import '../../core/utils/app_logger.dart';
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
import '../screens/slideshow_screen.dart';
import '../screens/image_comparison_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/tag_library_page/tag_library_page_screen.dart';
import '../screens/vibe_library/vibe_library_screen.dart';
import '../widgets/drop/global_drop_handler.dart';
import '../widgets/navigation/main_nav_rail.dart';
import '../widgets/queue/floating_queue_button.dart';
import '../widgets/queue/queue_management_page.dart';
import '../widgets/shortcuts/shortcut_aware_widget.dart';
import '../widgets/shortcuts/shortcut_help_dialog.dart';

part 'app_router.g.dart';

/// 队列管理面板显示状态 Provider
final queueManagementVisibleProvider = StateProvider<bool>((ref) => false);

/// 悬浮球手动关闭状态 Provider
///
/// 当用户主动关闭悬浮球时设为 true，悬浮球将不再显示
/// 当队列有新任务添加时自动重置为 false
final floatingButtonClosedProvider = StateProvider<bool>((ref) => false);

/// Navigator Keys for StatefulShellRoute branches
// ignore: unused_element
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _galleryKey = GlobalKey<NavigatorState>(debugLabel: 'gallery');
final _localGalleryKey = GlobalKey<NavigatorState>(debugLabel: 'localGallery');
final _onlineGalleryKey =
    GlobalKey<NavigatorState>(debugLabel: 'onlineGallery');
final _settingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
final _promptConfigKey = GlobalKey<NavigatorState>(debugLabel: 'promptConfig');
final _statisticsKey = GlobalKey<NavigatorState>(debugLabel: 'statistics');
  final _tagLibraryPageKey =
    GlobalKey<NavigatorState>(debugLabel: 'tagLibraryPage');
  final _vibeLibraryKey = GlobalKey<NavigatorState>(debugLabel: 'vibeLibrary');

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
  static const String slideshow = '/slideshow';
  static const String comparison = '/comparison';
  static const String statistics = '/statistics';
  static const String tagLibraryPage = '/tag-library';
  static const String vibeLibrary = '/vibe-library';
}

/// 应用路由 Provider
///
/// 使用 ref.listen 监听认证状态变化并通知 GoRouter
/// 避免使用 ref.watch 导致 GoRouter 实例频繁重建
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // 创建 ValueNotifier 作为 refreshListenable
  // 初始值无关紧要，只要变化就会触发重定向
  final authStateNotifier = ValueNotifier<int>(0);

  // 监听认证状态变化 (status 或 isAuthenticated)
  ref.listen(
    authNotifierProvider.select((value) => value.status),
    (previous, next) {
      // 触发 GoRouter 刷新
      authStateNotifier.value++;
    },
  );

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
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const LoginScreen(),
          slideOffset: const Offset(0.0, 0.05),
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
                pageBuilder: (context, state) => _buildFadePage(
                  state: state,
                  child: const GenerationScreen(),
                ),
              ),
              GoRoute(
                path: AppRoutes.generation,
                name: 'generation',
                pageBuilder: (context, state) => _buildFadePage(
                  state: state,
                  child: const GenerationScreen(),
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
                routes: [
                  // 幻灯片子路由
                  GoRoute(
                    path: AppRoutes.slideshow,
                    name: 'slideshow',
                    pageBuilder: (context, state) {
                      // 从查询参数获取初始索引
                      final initialIndex = int.tryParse(
                            state.uri.queryParameters['initialIndex'] ?? '0',
                          ) ??
                          0;

                      return MaterialPage(
                        key: state.pageKey,
                        child: SlideshowScreen(
                          images: const [],
                          initialIndex: initialIndex,
                        ),
                      );
                    },
                  ),
                  // 图片对比子路由
                  GoRoute(
                    path: AppRoutes.comparison,
                    name: 'comparison',
                    pageBuilder: (context, state) {
                      return MaterialPage(
                        key: state.pageKey,
                        child: const ImageComparisonScreen(
                          images: [],
                        ),
                      );
                    },
                  ),
                ],
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

          // Branch 6: 统计页 - 不保活
          StatefulShellBranch(
            navigatorKey: _statisticsKey,
            routes: [
              GoRoute(
                path: AppRoutes.statistics,
                name: 'statistics',
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),

          // Branch 7: 词库页 - 保活
          StatefulShellBranch(
            navigatorKey: _tagLibraryPageKey,
            routes: [
              GoRoute(
                path: AppRoutes.tagLibraryPage,
                name: 'tagLibraryPage',
                builder: (context, state) => const TagLibraryPageScreen(),
              ),
            ],
          ),

          // Branch 8: Vibe库页 - 保活
          StatefulShellBranch(
            navigatorKey: _vibeLibraryKey,
            routes: [
              GoRoute(
                path: AppRoutes.vibeLibrary,
                name: 'vibeLibrary',
                builder: (context, state) => const VibeLibraryScreen(),
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
    final downloadNotifier =
        ref.read(downloadProgressNotifierProvider.notifier);

    if (mounted) {
      downloadNotifier.setContext(context);
    }

    // 后台初始化标签数据
    await downloadNotifier.initializeTagData();

    // 下载共现标签数据（100MB）
    if (mounted) {
      try {
        await downloadNotifier.downloadCooccurrenceData();
      } catch (e) {
        AppLogger.e('Failed to download cooccurrence data', e, null, 'AppRouter');
      }
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

    // 使用 GlobalDropHandler 包装内容，支持拖拽图片到任意页面
    final dropEnabledContent = GlobalDropHandler(
      child: contentStack,
    );

    // 定义全局快捷键动作映射（使用 ShortcutIds 常量）
    final globalShortcuts = <String, VoidCallback>{
      // 页面导航
      ShortcutIds.navigateToGeneration: () {
        widget.navigationShell.goBranch(0);
      },
      ShortcutIds.navigateToLocalGallery: () {
        widget.navigationShell.goBranch(2);
      },
      ShortcutIds.navigateToOnlineGallery: () {
        widget.navigationShell.goBranch(3);
      },
      ShortcutIds.navigateToSettings: () {
        widget.navigationShell.goBranch(4);
      },
      ShortcutIds.navigateToRandomConfig: () {
        widget.navigationShell.goBranch(5);
      },
      ShortcutIds.navigateToStatistics: () {
        widget.navigationShell.goBranch(6);
      },
      ShortcutIds.navigateToTagLibrary: () {
        widget.navigationShell.goBranch(7);
      },
      // 显示快捷键帮助
      ShortcutIds.showShortcutHelp: () {
        ShortcutHelpDialog.show(context);
      },
      // 显示/隐藏队列
      ShortcutIds.toggleQueue: () {
        final isVisible = ref.read(queueManagementVisibleProvider);
        ref.read(queueManagementVisibleProvider.notifier).state = !isVisible;
      },
    };

    // 使用 ShortcutAwareWidget 包装全局快捷键
    final shortcutEnabledContent = ShortcutAwareWidget(
      contextType: ShortcutContext.global,
      shortcuts: globalShortcuts,
      autofocus: true,
      child: dropEnabledContent,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端：使用侧边导航
        if (constraints.maxWidth >= 800) {
          return DesktopShell(
            navigationShell: widget.navigationShell,
            content: shortcutEnabledContent,
          );
        }

        // 移动端：使用底部导航
        return MobileShell(
          navigationShell: widget.navigationShell,
          content: shortcutEnabledContent,
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
    final isQueueVisible = ref.watch(queueManagementVisibleProvider);

    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏
          MainNavRail(navigationShell: navigationShell),

          // 主内容区
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    content,
                    // 队列悬浮球 - 传入实际可用区域大小
                    FloatingQueueButton(
                      onTap: () => ref
                          .read(queueManagementVisibleProvider.notifier)
                          .state = !isQueueVisible,
                      containerSize:
                          Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    // 队列管理面板
                    _QueuePanel(
                      isVisible: isQueueVisible,
                      maxWidth: 650,
                      heightFactor: 0.85,
                    ),
                  ],
                );
              },
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
    final isQueueVisible = ref.watch(queueManagementVisibleProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              content,
              // 队列悬浮球 - 传入实际可用区域大小
              FloatingQueueButton(
                onTap: () => ref
                    .read(queueManagementVisibleProvider.notifier)
                    .state = !isQueueVisible,
                containerSize:
                    Size(constraints.maxWidth, constraints.maxHeight),
              ),
              // 队列管理面板
              _QueuePanel(
                isVisible: isQueueVisible,
                maxWidth: double.infinity,
                heightFactor: 0.85,
              ),
            ],
          );
        },
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

// ============================================
// 页面过渡动画辅助方法
// ============================================

const _defaultTransitionDuration = Duration(milliseconds: 300);
const _defaultCurve = Curves.easeOutCubic;

/// 构建淡入页面过渡
CustomTransitionPage<void> _buildFadePage({
  required GoRouterState state,
  required Widget child,
  Duration duration = _defaultTransitionDuration,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: _defaultCurve).animate(animation),
        child: child,
      );
    },
  );
}

/// 构建淡入+滑动页面过渡
CustomTransitionPage<void> _buildFadeSlidePage({
  required GoRouterState state,
  required Widget child,
  Offset slideOffset = Offset.zero,
  Duration duration = _defaultTransitionDuration,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurveTween(curve: _defaultCurve).animate(animation);
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

// ============================================
// 队列面板组件
// ============================================

/// 队列管理面板组件
///
/// 带背景遮罩、滑动动画和队列管理页面
class _QueuePanel extends ConsumerWidget {
  final bool isVisible;
  final double maxWidth;
  final double heightFactor;

  const _QueuePanel({
    required this.isVisible,
    required this.maxWidth,
    required this.heightFactor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 背景遮罩
            if (isVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => ref.read(queueManagementVisibleProvider.notifier).state = false,
                  child: Container(color: Colors.black54),
                ),
              ),
            // 滑动面板
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: const Offset(0, 1),
                end: isVisible ? Offset.zero : const Offset(0, 1),
              ),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                return IgnorePointer(
                  ignoring: offset.dy >= 0.5,
                  child: FractionalTranslation(
                    translation: offset,
                    child: child,
                  ),
                );
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Material(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: constraints.maxHeight * heightFactor,
                        child: const QueueManagementPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
