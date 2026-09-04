import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart';

class _FakeTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => const TagLibraryPageState();

  @override
  void setSortBy(TagLibrarySortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }
}

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('桌面宽度保留紧凑排序入口并可打开菜单', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    await tester.binding.setSurfaceSize(const Size(1180, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(
            _FakeTagLibraryPageNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TagLibraryToolbar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sortButton = find.byKey(const Key('tag-library-sort-menu-button'));
    final addButton = find.byKey(const Key('tag-library-add-entry-button'));
    expect(tester.getSize(sortButton).height, 36);
    expect(tester.getSize(addButton).height, greaterThanOrEqualTo(40));
    expect(find.text('自定义排序'), findsOneWidget);

    await tester.tap(sortButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tag-library-sort-option-updatedAt')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('手机宽度 $width 下分类与排序菜单完整显示', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagLibraryPageNotifierProvider.overrideWith(
              _FakeTagLibraryPageNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 180,
                  child: ClipRect(
                    child: TagLibraryToolbar(onShowCategories: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final categories = find.byKey(const Key('tag-library-categories-button'));
      final sortButton = find.byKey(const Key('tag-library-sort-menu-button'));
      expect(categories, findsOneWidget);
      expect(
        find.descendant(of: categories, matching: find.text('分类')),
        findsOneWidget,
      );
      expect(sortButton, findsOneWidget);
      expect(
        find.descendant(of: sortButton, matching: find.text('自定义排序')),
        findsOneWidget,
      );
      _expectOnScreen(tester.getRect(categories), width);
      _expectOnScreen(tester.getRect(sortButton), width);
      expect(tester.takeException(), isNull);

      final anchor = tester.widget<MenuAnchor>(
        find.byKey(const Key('tag-library-sort-menu-anchor')),
      );
      expect(anchor.useRootOverlay, isTrue);
      expect(anchor.style?.minimumSize?.resolve({})?.width, 176);
      expect(anchor.style?.maximumSize?.resolve({})?.width, 176);
      expect(anchor.style?.maximumSize?.resolve({})?.height, 280);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      final optionKeys = ['order', 'name', 'useCount', 'updatedAt'];
      for (final optionKey in optionKeys) {
        final option = find.byKey(
          ValueKey('tag-library-sort-option-$optionKey'),
        );
        expect(option, findsOneWidget);
        final rect = tester.getRect(option);
        _expectOnScreen(rect, width);
        expect(rect.width, inInclusiveRange(140, 176));
      }

      final firstOption = tester.getRect(
        find.byKey(const ValueKey('tag-library-sort-option-order')),
      );
      expect(
        firstOption.top,
        greaterThanOrEqualTo(tester.getRect(sortButton).bottom),
      );

      await tester.tap(
        find.byKey(const ValueKey('tag-library-sort-option-name')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sortButton, matching: find.text('名称')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectOnScreen(Rect rect, double screenWidth) {
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(screenWidth));
}
