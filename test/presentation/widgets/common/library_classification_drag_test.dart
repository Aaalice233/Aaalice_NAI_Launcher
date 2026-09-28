import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_source.dart';
import 'package:nai_launcher/presentation/widgets/common/library_classification_drag.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import '../../../helpers/card_drop_test_utils.dart';

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('classification resolves every member before changing any item', (
    tester,
  ) async {
    final accepted = <String>[];
    final resolved = <String>[];
    await tester.pumpWidget(
      app(
        LibraryClassificationDropTarget<String>(
          kind: AgentChatResourceKind.vibeLibraryEntry,
          resolve: (id) {
            resolved.add(id);
            return id;
          },
          onAccept: (id) {
            expect(resolved, ['a', 'b']);
            accepted.add(id);
          },
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    final session = TestCardDropSession([
      TestCardDropItem.resource('a'),
      TestCardDropItem.resource('b'),
    ]);
    addTearDown(session.dispose);
    final target = tester.widget<DropRegion>(find.byType(DropRegion));
    expect(
      await target.onDropOver(
        DropOverEvent(session: session, position: testCardDropPosition),
      ),
      DropOperation.copy,
    );
    await target.onPerformDrop(
      PerformDropEvent(
        session: session,
        position: testCardDropPosition,
        acceptedOperation: DropOperation.copy,
      ),
    );
    expect(accepted, ['a', 'b']);
  });

  testWidgets('mixed types and empty sets reject the entire set', (
    tester,
  ) async {
    var writes = 0;
    await tester.pumpWidget(
      app(
        LibraryClassificationDropTarget<String>(
          kind: AgentChatResourceKind.vibeLibraryEntry,
          resolve: (id) => id,
          onAccept: (_) {
            writes++;
          },
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    final target = tester.widget<DropRegion>(find.byType(DropRegion));
    for (final items in <List<DropItem>>[
      [],
      [
        TestCardDropItem.resource('a'),
        TestCardDropItem.resource(
          'b',
          kind: AgentChatResourceKind.tagLibraryEntry,
        ),
      ],
    ]) {
      final session = TestCardDropSession(items);
      addTearDown(session.dispose);
      expect(
        await target.onDropOver(
          DropOverEvent(session: session, position: testCardDropPosition),
        ),
        DropOperation.none,
      );
    }
    expect(writes, 0);
  });

  testWidgets('missing member aborts before the first mutation', (
    tester,
  ) async {
    final accepted = <String>[];
    await tester.pumpWidget(
      app(
        LibraryClassificationDropTarget<String>(
          kind: AgentChatResourceKind.vibeLibraryEntry,
          resolve: (id) => id == 'missing' ? null : id,
          onAccept: accepted.add,
          child: const SizedBox(width: 100, height: 60),
        ),
      ),
    );
    final session = TestCardDropSession([
      TestCardDropItem.resource('a'),
      TestCardDropItem.resource('missing'),
    ]);
    addTearDown(session.dispose);
    final target = tester.widget<DropRegion>(find.byType(DropRegion));
    await target.onPerformDrop(
      PerformDropEvent(
        session: session,
        position: testCardDropPosition,
        acceptedOperation: DropOperation.copy,
      ),
    );
    expect(accepted, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('active drop uses the row single highlight surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        LibraryClassificationDropTarget<String>(
          kind: AgentChatResourceKind.vibeLibraryEntry,
          resolve: (id) => id,
          onAccept: (_) {},
          child: GallerySidebarNavigationItem(
            key: const ValueKey('row'),
            icon: Icons.folder_outlined,
            label: 'Category',
            count: 1,
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );
    final session = TestCardDropSession([TestCardDropItem.resource('a')]);
    addTearDown(session.dispose);
    final target = tester.widget<DropRegion>(find.byType(DropRegion));
    await target.onDropOver(
      DropOverEvent(session: session, position: testCardDropPosition),
    );
    await tester.pump();
    final row = find.byKey(const ValueKey('row'));
    final surface = tester.widget<AnimatedContainer>(
      find.descendant(of: row, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (surface.decoration as BoxDecoration).color,
      Theme.of(tester.element(row)).colorScheme.primary.withValues(alpha: .12),
    );
    expect(
      find.ancestor(
        of: find.text('Category'),
        matching: find.byType(AnimatedContainer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('touch source leaves scrolling to the viewport', (tester) async {
    await tester.pumpWidget(
      app(
        InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: CardDragSource(
            resource: () => const CardDragResource(id: 'a', fileName: 'a'),
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<DragItemWidget>(find.byType(DragItemWidget))
          .allowedOperations(),
      isEmpty,
    );
    expect(
      tester
          .widget<DraggableWidget>(find.byType(DraggableWidget))
          .isLocationDraggable(Offset.zero),
      isFalse,
    );
  });
}
