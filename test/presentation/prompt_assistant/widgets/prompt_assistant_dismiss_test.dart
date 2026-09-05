import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';

import '../../../helpers/memory_local_storage.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('outside $kind tap collapses only its own assistant', (
      tester,
    ) async {
      final source = TextEditingController(text: 'cat');
      addTearDown(source.dispose);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => MemoryLocalStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);
      var outsideTaps = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Column(
                  children: [
                    // Character editors share this outer group with their assistant.
                    TapRegion(
                      groupId: 'editor',
                      child: TextButton(
                        onPressed: () => outsideTaps++,
                        child: const Text('outside'),
                      ),
                    ),
                    PromptAssistantOverlay(
                      sessionId: 'dismiss',
                      controller: source,
                      tapRegionGroupId: 'editor',
                      placement: PromptAssistantPlacement.inline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final notifier = container.read(promptAssistantStateProvider.notifier);
      notifier.setExpanded('other', true);
      await tester.tap(find.byIcon(Icons.auto_awesome_rounded), kind: kind);
      await tester.pumpAndSettle();
      bool expanded(String id) =>
          container.read(promptAssistantStateProvider)[id]!.expanded;
      expect(expanded('dismiss'), isTrue);
      final toolbar = tester.getRect(
        find.byKey(const ValueKey('prompt_assistant_toolbar_dismiss')),
      );
      await tester.tapAt(toolbar.topLeft + const Offset(2, 2), kind: kind);
      await tester.pump();
      expect(expanded('dismiss'), isTrue);
      await tester.tap(find.text('outside'), kind: kind);
      await tester.pumpAndSettle();
      expect(expanded('dismiss'), isFalse);
      expect(expanded('other'), isTrue);
      expect(outsideTaps, 1);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
