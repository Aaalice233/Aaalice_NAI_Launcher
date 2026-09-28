import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/quick_tools_drawer.dart';

import '../../../../helpers/memory_local_storage.dart';

void main() {
  testWidgets('固定词按正负向再按分类分节，收起状态重开抽屉后仍保留', (tester) async {
    final artists = TagLibraryCategory.create(name: '画师串', sortOrder: 0);
    final outfits = TagLibraryCategory.create(name: '服装插件', sortOrder: 1);
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.fixedTagsData] = jsonEncode([
        FixedTagEntry.create(
          name: 'artist A',
          content: 'a',
          categoryId: artists.id,
        ).toJson(),
        FixedTagEntry.create(
          name: 'artist B',
          content: 'b',
          enabled: false,
          categoryId: artists.id,
          sortOrder: 1,
        ).toJson(),
        FixedTagEntry.create(
          name: 'maid outfit',
          content: 'maid',
          enabled: false,
          categoryId: outfits.id,
          sortOrder: 2,
        ).toJson(),
        FixedTagEntry.create(
          name: 'loose tag',
          content: 'x',
          sortOrder: 3,
        ).toJson(),
        FixedTagEntry.create(
          name: 'bad artist',
          content: 'bad',
          promptType: FixedTagPromptType.negative,
          categoryId: artists.id,
        ).toJson(),
      ]);

    Future<void> pumpDrawer() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
            tagLibraryPageCategoriesProvider.overrideWith(
              (ref) => [outfits, artists],
            ),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: GenerationQuickToolsDrawer()),
          ),
        ),
      );
      await tester.pump();
    }

    Finder header(String key) =>
        find.byKey(ValueKey('generation-quick-tools-section-$key'));

    await pumpDrawer();

    // 分节顺序跟词库排序走，未分类垫底；分节头显示已启用数 / 总数。
    final positiveArtists = header('positive:${artists.id}');
    final positiveOutfits = header('positive:${outfits.id}');
    final uncategorized = header('positive:__uncategorized__');
    expect(
      tester.getTopLeft(positiveArtists).dy,
      lessThan(tester.getTopLeft(positiveOutfits).dy),
    );
    expect(
      tester.getTopLeft(positiveOutfits).dy,
      lessThan(tester.getTopLeft(uncategorized).dy),
    );
    expect(
      find.descendant(of: positiveArtists, matching: find.text('1/2')),
      findsOneWidget,
    );
    expect(header('negative:${artists.id}'), findsOneWidget);

    await tester.tap(positiveArtists);
    await tester.pump();

    expect(find.text('artist A'), findsNothing);
    expect(find.text('artist B'), findsNothing);
    // 正向与负向的同名分类各自收起，互不影响。
    expect(find.text('bad artist'), findsOneWidget);
    expect(storage.values[StorageKeys.quickToolsFixedTagsCollapsedSections], [
      'positive:${artists.id}',
    ]);

    await pumpDrawer();

    expect(find.text('artist A'), findsNothing);
    expect(find.text('maid outfit'), findsOneWidget);

    await tester.tap(header('positive:${artists.id}'));
    await tester.pump();

    expect(find.text('artist A'), findsOneWidget);
    expect(
      storage.values[StorageKeys.quickToolsFixedTagsCollapsedSections],
      isEmpty,
    );
  });
}
