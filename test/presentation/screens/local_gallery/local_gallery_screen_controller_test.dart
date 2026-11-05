import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/collection_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_screen_controller.dart';
import 'package:nai_launcher/presentation/widgets/grouped_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 自动释放的 provider 每次读取都可能新建，计数放在实例之外
final class _CountingGallery extends LocalGalleryNotifier {
  _CountingGallery(this.refreshes);

  final List<bool> refreshes;

  @override
  LocalGalleryState build() => const LocalGalleryState(isInitialized: true);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh({bool scan = true}) async => refreshes.add(scan);
}

final class _IdleCollections extends CollectionNotifier {
  @override
  CollectionState build() => const CollectionState();

  @override
  Future<void> initialize() async {}
}

final class _IdleCategories extends GalleryCategoryNotifier {
  @override
  GalleryCategoryState build() => const GalleryCategoryState();

  @override
  Future<void> syncWithFileSystem() async {}
}

class _ControllerHost extends ConsumerStatefulWidget {
  const _ControllerHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends ConsumerState<_ControllerHost> {
  late final LocalGalleryScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocalGalleryScreenController(
      ref: ref,
      context: () => context,
      mounted: () => mounted,
      groupedGridViewKey: GlobalKey<GroupedGridViewState>(),
      actions: LocalGalleryActionCoordinator(
        ref: ref,
        context: () => context,
        mounted: () => mounted,
      ),
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  // 返回后延迟 500ms 再进防抖 500ms
  const refreshSettle = Duration(milliseconds: 1200);

  testWidgets('the gallery refreshes after the window was hidden, never on a '
      'focus switch', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.hasSeenLocalGalleryTip: true,
    });
    final refreshes = <bool>[];
    // 启动时停在别的页面，首次自动刷新被跳过，之后的刷新不受 30 秒间隔限制
    final router = GoRouter(
      initialLocation: '/elsewhere',
      routes: [
        ShellRoute(
          builder: (context, state, child) => _ControllerHost(child: child),
          routes: [
            GoRoute(
              path: '/elsewhere',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/local-gallery',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localGalleryNotifierProvider.overrideWith(
            () => _CountingGallery(refreshes),
          ),
          collectionNotifierProvider.overrideWith(_IdleCollections.new),
          galleryCategoryNotifierProvider.overrideWith(_IdleCategories.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pump(refreshSettle);
    router.go('/local-gallery');
    await tester.pumpAndSettle();
    expect(refreshes, isEmpty);

    Future<void> enter(List<AppLifecycleState> states) async {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pump(refreshSettle);
    }

    for (var round = 0; round < 3; round++) {
      await enter(const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
    }
    expect(refreshes, isEmpty);

    // 从最小化恢复但还没拿到焦点
    await enter(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
    ]);
    expect(refreshes, [false]);
  });
}
