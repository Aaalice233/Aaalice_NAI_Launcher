import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/tag_library_page_screen.dart';

void main() {
  testWidgets(
    'mobile category selection closes its panel without popping route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const TagLibraryPageScreen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagLibraryPageNotifierProvider.overrideWith(
              _TestTagLibraryPageNotifier.new,
            ),
            shortcutConfigNotifierProvider.overrideWith(
              _TestShortcutConfigNotifier.new,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tag-library-categories-button')));
      await tester.pumpAndSettle();
      expect(find.text('测试类别'), findsOneWidget);

      await tester.tap(find.text('测试类别'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TagLibraryPageScreen)),
      );
      expect(
        container.read(tagLibraryPageNotifierProvider).selectedCategoryId,
        'test-category',
      );
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('测试类别'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TestShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    categories: [
      TagLibraryCategory(
        id: 'test-category',
        name: '测试类别',
        createdAt: DateTime(2026),
      ),
    ],
  );
}
