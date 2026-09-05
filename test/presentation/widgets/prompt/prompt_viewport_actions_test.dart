import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_mode_prompt_field.dart';

import '../../../helpers/memory_local_storage.dart';

void main() {
  final scenarios = [
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
      for (final scale in [1.0, 3.0]) (width, 800.0, scale, 0.0),
    (840.0, 360.0, 1.0, 0.0),
    (600.0, 800.0, 1.0, 240.0),
  ];
  for (final (width, height, scale, keyboard) in scenarios) {
    testWidgets(
      'mode switch stays in visible editor $width/$height/$scale/$keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final page = ScrollController();
        final source = TextEditingController(text: 'cat, dog');
        addTearDown(page.dispose);
        addTearDown(source.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith(
                (ref) => MemoryLocalStorage(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, height),
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SizedBox(
                            key: const ValueKey('page-viewport'),
                            child: SingleChildScrollView(
                              controller: page,
                              child: Column(
                                children: [
                                  const SizedBox(height: 80),
                                  SizedBox(
                                    height: 1000,
                                    child: TagModePromptField(
                                      controller: source,
                                      enableAutocomplete: false,
                                      child: TextField(
                                        controller: source,
                                        maxLines: null,
                                        expands: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 1000),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('tag-mode-button'));
        for (final tagMode in [false, true]) {
          for (final offset in [0.0, 150.0, 600.0, 900.0]) {
            page.jumpTo(offset);
            await tester.pump();
            final viewport = tester.getRect(
              find.byKey(const ValueKey('page-viewport')),
            );
            final editor = tester.getRect(find.byType(TagModePromptField));
            final visible = viewport.intersect(editor);
            final rect = tester.getRect(button);
            expect(rect.bottom, closeTo(visible.bottom - 4, 0.01));
            expect(rect.top, greaterThanOrEqualTo(visible.top));
            expect(rect.right, lessThanOrEqualTo(visible.right));
            expect(button.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          if (!tagMode) {
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.byIcon(Icons.sell), findsOneWidget);
          }
        }
        page.jumpTo(1300);
        await tester.pump();
        expect(button.hitTestable(), findsNothing);
        expect(source.text, 'cat, dog');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
