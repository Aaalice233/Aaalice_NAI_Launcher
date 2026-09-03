import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../adaptive/adaptive_layout.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/generation/generation_screen.dart';
import '../screens/image_comparison_screen.dart';
import '../screens/local_gallery/local_gallery_screen.dart';
import '../screens/online_gallery/online_gallery_screen.dart';
import '../screens/precise_ref_library/precise_ref_library_screen.dart';
import '../screens/prompt_config/prompt_config_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/settings_section.dart';
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

/// Runtime payload for gallery routes whose image records cannot be encoded in
/// a URL. Routes without a usable payload redirect to the local gallery.
class GallerySlideshowRouteData {
  const GallerySlideshowRouteData({
    required this.images,
    this.initialIndex = 0,
  });

  final List<LocalImageRecord> images;
  final int initialIndex;
}

class GalleryComparisonRouteData {
  const GalleryComparisonRouteData({required this.images});

  final List<LocalImageRecord> images;
}

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
                builder: (context, state) => const GenerationScreen(),
              ),
              GoRoute(
                path: AppRoutes.generation,
                name: AppRouteNames.generation,
                builder: (context, state) => const GenerationScreen(),
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
                    redirect: (context, state) {
                      final payload = state.extra is GallerySlideshowRouteData
                          ? state.extra! as GallerySlideshowRouteData
                          : null;
                      return payload == null || payload.images.isEmpty
                          ? AppRoutes.localGallery
                          : null;
                    },
                    pageBuilder: (context, state) {
                      final payload = state.extra! as GallerySlideshowRouteData;
                      final requestedIndex =
                          int.tryParse(
                            state.uri.queryParameters['initialIndex'] ?? '',
                          ) ??
                          payload.initialIndex;
                      final initialIndex = requestedIndex.clamp(
                        0,
                        payload.images.length - 1,
                      );
                      return MaterialPage(
                        key: state.pageKey,
                        child: SlideshowScreen(
                          images: payload.images,
                          initialIndex: initialIndex,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: AppRoutes.comparison,
                    name: AppRouteNames.comparison,
                    redirect: (context, state) {
                      final payload = state.extra is GalleryComparisonRouteData
                          ? state.extra! as GalleryComparisonRouteData
                          : null;
                      return payload == null || payload.images.length < 2
                          ? AppRoutes.localGallery
                          : null;
                    },
                    pageBuilder: (context, state) {
                      final payload =
                          state.extra! as GalleryComparisonRouteData;
                      return MaterialPage(
                        key: state.pageKey,
                        child: ImageComparisonScreen(images: payload.images),
                      );
                    },
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
                  initialSection: SettingsSection.fromId(
                    state.uri.queryParameters['section'],
                  ),
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
    errorBuilder: (context, state) => RouterErrorScreen(error: state.error),
  );
}

/// Responsive fallback shown when no application route can handle a location.
class RouterErrorScreen extends StatelessWidget {
  const RouterErrorScreen({super.key, required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: AdaptiveSlotLayout(
          builder: (context, areas) => SingleChildScrollView(
            key: const ValueKey('router_error_scroll_view'),
            padding: EdgeInsets.symmetric(
              horizontal: areas.horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (areas.constraints.maxHeight - 48)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: AdaptiveContentBounds(
                maxWidth: 640,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.router_pageNotFound('$error'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        TextButton.icon(
                          key: const ValueKey('router_error_back'),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go(AppRoutes.home);
                            }
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: Text(context.l10n.editor_back),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('router_error_home'),
                          onPressed: () => context.go(AppRoutes.home),
                          icon: const Icon(Icons.home_outlined),
                          label: Text(
                            context.l10n.shortcut_action_send_to_home,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _defaultTransitionDuration = Duration(milliseconds: 300);
const _defaultCurve = Curves.easeOutCubic;

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
