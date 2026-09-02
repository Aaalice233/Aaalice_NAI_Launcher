import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
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
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.padding = const FakeViewPadding(bottom: 32);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final navigationShell = _MockNavigationShell();
      var importCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountManagerNotifierProvider.overrideWith(
              _EmptyAccountManagerNotifier.new,
            ),
          ],
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

      expect(find.byKey(const ValueKey('mobile-more-account')), findsOneWidget);
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
      expect(find.byType(Scrollbar), findsOneWidget);
      final settings = find.byKey(const ValueKey('mobile-more-settings'));
      await tester.scrollUntilVisible(
        settings,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(settings.hitTestable(), findsOneWidget);

      for (final key in const [
        ValueKey('mobile-more-discord'),
        ValueKey('mobile-more-github'),
      ]) {
        final button = find.byKey(key);
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(768));
      }

      await tester.scrollUntilVisible(
        entry,
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(importCalls, 1);
      expect(find.byKey(entryKey), findsNothing);
    },
  );
}

class _EmptyAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}
