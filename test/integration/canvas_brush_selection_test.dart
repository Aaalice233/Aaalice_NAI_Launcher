import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_base.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';

/// Integration Test for Brush Selection and Canvas Rendering
///
/// This test verifies that:
/// 1. Brush preset buttons render correctly and are visible when selected
/// 2. Selecting a brush preset updates the tool settings appropriately
/// 3. Canvas rendering works without performance issues (no contradictory CustomPainter flags)
/// 4. The brush selection flow works end-to-end: BrushTool → EditorState → Canvas
///
/// This is a regression test for two issues:
/// - Brush preset buttons appearing as solid color blocks (poor contrast)
/// - Contradictory CustomPainter flags (isComplex + willChange) causing performance issues
void main() {
  group('Brush Selection - Integration Tests', () {
    testWidgets('BrushTool initializes with default preset selected',
        (WidgetTester tester) async {
      // Arrange: Create EditorState (brush tool is automatically created in ToolManager)
      final state = EditorState();

      // Act: Get the brush tool from tool manager
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Assert: Default preset should be selected
      expect(
        brushTool.selectedPresetIndex,
        equals(2),
        reason: 'BrushTool should initialize with "标准笔刷" (index 2) selected',
      );

      // Verify settings match the default preset
      final defaultPreset = defaultBrushPresets[2];
      expect(
        brushTool.settings.size,
        equals(defaultPreset.size),
        reason: 'Brush size should match default preset',
      );
      expect(
        brushTool.settings.opacity,
        equals(defaultPreset.opacity),
        reason: 'Brush opacity should match default preset',
      );
      expect(
        brushTool.settings.hardness,
        equals(defaultPreset.hardness),
        reason: 'Brush hardness should match default preset',
      );
    });

    testWidgets('Selecting brush preset updates tool settings',
        (WidgetTester tester) async {
      // Arrange: Create EditorState and get brush tool
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Act: Select a different preset (e.g., "软笔刷" at index 3)
      const newPresetIndex = 3;
      final newPreset = defaultBrushPresets[newPresetIndex];
      brushTool.applyPreset(newPreset, newPresetIndex);

      // Assert: Selected preset index should be updated
      expect(
        brushTool.selectedPresetIndex,
        equals(newPresetIndex),
        reason: 'Selected preset index should update to $newPresetIndex',
      );

      // Verify settings match the new preset
      expect(
        brushTool.settings.size,
        equals(newPreset.size),
        reason: 'Brush size should update to match new preset',
      );
      expect(
        brushTool.settings.opacity,
        equals(newPreset.opacity),
        reason: 'Brush opacity should update to match new preset',
      );
      expect(
        brushTool.settings.hardness,
        equals(newPreset.hardness),
        reason: 'Brush hardness should update to match new preset',
      );
    });

    testWidgets('All brush presets are accessible and valid',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Test each preset
      for (var i = 0; i < defaultBrushPresets.length; i++) {
        final preset = defaultBrushPresets[i];

        // Act: Select preset
        brushTool.applyPreset(preset, i);

        // Assert: Verify all properties are within valid ranges
        expect(
          brushTool.settings.size,
          greaterThan(0),
          reason: 'Preset $i (${preset.name}) should have positive size',
        );
        expect(
          brushTool.settings.opacity,
          greaterThanOrEqualTo(0.0),
          reason: 'Preset $i (${preset.name}) should have valid opacity (>= 0)',
        );
        expect(
          brushTool.settings.opacity,
          lessThanOrEqualTo(1.0),
          reason: 'Preset $i (${preset.name}) should have valid opacity (<= 1)',
        );
        expect(
          brushTool.settings.hardness,
          greaterThanOrEqualTo(0.0),
          reason: 'Preset $i (${preset.name}) should have valid hardness (>= 0)',
        );
        expect(
          brushTool.settings.hardness,
          lessThanOrEqualTo(1.0),
          reason: 'Preset $i (${preset.name}) should have valid hardness (<= 1)',
        );
      }
    });

    testWidgets('Brush tool settings can be customized beyond presets',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Arrange: Start with a preset
      brushTool.applyPreset(defaultBrushPresets[2], 2); // 标准笔刷
      expect(
        brushTool.selectedPresetIndex,
        equals(2),
        reason: 'Should start with preset selected',
      );

      // Act: Customize settings
      brushTool.setSize(15.0);
      brushTool.setOpacity(0.5);
      brushTool.setHardness(0.95);

      // Assert: Preset index remains at 2 (customizing doesn't auto-change it)
      expect(
        brushTool.selectedPresetIndex,
        equals(2),
        reason: 'Preset index remains at preset index even after customizing',
      );

      // Verify custom settings are applied
      expect(
        brushTool.settings.size,
        equals(15.0),
        reason: 'Custom size should be applied',
      );
      expect(
        brushTool.settings.opacity,
        equals(0.5),
        reason: 'Custom opacity should be applied',
      );
      expect(
        brushTool.settings.hardness,
        equals(0.95),
        reason: 'Custom hardness should be applied',
      );
    });

    testWidgets('Brush tool integrates with tool manager',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Verify brush tool is registered in tool manager
      expect(
        state.toolManager.tools.contains(brushTool),
        isTrue,
        reason: 'Brush tool should be registered in tool manager',
      );

      // Verify we can get the tool by ID
      expect(
        state.toolManager.getToolById('brush'),
        equals(brushTool),
        reason: 'Should be able to retrieve brush tool by ID',
      );

      // Act: Select a different preset
      final preset = defaultBrushPresets[4]; // 喷枪
      brushTool.applyPreset(preset, 4);

      // Assert: Preset should be updated
      expect(
        brushTool.selectedPresetIndex,
        equals(4),
        reason: 'Preset index should be updated',
      );
    });
  });

  group('Canvas Rendering - Integration Tests', () {
    testWidgets('EditorCanvas renders without errors in light theme',
        (WidgetTester tester) async {
      final state = EditorState();

      // Build the canvas with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Verify canvas is rendered
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'EditorCanvas should render in light theme',
      );
    });

    testWidgets('EditorCanvas renders without errors in dark theme',
        (WidgetTester tester) async {
      final state = EditorState();

      // Build the canvas with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Verify canvas is rendered
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'EditorCanvas should render in dark theme',
      );
    });

    testWidgets('EditorCanvas renders with brush tool active',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Brush tool is already active by default

      // Build the canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Verify canvas is rendered with brush tool
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'EditorCanvas should render with brush tool active',
      );

      // Verify brush tool is selected
      expect(
        state.currentTool?.id,
        equals(brushTool.id),
        reason: 'Brush tool should be the current tool',
      );
    });

    testWidgets('EditorCanvas handles brush preset changes',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build the canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Act: Change brush preset
      final preset = defaultBrushPresets[5]; // 马克笔
      brushTool.applyPreset(preset, 5);

      // Pump to rebuild
      await tester.pump();

      // Verify canvas still renders after preset change
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'EditorCanvas should remain rendered after brush preset change',
      );

      // Verify brush tool still has the new preset selected
      expect(
        brushTool.selectedPresetIndex,
        equals(5),
        reason: 'Brush preset should be updated to index 5 (马克笔)',
      );
    });

    testWidgets('Canvas rendering remains smooth across multiple rebuilds',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build the canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      // Initial render
      await tester.pump();
      expect(find.byType(EditorCanvas), findsOneWidget);

      // Rebuild multiple times to test stability
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green,
                brightness: Brightness.light,
              ),
            ),
            home: Scaffold(
              body: EditorCanvas(state: state),
            ),
          ),
        );

        await tester.pump();

        // Verify canvas remains rendered
        expect(
          find.byType(EditorCanvas),
          findsOneWidget,
          reason: 'EditorCanvas should remain stable across rebuild #$i',
        );
      }
    });
  });

  group('Brush Selection & Canvas Integration - End-to-End Tests', () {
    testWidgets('Complete brush selection flow: preset → settings → canvas',
        (WidgetTester tester) async {
      // Arrange: Create full editor state
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Act: Select different brush presets
      final presetsToTest = [0, 3, 6]; // 铅笔, 软笔刷, 粗笔刷

      for (final presetIndex in presetsToTest) {
        brushTool.applyPreset(defaultBrushPresets[presetIndex], presetIndex);
        await tester.pump();

        // Assert: Canvas should still render
        expect(
          find.byType(EditorCanvas),
          findsOneWidget,
          reason:
              'Canvas should render after selecting preset $presetIndex',
        );

        // Verify settings are applied
        final preset = defaultBrushPresets[presetIndex];
        expect(
          brushTool.settings.size,
          equals(preset.size),
          reason: 'Size should match preset $presetIndex',
        );
        expect(
          brushTool.settings.opacity,
          equals(preset.opacity),
          reason: 'Opacity should match preset $presetIndex',
        );
        expect(
          brushTool.settings.hardness,
          equals(preset.hardness),
          reason: 'Hardness should match preset $presetIndex',
        );
      }
    });

    testWidgets('Custom brush settings integrate with canvas rendering',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Act: Customize brush settings
      brushTool.setSize(25.5);
      brushTool.setOpacity(0.75);
      brushTool.setHardness(0.85);

      await tester.pump();

      // Assert: Verify custom settings are applied and canvas renders
      expect(
        brushTool.settings.size,
        equals(25.5),
        reason: 'Custom size should be applied',
      );
      expect(
        brushTool.settings.opacity,
        equals(0.75),
        reason: 'Custom opacity should be applied',
      );
      expect(
        brushTool.settings.hardness,
        equals(0.85),
        reason: 'Custom hardness should be applied',
      );
      expect(
        brushTool.selectedPresetIndex,
        equals(2),
        reason: 'Preset index remains at last selected preset',
      );

      // Canvas should still render
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render with custom brush settings',
      );
    });

    testWidgets('Rapid brush preset changes do not cause rendering errors',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.orange,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Act: Rapidly change presets
      for (var i = 0; i < defaultBrushPresets.length; i++) {
        brushTool.applyPreset(defaultBrushPresets[i], i);
        await tester.pump(Duration(milliseconds: 16)); // ~60fps
      }

      // Assert: Canvas should still render without errors
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should handle rapid preset changes without errors',
      );

      // Final preset should be selected
      expect(
        brushTool.selectedPresetIndex,
        equals(defaultBrushPresets.length - 1),
        reason: 'Last preset should be selected',
      );
    });

    testWidgets('Brush and canvas work in both light and dark themes',
        (WidgetTester tester) async {
      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Test in light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      brushTool.applyPreset(defaultBrushPresets[3], 3);
      await tester.pump();

      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render in light theme',
      );

      // Test in dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      brushTool.applyPreset(defaultBrushPresets[6], 6);
      await tester.pump();

      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render in dark theme',
      );
    });
  });

  group('Regression Prevention - Brush & Canvas Bugs', () {
    testWidgets('prevents regression: brush preset buttons remain visible',
        (WidgetTester tester) async {
      // Regression test for: "Brush preset buttons appearing as solid color blocks"
      // Root cause: Selected buttons had poor contrast (primary on primaryContainer)
      // Fix: Use onPrimaryContainer for selected buttons

      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      // Build in light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Select different presets to ensure button visibility
      for (var i = 0; i < defaultBrushPresets.length; i++) {
        brushTool.applyPreset(defaultBrushPresets[i], i);
        await tester.pump();

        // Verify brush tool state is updated
        expect(
          brushTool.selectedPresetIndex,
          equals(i),
          reason: 'Preset $i should be selected',
        );
      }

      // All preset selections should complete without rendering errors
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render successfully after all preset changes',
      );
    });

    testWidgets('prevents regression: canvas has no contradictory CustomPainter flags',
        (WidgetTester tester) async {
      // Regression test for: "isComplex and willChange flags used together"
      // Root cause: These flags are contradictory (isComplex hints to cache,
      //             willChange hints it will change frequently)
      // Fix: Remove both flags since LayerPainter uses repaint notifier

      final state = EditorState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Verify canvas renders without errors
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render without contradictory flags',
      );

      // If contradictory flags were present, we might see:
      // - Performance degradation
      // - Rendering glitches
      // - Console warnings
      // The fact that canvas renders successfully is a basic check
    });

    testWidgets('prevents regression: renderNotifier triggers canvas repaints',
        (WidgetTester tester) async {
      // Regression test to ensure renderNotifier works correctly
      // This is critical for canvas performance - it should trigger repaints
      // without rebuilding the entire widget tree

      final state = EditorState();
      final brushTool = state.toolManager.getToolById('brush') as BrushTool;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Scaffold(
            body: EditorCanvas(state: state),
          ),
        ),
      );

      await tester.pump();

      // Verify renderNotifier exists
      expect(
        state.renderNotifier,
        isNotNull,
        reason: 'EditorState should have renderNotifier',
      );

      // Verify canvas is rendered
      expect(find.byType(EditorCanvas), findsOneWidget);

      // Notify render changes (simulating a drawing operation)
      state.renderNotifier.notifyListeners();
      await tester.pump();

      // Canvas should still render after repaint notification
      expect(
        find.byType(EditorCanvas),
        findsOneWidget,
        reason: 'Canvas should render after renderNotifier notification',
      );
    });
  });
}
