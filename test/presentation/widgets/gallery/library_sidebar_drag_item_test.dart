import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_tree_drop_slot.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/gallery/library_sidebar_drag_item.dart';

void main() {
  Widget host({
    required Future<bool> Function(String, GalleryTreeDropSlot) onDrop,
    bool touch = false,
    bool children = true,
    bool accepts = true,
    VoidCallback? onTap,
    VoidCallback? onExpand,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: InteractionPolicyScope(
      initialPolicy: InteractionPolicy(
        modality: touch
            ? InteractionModality.touch
            : InteractionModality.pointer,
        touchAvailable: touch,
        precisePointerAvailable: !touch,
      ),
      child: Scaffold(
        body: SizedBox(
          width: 260,
          child: Column(
            children: [
              for (final id in ['a', 'b'])
                LibrarySidebarDragItem<String>(
                  key: ValueKey(id),
                  item: id,
                  label: id,
                  icon: Icons.folder_outlined,
                  allowChildren: children,
                  canDrop: (source, slot) => accepts && source != id,
                  onDrop: onDrop,
                  onExpand: id == 'b' ? onExpand : null,
                  child: SizedBox(
                    height: 64,
                    child: InkWell(
                      onTap: onTap,
                      child: Center(child: Text(id)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('drop overlays preserve row taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(onDrop: (_, _) async => true, onTap: () => taps++),
    );
    await tester.tap(find.text('b'));
    await tester.pump();
    expect(taps, 1);
  });

  for (final slot in GalleryTreeDropSlot.values) {
    testWidgets('pointer drop selects the $slot zone', (tester) async {
      final drops = <(String, GalleryTreeDropSlot)>[];
      await tester.pumpWidget(
        host(
          onDrop: (id, slot) async {
            drops.add((id, slot));
            return true;
          },
        ),
      );
      final target = tester.getRect(find.byKey(const ValueKey('b')));
      final position = switch (slot) {
        GalleryTreeDropSlot.before => target.topCenter + const Offset(0, 3),
        GalleryTreeDropSlot.child => target.center,
        GalleryTreeDropSlot.after => target.bottomCenter - const Offset(0, 3),
      };
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(position);
      await tester.pump();
      if (slot != GalleryTreeDropSlot.child) {
        expect(
          find.byKey(ValueKey('sidebar-drop-indicator-${slot.name}')),
          findsOneWidget,
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(drops, [('a', slot)]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('flat categories use two insertion zones on touch', (
    tester,
  ) async {
    final drops = <GalleryTreeDropSlot>[];
    await tester.pumpWidget(
      host(
        touch: true,
        children: false,
        onDrop: (_, slot) async {
          drops.add(slot);
          return true;
        },
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('a'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final target = tester.getRect(find.byKey(const ValueKey('b')));
    await gesture.moveTo(target.center + const Offset(0, 3));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(drops, [GalleryTreeDropSlot.after]);
  });

  testWidgets('rejected drops do not invoke persistence', (tester) async {
    var drops = 0;
    await tester.pumpWidget(
      host(
        accepts: false,
        onDrop: (_, _) async {
          drops++;
          return true;
        },
      ),
    );
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('a'))),
      const Offset(0, 64),
    );
    await tester.pumpAndSettle();
    expect(drops, 0);
  });

  testWidgets('leaving a child zone cancels pending auto expansion', (
    tester,
  ) async {
    var expansions = 0;
    await tester.pumpWidget(
      host(onDrop: (_, _) async => true, onExpand: () => expansions++),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('a'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('b'))));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 900));
    expect(expansions, 0);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });
}
