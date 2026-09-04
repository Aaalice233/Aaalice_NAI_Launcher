import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/library_classification_drag.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

void main() {
  testWidgets(
    'desktop entry can be dragged to an enabled classification target',
    (tester) async {
      String? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Scaffold(
              body: Column(
                children: [
                  const LibraryClassificationDragSource<String>(
                    data: 'entry-1',
                    label: 'Entry',
                    child: ColoredBox(
                      key: ValueKey('source'),
                      color: Colors.transparent,
                      child: SizedBox(width: 100, height: 60),
                    ),
                  ),
                  LibraryClassificationDropTarget<String>(
                    onAccept: (value) => accepted = value,
                    child: const SizedBox(
                      key: ValueKey('target'),
                      width: 100,
                      height: 60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey('source')),
        const Offset(0, 70),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(accepted, 'entry-1');
    },
  );

  testWidgets(
    'active drop uses the classification row single highlight surface',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Scaffold(
              body: Column(
                children: [
                  LibraryClassificationDropTarget<String>(
                    onAccept: (_) {},
                    child: LibraryClassificationDropTargetStatus(
                      isAccepting: true,
                      child: GallerySidebarNavigationItem(
                        key: const ValueKey('single-highlight-target'),
                        icon: Icons.folder_outlined,
                        label: 'Category',
                        count: 1,
                        isSelected: false,
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final rowSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('single-highlight-target')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = rowSurface.decoration! as BoxDecoration;
      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey('single-highlight-target'))),
      );
      expect(
        decoration.color,
        theme.colorScheme.primary.withValues(alpha: 0.12),
      );
      expect(
        find.ancestor(
          of: find.text('Category'),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'touch uses explicit actions instead of a competing drag gesture',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InteractionPolicyScope(
            initialPolicy: InteractionPolicy(
              modality: InteractionModality.touch,
              touchAvailable: true,
              precisePointerAvailable: false,
            ),
            child: LibraryClassificationDragSource<String>(
              data: 'entry-1',
              label: 'Entry',
              child: SizedBox(width: 100, height: 60),
            ),
          ),
        ),
      );

      final draggable = tester.widget<Draggable<String>>(
        find.byType(Draggable<String>),
      );
      expect(draggable.maxSimultaneousDrags, 0);
    },
  );
}
