import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_context_menu.dart';
import 'package:nai_launcher/presentation/widgets/common/pro_context_menu.dart';

void main() {
  testWidgets('menu items support arrow traversal and keyboard activation', (
    tester,
  ) async {
    String? selected;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ProContextMenu(
                position: const Offset(16, 16),
                items: const [
                  ProMenuItem(id: 'first', label: 'First'),
                  ProMenuItem.divider(),
                  ProMenuItem(id: 'second', label: 'Second'),
                ],
                onSelect: (item) => selected = item.id,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, 'second');
    expect(find.bySemanticsLabel('Second'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('pointer and keyboard activate the same command', (tester) async {
    var activations = 0;
    Widget buildMenu() => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ProContextMenu(
              position: const Offset(16, 16),
              items: [
                ProMenuItem(
                  id: 'copy',
                  label: 'Copy',
                  onTap: () => activations++,
                ),
              ],
              onSelect: (item) => item.onTap?.call(),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(buildMenu());
    await tester.tap(find.text('Copy'));
    expect(activations, 1);

    await tester.pumpWidget(buildMenu());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activations, 2);
  });

  testWidgets('long scaled menu stays inside safe viewport edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    ImageCardContextMenuRoute(
                      position: const Offset(350, 310),
                      items: const [
                        ProMenuItem(
                          id: 'long',
                          label:
                              'A very long localized context menu command label',
                        ),
                        ProMenuItem(id: 'next', label: 'Next command'),
                      ],
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(
      find.descendant(
        of: find.byType(ProContextMenu),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.top, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(344));
    expect(rect.bottom, lessThanOrEqualTo(304));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hybrid touch capability preserves 48dp menu targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.keyboard,
            touchAvailable: true,
            precisePointerAvailable: true,
          ),
          child: Scaffold(
            body: Stack(
              children: [
                ProContextMenu(
                  position: Offset(16, 16),
                  items: [ProMenuItem(id: 'copy', label: 'Copy')],
                  onSelect: _ignoreSelection,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(48),
    );
  });
}

void _ignoreSelection(ProMenuItem _) {}
