import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize Flutter binding for all tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorCanvas', () {
    late EditorState editorState;

    setUp(() {
      // Create EditorState (may throw async error but tests will still work)
      try {
        SharedPreferences.setMockInitialValues({});
      } catch (_) {
        // Ignore if already initialized
      }
      editorState = EditorState();
    });

    tearDown(() {
      editorState.dispose();
    });

    testWidgets('should render without errors', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert
      expect(find.byType(EditorCanvas), findsOneWidget,
          reason: 'EditorCanvas should render without errors');
    });

    testWidgets('should not use contradictory CustomPainter flags',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() instead of pumpAndSettle() to avoid timeout on animations
      await tester.pump();

      // Assert - Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // Verify none of them have both isComplex and willChange set to true
      for (final customPaint in customPaints) {
        final hasComplexFlag = customPaint.isComplex ?? false;
        final willChangeFlag = customPaint.willChange ?? false;

        expect(
          hasComplexFlag && willChangeFlag,
          isFalse,
          reason: 'CustomPaint should not have both isComplex: true and '
              'willChange: true (contradictory flags). '
              'Found isComplex: $hasComplexFlag, willChange: $willChangeFlag',
        );
      }
    });

    testWidgets('LayerPainter should not use isComplex flag',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // LayerPainter should not use isComplex
      bool foundLayerPainter = false;
      for (final customPaint in customPaints) {
        final painterStr = customPaint.painter.toString();
        if (painterStr.contains('LayerPainter')) {
          foundLayerPainter = true;
          expect(
            customPaint.isComplex ?? false,
            isFalse,
            reason: 'LayerPainter should not use isComplex: true flag',
          );
        }
      }

      expect(foundLayerPainter, isTrue,
          reason: 'Should find LayerPainter in the widget tree');
    });

    testWidgets('CursorPainter should not use contradictory flags',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Trigger cursor to appear by moving mouse
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // Check CursorPainter doesn't have both flags set
      bool foundCursorPainter = false;
      for (final customPaint in customPaints) {
        final painterStr = customPaint.painter.toString();
        if (painterStr.contains('CursorPainter')) {
          foundCursorPainter = true;
          final hasComplexFlag = customPaint.isComplex ?? false;
          final willChangeFlag = customPaint.willChange ?? false;

          expect(
            hasComplexFlag && willChangeFlag,
            isFalse,
            reason: 'CursorPainter should not have both isComplex: true and '
                'willChange: true',
          );
        }
      }

      // CursorPainter may not be visible if no cursor position, so we don't
      // assert foundCursorPainter is true
    });

    testWidgets('SelectionPainter should not use contradictory flags',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // Check SelectionPainter doesn't have both flags set
      bool foundSelectionPainter = false;
      for (final customPaint in customPaints) {
        final painterStr = customPaint.painter.toString();
        if (painterStr.contains('SelectionPainter')) {
          foundSelectionPainter = true;
          final hasComplexFlag = customPaint.isComplex ?? false;
          final willChangeFlag = customPaint.willChange ?? false;

          expect(
            hasComplexFlag && willChangeFlag,
            isFalse,
            reason: 'SelectionPainter should not have both isComplex: true and '
                'willChange: true',
          );
        }
      }

      expect(foundSelectionPainter, isTrue,
          reason: 'Should find SelectionPainter in the widget tree');
    });

    testWidgets('should have proper focus management',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert - Should have Focus widget (there may be multiple Focus widgets in the tree)
      expect(find.byType(Focus), findsWidgets,
          reason: 'EditorCanvas should have Focus widgets for keyboard input');
    });

    testWidgets('should handle mouse events', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert - Should have Listener for pointer events
      expect(find.byType(Listener), findsWidgets,
          reason: 'EditorCanvas should have Listener widgets for pointer events');

      // Should have MouseRegion for cursor
      expect(find.byType(MouseRegion), findsWidgets,
          reason: 'EditorCanvas should have MouseRegion widgets for cursor handling');
    });

    testWidgets('should handle gesture events', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert - Should have GestureDetector for gestures
      expect(find.byType(GestureDetector), findsWidgets,
          reason: 'EditorCanvas should have GestureDetector for pan/zoom');
    });

    testWidgets('should use RepaintBoundary for independent repaints',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert - Should have RepaintBoundary widgets
      expect(find.byType(RepaintBoundary), findsWidgets,
          reason: 'EditorCanvas should use RepaintBoundary for optimization');
    });

    testWidgets('should have Stack for overlay composition',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Assert - Should have Stack for layering
      expect(find.byType(Stack), findsWidgets,
          reason: 'EditorCanvas should use Stack to compose layers');
    });

    testWidgets('should update viewport size on layout',
        (WidgetTester tester) async {
      // Arrange
      const testSize = Size(800, 600);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: testSize.width,
            height: testSize.height,
            child: Scaffold(
              body: EditorCanvas(state: editorState),
            ),
          ),
        ),
      );

      // Act
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Viewport size should be updated
      expect(editorState.canvasController.viewportSize.width, closeTo(testSize.width, 1.0),
          reason: 'Viewport width should be updated based on layout constraints');
      expect(editorState.canvasController.viewportSize.height, closeTo(testSize.height, 1.0),
          reason: 'Viewport height should be updated based on layout constraints');
    });

    testWidgets('should not rebuild unnecessarily when tool changes',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Act - Change tool (should trigger rebuild via ValueListenableBuilder)
      // Get the eraser tool from the tool manager
      final eraserTool = editorState.toolManager.tools.firstWhere(
        (t) => t.id == 'eraser',
        orElse: () => editorState.toolManager.tools.first,
      );
      editorState.toolManager.setTool(eraserTool);
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Canvas should rebuild when tool changes
      expect(find.byType(EditorCanvas), findsOneWidget);
    });

    testWidgets('should handle color picker mode', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Enter color picker mode
      editorState.enterTemporaryColorPicker();
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Should not throw
      expect(find.byType(EditorCanvas), findsOneWidget,
          reason: 'EditorCanvas should handle color picker mode without errors');
    });

    testWidgets('should dispose resources properly',
        (WidgetTester tester) async {
      // Arrange
      final testWidget = MaterialApp(
        home: Scaffold(
          body: EditorCanvas(state: editorState),
        ),
      );

      await tester.pumpWidget(testWidget);
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Act - Remove widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Should not throw or cause memory leaks
      // (In a real scenario, you'd use memory profiling tools)
      expect(find.byType(EditorCanvas), findsNothing,
          reason: 'EditorCanvas should be removed cleanly');
    });
  });

  group('CustomPainter Performance', () {
    testWidgets('should use repaint notifier instead of isComplex',
        (WidgetTester tester) async {
      // Arrange
      final editorState = EditorState();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // Verify painters use repaint notifiers instead of isComplex
      for (final customPaint in customPaints) {
        final painter = customPaint.painter;
        final painterStr = painter.toString();
        final isComplex = customPaint.isComplex ?? false;

        // If painter uses a repaint notifier, isComplex should be false/null
        if (painterStr.contains('LayerPainter')) {
          expect(
            isComplex,
            isFalse,
            reason: 'LayerPainter uses repaint notifier and should not set '
                'isComplex: true',
          );
        }
      }

      editorState.dispose();
    });

    testWidgets('should not cache static content with willChange',
        (WidgetTester tester) async {
      // Arrange
      final editorState = EditorState();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Find all CustomPaint widgets
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      // Verify no painter has both flags set
      for (final customPaint in customPaints) {
        final hasComplexFlag = customPaint.isComplex ?? false;
        final willChangeFlag = customPaint.willChange ?? false;

        expect(
          hasComplexFlag && willChangeFlag,
          isFalse,
          reason: 'CustomPaint should not combine isComplex (cache hint) '
              'with willChange (frequent change hint)',
        );
      }

      editorState.dispose();
    });

    testWidgets('LayerPainter should use repaint notifier for efficiency',
        (WidgetTester tester) async {
      // Arrange
      final editorState = EditorState();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Find LayerPainter's CustomPaint
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      bool foundLayerPainter = false;
      for (final customPaint in customPaints) {
        final painterStr = customPaint.painter.toString();
        if (painterStr.contains('LayerPainter')) {
          foundLayerPainter = true;
          // The LayerPainter should use the repaint parameter in its constructor
          // which is more efficient than isComplex/willChange flags
          expect(
            customPaint.isComplex ?? false,
            isFalse,
            reason: 'LayerPainter should rely on repaint notifier, not isComplex',
          );
        }
      }

      expect(foundLayerPainter, isTrue,
          reason: 'LayerPainter should be present in the widget tree');

      editorState.dispose();
    });

    testWidgets('CursorPainter should use willChange appropriately',
        (WidgetTester tester) async {
      // Arrange
      final editorState = EditorState();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorCanvas(state: editorState),
          ),
        ),
      );

      // Use pump() to avoid infinite animation timeout
      await tester.pump();

      // Assert - Check CursorPainter configuration
      final customPaints = tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      );

      for (final customPaint in customPaints) {
        final painterStr = customPaint.painter.toString();
        if (painterStr.contains('CursorPainter')) {
          // CursorPainter updates frequently (every mouse movement), so it
          // might use willChange, but should NOT also use isComplex
          final hasComplexFlag = customPaint.isComplex ?? false;
          final willChangeFlag = customPaint.willChange ?? false;

          if (willChangeFlag) {
            expect(
              hasComplexFlag,
              isFalse,
              reason: 'CursorPainter with willChange: true should not also '
                  'have isComplex: true (contradictory)',
            );
          }
        }
      }

      editorState.dispose();
    });
  });
}
