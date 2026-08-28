import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/localization_extension.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/generation/generation_screen.dart';
import '../screens/image_comparison_screen.dart';
import '../screens/local_gallery/local_gallery_screen.dart';
import '../screens/online_gallery/online_gallery_screen.dart';
import '../screens/precise_ref_library/precise_ref_library_screen.dart';
import '../screens/prompt_config/prompt_config_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/slideshow_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/tag_library_page/tag_library_page_screen.dart';
import '../screens/vibe_library/vibe_library_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

part 'app_router_config.g.dart';

final _homeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _localGalleryKey = GlobalKey<NavigatorState>(debugLabel: 'localGallery');
final _onlineGalleryKey = GlobalKey<NavigatorState>(
  debugLabel: 'onlineGallery',
);
final _settingsKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
final _promptConfigKey = GlobalKey<NavigatorState>(debugLabel: 'promptConfig');
final _statisticsKey = GlobalKey<NavigatorState>(debugLabel: 'statistics');
final _tagLibraryPageKey = GlobalKey<NavigatorState>(
  debugLabel: 'tagLibraryPage',
);
final _vibeLibraryKey = GlobalKey<NavigatorState>(debugLabel: 'vibeLibrary');
final _preciseRefLibraryKey = GlobalKey<NavigatorState>(
  debugLabel: 'preciseRefLibrary',
);

/// 应用路由 Provider。
///
/// 监听认证状态并通知 GoRouter 重新评估重定向，不重建路由实例。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authStateNotifier = ValueNotifier<int>(0);

  ref.listen(authNotifierProvider.select((value) => value.status), (_, __) {
    authStateNotifier.value++;
  });
  ref.onDispose(authStateNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    restorationScopeId: 'app_router',
    debugLogDiagnostics: true,
    refreshListenable: authStateNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      return resolveAuthRedirect(
        status: authState.status,
        isAuthenticated: authState.isAuthenticated,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const LoginScreen(),
          slideOffset: const Offset(0, 0.05),
        ),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRouteNames.home,
                pageBuilder: (context, state) => _buildFadePage(
                  state: state,
                  child: const GenerationScreen(),
                ),
              ),
              GoRoute(
                path: AppRoutes.generation,
                name: AppRouteNames.generation,
                pageBuilder: (context, state) => _buildFadePage(
                  state: state,
                  child: const GenerationScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _localGalleryKey,
            routes: [
              GoRoute(
                path: AppRoutes.localGallery,
                name: AppRouteNames.localGallery,
                builder: (context, state) => const LocalGalleryScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.slideshow,
                    name: AppRouteNames.slideshow,
                    pageBuilder: (context, state) {
                      final initialIndex =
                          int.tryParse(
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
                  GoRoute(
                    path: AppRoutes.comparison,
                    name: AppRouteNames.comparison,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const ImageComparisonScreen(images: []),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _onlineGalleryKey,
            routes: [
              GoRoute(
                path: AppRoutes.onlineGallery,
                name: AppRouteNames.onlineGallery,
                builder: (context, state) => const OnlineGalleryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsKey,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRouteNames.settings,
                builder: (context, state) => SettingsScreen(
                  initialSectionIndex:
                      switch (state.uri.queryParameters['section']) {
                        'storage' => 3,
                        'integrations' => 7,
                        _ => 0,
                      },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _promptConfigKey,
            routes: [
              GoRoute(
                path: AppRoutes.promptConfig,
                name: AppRouteNames.promptConfig,
                builder: (context, state) => const PromptConfigScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _statisticsKey,
            routes: [
              GoRoute(
                path: AppRoutes.statistics,
                name: AppRouteNames.statistics,
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _tagLibraryPageKey,
            routes: [
              GoRoute(
                path: AppRoutes.tagLibraryPage,
                name: AppRouteNames.tagLibraryPage,
                builder: (context, state) => const TagLibraryPageScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _vibeLibraryKey,
            routes: [
              GoRoute(
                path: AppRoutes.vibeLibrary,
                name: AppRouteNames.vibeLibrary,
                builder: (context, state) => const VibeLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _preciseRefLibraryKey,
            routes: [
              GoRoute(
                path: AppRoutes.preciseRefLibrary,
                name: AppRouteNames.preciseRefLibrary,
                builder: (context, state) => const PreciseRefLibraryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(context.l10n.router_pageNotFound('${state.error}')),
      ),
    ),
  );
}

const _defaultTransitionDuration = Duration(milliseconds: 300);
const _defaultCurve = Curves.easeOutCubic;

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
      final curvedAnimation = CurveTween(
        curve: _defaultCurve,
      ).animate(animation);
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
