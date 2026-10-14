import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_content.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

  testWidgets('F5 按当前搜索框草稿刷新', (tester) async {
    final harness = await _pumpGallery(tester);

    await harness.press(LogicalKeyboardKey.f5);

    expect(harness.notifier.refreshes, 1);
  }, variant: desktop);

  testWidgets('PageUp / PageDown 跳到上一页 / 下一页', (tester) async {
    final harness = await _pumpGallery(tester, page: 2);

    await harness.press(LogicalKeyboardKey.pageDown);
    await harness.press(LogicalKeyboardKey.pageUp);

    expect(harness.notifier.requestedPages, [3, 1]);
  }, variant: desktop);

  testWidgets('第一页按 PageUp、没有下一页时按 PageDown 都不翻页', (tester) async {
    final harness = await _pumpGallery(tester, hasMore: false);

    await harness.press(LogicalKeyboardKey.pageUp);
    await harness.press(LogicalKeyboardKey.pageDown);

    expect(harness.notifier.requestedPages, isEmpty);
  }, variant: desktop);

  testWidgets('Ctrl+F 聚焦搜索框，聚焦后 PageDown 留给输入框、F5 照常刷新', (tester) async {
    final harness = await _pumpGallery(tester);

    await harness.press(LogicalKeyboardKey.keyF, control: true);
    expect(harness.controller.searchFocusNode.hasPrimaryFocus, isTrue);

    await harness.press(LogicalKeyboardKey.pageDown);
    expect(harness.notifier.requestedPages, isEmpty);
    await harness.press(LogicalKeyboardKey.f5);
    expect(harness.notifier.refreshes, 1);
  }, variant: desktop);

  testWidgets('进入多选改绑后按新组合键进入多选', (tester) async {
    final harness = await _pumpGallery(
      tester,
      config: ShortcutConfig.createDefault().setCustomShortcut(
        ShortcutIds.enterSelectionMode,
        'ctrl+shift+s',
      ),
    );

    await harness.press(LogicalKeyboardKey.keyS, control: true, shift: true);

    expect(harness.selection.isActive, isTrue);
    expect(harness.selection.selectedIds, isEmpty);
  }, variant: desktop);

  testWidgets('快捷键总开关关闭时 F5 不刷新，Ctrl+A 全选照常', (tester) async {
    final harness = await _pumpGallery(
      tester,
      config: ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
    );

    await harness.press(LogicalKeyboardKey.f5);
    expect(harness.notifier.refreshes, 0);

    await harness.press(LogicalKeyboardKey.keyA, control: true);
    expect(harness.selection.selectedIds, hasLength(_postCount));
  }, variant: desktop);
}

const _postCount = 24;

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;

  ProviderContainer get _container => ProviderScope.containerOf(
    tester.element(find.byType(OnlineGalleryScreen)),
  );

  _CountingGalleryNotifier get notifier =>
      _container.read(onlineGalleryNotifierProvider.notifier)
          as _CountingGalleryNotifier;

  SelectionModeState get selection =>
      _container.read(onlineGallerySelectionNotifierProvider);

  OnlineGalleryScreenController get controller => tester
      .widget<OnlineGalleryContent>(find.byType(OnlineGalleryContent))
      .controller;

  Future<void> press(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }
}

Future<_Harness> _pumpGallery(
  WidgetTester tester, {
  int page = 1,
  bool hasMore = true,
  ShortcutConfig? config,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          () => _FixedShortcutConfigNotifier(
            config ?? ShortcutConfig.createDefault(),
          ),
        ),
        onlineGalleryNotifierProvider.overrideWith(
          () => _CountingGalleryNotifier(page: page, hasMore: hasMore),
        ),
        danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
        gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnlineGalleryScreen(),
      ),
    ),
  );
  await tester.pump();
  return _Harness(tester);
}

class _FixedShortcutConfigNotifier extends ShortcutConfigNotifier {
  _FixedShortcutConfigNotifier(this.config);

  final ShortcutConfig config;

  @override
  Future<ShortcutConfig> build() async => config;
}

class _CountingGalleryNotifier extends OnlineGalleryNotifier {
  _CountingGalleryNotifier({required this.page, required this.hasMore});

  final int page;
  final bool hasMore;
  int refreshes = 0;
  final requestedPages = <int>[];

  @override
  OnlineGalleryState build() => OnlineGalleryState(
    searchCache: ModeCache(
      posts: List.generate(
        _postCount,
        (index) => DanbooruPost(
          id: 7000 + index,
          site: 'danbooru',
          width: 1200,
          height: 800,
          rating: 'g',
          tagStringGeneral: 'solo',
        ),
        growable: false,
      ),
      page: page,
      hasMore: hasMore,
      nextCursor: hasMore ? 'next' : null,
    ),
  );

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refreshWithDraft({
    required String query,
    required String prompt,
  }) async {
    refreshes++;
  }

  @override
  Future<GalleryPageJumpTarget?> goToPage(int page) async {
    requestedPages.add(page);
    return null;
  }
}

class _LoggedOutDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();

  @override
  Future<void> ensureInitialized() async {}
}

class _UnconfiguredGelbooruAuth extends GelbooruAuth {
  @override
  GelbooruAuthState build() =>
      const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured);

  @override
  Future<void> ensureInitialized() async {}
}
