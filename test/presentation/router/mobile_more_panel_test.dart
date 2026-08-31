import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/router/mobile_more_panel.dart';

class _MockNavigationShell extends Mock implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockNavigationShell';
}

void main() {
  testWidgets(
    'mobile more panel exposes one single-line metadata entry and wires tap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigationShell = _MockNavigationShell();
      var importCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Consumer(
              builder: (context, ref, child) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMobileMorePanel(
                      context: context,
                      ref: ref,
                      navigationShell: navigationShell,
                      onImportImageMetadata: (context, ref) async {
                        importCalls++;
                      },
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const entryKey = ValueKey('mobile-more-read-image-metadata');
      final entry = find.byKey(entryKey);
      expect(entry, findsOneWidget);
      expect(find.text('读取图片元数据'), findsOneWidget);

      final tile = tester.widget<ListTile>(
        find.descendant(of: entry, matching: find.byType(ListTile)),
      );
      expect(tile.subtitle, isNull);
      final title = tile.title! as Text;
      expect(title.maxLines, 1);

      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(importCalls, 1);
      expect(find.byKey(entryKey), findsNothing);
    },
  );
}
