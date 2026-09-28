import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_library_sidebar.dart';

void main() {
  testWidgets('收藏作为分类内置项并统一使用爱心图标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 250,
              height: 600,
              child: PreciseRefLibrarySidebar(
                state: const PreciseRefLibraryState(),
                onFilterChanged: ({required favoritesOnly, type}) {},
              ),
            ),
          ),
        ),
      ),
    );

    final allY = tester.getTopLeft(find.text('全部图片')).dy;
    final categoriesY = tester.getTopLeft(find.text('分类')).dy;
    final favoritesY = tester.getTopLeft(find.text('收藏')).dy;
    final firstTypeY = tester.getTopLeft(find.text('角色')).dy;

    expect(allY, lessThan(categoriesY));
    expect(categoriesY, lessThan(favoritesY));
    expect(favoritesY, lessThan(firstTypeY));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('precise-ref-type-section-toggle')));
    await tester.pump();

    expect(find.text('收藏'), findsNothing);
    expect(find.text('角色'), findsNothing);
    expect(find.text('全部图片'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
