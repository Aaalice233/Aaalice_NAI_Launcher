import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/tag_library_page_screen.dart';

import '../../../helpers/light_theme_contrast.dart';

/// 【偏离上游】上游 v4.2.1 的窄屏分类入口是 AdaptivePresenter.showPanel 的
/// 底部弹面板（key: adaptive-bottom-sheet）。用户点名要左侧边栏，所以窄屏改成
/// 左侧 Drawer 承载同一个分类树。这条测试守住「是抽屉、不是底部面板」。
void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
  });
  tearDown(() => PlatformCapabilities.debugOverride = null);

  testWidgets('窄屏分类入口打开左侧抽屉而不是底部面板，选中后收起', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLibrary(tester);

    // 抽屉挂在 Scaffold 上，且关闭了边缘拖拽（避免与卡片横滑抢触点）
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(TagLibraryPageScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.drawer, isNotNull);
    expect(scaffold.drawerEnableOpenDragGesture, isFalse);
    expect(find.byType(Drawer), findsNothing);

    await tester.tap(find.byKey(const Key('tag-library-categories-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('tag-library-category-drawer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    final allEntries = find.byKey(const Key('tag-library-all-entries'));
    expect(allEntries, findsOneWidget);
    // 抽屉贴左边：左缘落在屏幕左侧
    expect(tester.getRect(find.byType(Drawer)).left, 0);

    await tester.tap(allEntries);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tag-library-category-drawer')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLibrary(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith(
          (ref) => InMemoryLocalStorageService(),
        ),
        tagLibraryPageNotifierProvider.overrideWith(
          _PopulatedTagLibraryNotifier.new,
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _ShortcutConfigNotifier.new,
        ),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: TagLibraryPageScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _PopulatedTagLibraryNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    viewMode: TagLibraryViewMode.card,
    entries: [
      TagLibraryEntry(
        id: 'target-entry',
        name: '目标条目',
        content: 'target tag, detailed prompt',
        tags: const ['人物'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  );
}

class _ShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
