import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_assistant.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_tag_mode_toggle.dart';

import '../../../../helpers/memory_local_storage.dart';

void main() {
  final scenarios = [
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
      for (final scale in [1.0, 3.0]) (width, 800.0, scale, 0.0),
    (840.0, 360.0, 1.0, 0.0),
    (600.0, 800.0, 1.0, 240.0),
  ];
  for (final (width, height, scale, keyboard) in scenarios) {
    testWidgets(
      'assistant stays in visible editor $width/$height/$scale/$keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final page = ScrollController();
        final source = TextEditingController(text: 'cat, dog');
        addTearDown(page.dispose);
        addTearDown(source.dispose);
        var textPointerDowns = 0;
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
                                    child: Stack(
                                      children: [
                                        Listener(
                                          onPointerDown: (_) =>
                                              textPointerDowns++,
                                          child: TextField(
                                            controller: source,
                                            maxLines: null,
                                            expands: true,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: PromptInputAssistant(
                                            sessionId: 'test',
                                            controller: source,
                                            onChanged: (_) {},
                                            onOpenSettings: () {},
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 1000),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: PromptTagModeToggle(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final modeSwitch = find.widgetWithText(TextButton, 'Tag mode');
        expect(modeSwitch.hitTestable(), findsOneWidget);
        expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
        await tester.tap(modeSwitch);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.sell), findsOneWidget);
        final button = find.byKey(
          const ValueKey('generation_prompt_assistant_test'),
        );
        for (final expanded in [false, true]) {
          for (final offset in [0.0, 150.0, 600.0, 900.0]) {
            page.jumpTo(offset);
            await tester.pump();
            final viewport = tester.getRect(
              find.byKey(const ValueKey('page-viewport')),
            );
            final editor = tester.getRect(find.byType(TextField));
            final visible = viewport.intersect(editor);
            final rect = tester.getRect(button);
            expect(rect.bottom, closeTo(visible.bottom - 4, 0.01));
            expect(rect.top, greaterThanOrEqualTo(visible.top));
            expect(rect.right, lessThanOrEqualTo(visible.right));
            expect(button.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          if (!expanded) {
            final editorBefore = tester.getRect(find.byType(TextField));
            final collapsed = tester.getRect(button);
            await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
            await tester.pumpAndSettle();
            expect(find.byIcon(Icons.translate), findsOneWidget);
            expect(textPointerDowns, 0);
            expect(tester.getRect(find.byType(TextField)), editorBefore);
            expect(tester.getRect(button).right, collapsed.right);
            expect(tester.getRect(button).left, lessThan(collapsed.left));
          }
        }
        page.jumpTo(150);
        await tester.pump();
        final visible = tester
            .getRect(find.byKey(const ValueKey('page-viewport')))
            .intersect(tester.getRect(find.byType(TextField)));
        await tester.tapAt(visible.topLeft + const Offset(20, 20));
        expect(textPointerDowns, 1);
        page.jumpTo(1300);
        await tester.pump();
        expect(button.hitTestable(), findsNothing);
        expect(source.text, 'cat, dog');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
