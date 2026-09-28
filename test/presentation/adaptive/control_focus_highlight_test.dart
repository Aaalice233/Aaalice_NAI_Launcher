import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/compact_icon_button.dart';
import 'package:nai_launcher/presentation/widgets/common/safe_dropdown.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_dropdown.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';

void main() {
  for (final kind in ['plain', 'safe', 'themed']) {
    testWidgets(
      '$kind dropdown clears pointer emphasis and keeps keyboard focus',
      (tester) async {
        var value = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: InteractionPolicyScope(
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 240,
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        const items = [
                          DropdownMenuItem(value: 1, child: Text('First')),
                          DropdownMenuItem(value: 2, child: Text('Second')),
                        ];
                        void select(int? next) => setState(() => value = next!);
                        return switch (kind) {
                          'safe' => SafeDropdown<int>(
                            value: value,
                            items: items,
                            onChanged: select,
                          ),
                          'themed' => ThemedDropdown<int>(
                            value: value,
                            items: items,
                            onChanged: select,
                          ),
                          _ => DropdownButton<int>(
                            value: value,
                            items: items,
                            onChanged: select,
                          ),
                        };
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        final trigger = find.byType(DropdownButton<int>);
        await mouse.addPointer(location: tester.getCenter(trigger));
        await mouse.down(tester.getCenter(trigger));
        await mouse.up();
        await tester.pumpAndSettle();
        final option = find.text('Second').last;
        await mouse.moveTo(tester.getCenter(option));
        await mouse.down(tester.getCenter(option));
        await mouse.up();
        await mouse.moveTo(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(value, 2);
        expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
        final focus = FocusManager.instance.primaryFocus;
        expect(focus, isNotNull);
        Color borderColor() =>
            ((tester
                                .widget<AnimatedContainer>(
                                  find.descendant(
                                    of: find.byType(InputSurfaceContainer),
                                    matching: find.byType(AnimatedContainer),
                                  ),
                                )
                                .decoration!
                            as BoxDecoration)
                        .border!
                    as Border)
                .top
                .color;
        if (kind != 'plain') expect(borderColor().a, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(
          FocusManager.instance.highlightMode,
          FocusHighlightMode.traditional,
        );
        if (kind != 'plain') expect(borderColor().a, greaterThan(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('First'), findsWidgets);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.macOS,
      }),
    );
  }
  testWidgets(
    'mouse and keyboard alternate focus indication without losing focus',
    (tester) async {
      final previousStrategy = FocusManager.instance.highlightStrategy;
      addTearDown(
        () => FocusManager.instance.highlightStrategy = previousStrategy,
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      late InteractionPolicy policy;
      await tester.pumpWidget(
        MaterialApp(
          home: InteractionPolicyScope(
            child: Builder(
              builder: (context) {
                policy = context.interactionPolicy;
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      focusNode: focus,
                      onPressed: () {},
                      child: const Text('Action'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(10, 10));
      for (var round = 0; round < 2; round++) {
        await mouse.moveTo(tester.getCenter(find.text('Action')));
        await mouse.down(tester.getCenter(find.text('Action')));
        await mouse.up();
        await mouse.moveTo(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(policy.modality, InteractionModality.pointer);
        expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(policy.keyboardNavigationActive, isTrue);
        expect(
          FocusManager.instance.highlightMode,
          FocusHighlightMode.traditional,
        );
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'compact menu trigger returns to idle after a mouse selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InteractionPolicyScope(
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: CompactIconButton(
                    icon: Icons.more_horiz,
                    label: 'Open',
                    onPressed: () => showMenu<int>(
                      context: context,
                      position: const RelativeRect.fromLTRB(300, 350, 300, 100),
                      items: const [
                        PopupMenuItem(value: 1, child: Text('Choose')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(TextButton);
      final material = find.descendant(
        of: button,
        matching: find.byType(Material),
      );
      await tester.pumpAndSettle();
      final idle = tester.widget<Material>(material).color;
      Focus.of(tester.element(find.text('Open'))).requestFocus();
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(button));
      await mouse.down(tester.getCenter(button));
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('Choose')));
      await mouse.down(tester.getCenter(find.text('Choose')));
      await mouse.up();
      await mouse.moveTo(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(material).color, idle);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );
}
