import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';

import '../../../helpers/memory_local_storage.dart';

enum _Mount { inline, editor, viewport }

Future<void> _pump(
  WidgetTester tester,
  TextEditingController source, {
  required _Mount mount,
  required bool touch,
  required bool iconOnly,
  double scale = 1,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: true,
          size: const Size(800, 600),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: touch
                ? InteractionPolicy.touchFirst
                : const InteractionPolicy(
                    modality: InteractionModality.pointer,
                    touchAvailable: false,
                    precisePointerAvailable: true,
                  ),
            child: Builder(
              builder: (context) {
                final assistant = PromptAssistantOverlay(
                  sessionId: 'layout',
                  controller: source,
                  iconOnly: iconOnly,
                  placement: switch (mount) {
                    _Mount.editor => PromptAssistantPlacement.editor,
                    _Mount.viewport => PromptAssistantPlacement.viewport,
                    _ => PromptAssistantPlacement.inline,
                  },
                );
                return SizedBox(
                  width: 320,
                  height: 180,
                  child: switch (mount) {
                    _Mount.inline => Align(
                      alignment: Alignment.bottomRight,
                      child: assistant,
                    ),
                    _Mount.editor => Stack(children: [assistant]),
                    _Mount.viewport => Stack(
                      children: [Positioned.fill(child: assistant)],
                    ),
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final mount in _Mount.values) {
    for (final touch in [false, true]) {
      for (final iconOnly in [false, true]) {
        for (final scale in [1.0, 3.0]) {
          testWidgets(
            'stable toolbar $mount / touch=$touch / icon=$iconOnly / scale=$scale',
            (tester) async {
              final source = TextEditingController(text: 'cat, dog');
              addTearDown(source.dispose);
              await _pump(
                tester,
                source,
                mount: mount,
                touch: touch,
                iconOnly: iconOnly,
                scale: scale,
              );
              await tester.pumpAndSettle();
              final toolbar = find.byKey(
                const ValueKey('prompt_assistant_toolbar_layout'),
              );
              final before = tester.getRect(toolbar);
              if (scale == 1) expect(before.height, touch ? 48 : 44);
              if (!touch && !iconOnly) {
                expect(
                  tester.getSize(find.text('Assistant')).height,
                  lessThanOrEqualTo(before.height),
                );
              }
              await tester.tap(
                find.byIcon(Icons.auto_awesome_rounded),
                kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
              );
              await tester.pump();
              expect(tester.getRect(toolbar).height, before.height);
              await tester.pump(const Duration(milliseconds: 80));
              expect(tester.getRect(toolbar).height, before.height);
              await tester.pumpAndSettle();
              expect(tester.getRect(toolbar).right, closeTo(before.right, .01));
              expect(tester.getRect(toolbar).top, before.top);

              final container = ProviderScope.containerOf(
                tester.element(find.byType(PromptAssistantOverlay)),
              );
              final state = container.read(
                promptAssistantStateProvider.notifier,
              );
              state.startProcessing('layout', 'test');
              await tester.pump();
              expect(tester.getRect(toolbar).height, before.height);
              expect(
                tester.getRect(toolbar).width,
                closeTo(before.height, .01),
              );
              expect(find.byIcon(Icons.translate), findsNothing);
              expect(
                find.byKey(const ValueKey('prompt_assistant_stop')),
                findsOneWidget,
              );
              state.setError('layout', 'test failure');
              await tester.pump();
              expect(tester.getRect(toolbar).height, before.height);
              for (final icon in [
                Icons.translate,
                Icons.more_horiz,
                Icons.keyboard_arrow_down_rounded,
              ]) {
                final button = find.widgetWithIcon(IconButton, icon);
                await tester.ensureVisible(button);
                await tester.pump();
                expect(button.hitTestable(), findsOneWidget);
                expect(
                  tester.getSize(button).height,
                  closeTo(before.height, .01),
                );
              }
              await tester.tap(
                find.byIcon(Icons.keyboard_arrow_down_rounded),
                kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
              );
              await tester.pumpAndSettle();
              expect(tester.getRect(toolbar), before);
              expect(source.text, 'cat, dog');
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }

  testWidgets('icon trigger remains keyboard accessible', (tester) async {
    final source = TextEditingController(text: 'cat');
    addTearDown(source.dispose);
    await _pump(
      tester,
      source,
      mount: _Mount.inline,
      touch: false,
      iconOnly: true,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.translate), findsOneWidget);
    expect(source.text, 'cat');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
