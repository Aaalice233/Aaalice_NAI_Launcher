import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_base.dart';

void main() {
  // Initialize Flutter binding for all tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrushPreset', () {
    test('should create preset with correct properties', () {
      // Arrange & Act
      const preset = BrushPreset(
        name: 'Test Brush',
        icon: Icons.brush,
        size: 10.0,
        opacity: 0.8,
        hardness: 0.5,
      );

      // Assert
      expect(preset.name, equals('Test Brush'),
          reason: 'Preset name should match provided value');
      expect(preset.icon, equals(Icons.brush),
          reason: 'Preset icon should match provided value');
      expect(preset.size, equals(10.0),
          reason: 'Preset size should match provided value');
      expect(preset.opacity, equals(0.8),
          reason: 'Preset opacity should match provided value');
      expect(preset.hardness, equals(0.5),
          reason: 'Preset hardness should match provided value');
    });

    test('toSettings should convert to BrushSettings correctly', () {
      // Arrange
      const preset = BrushPreset(
        name: 'Test Brush',
        icon: Icons.brush,
        size: 25.0,
        opacity: 0.7,
        hardness: 0.9,
      );

      // Act
      final settings = preset.toSettings();

      // Assert
      expect(settings.size, equals(25.0),
          reason: 'Settings size should match preset size');
      expect(settings.opacity, equals(0.7),
          reason: 'Settings opacity should match preset opacity');
      expect(settings.hardness, equals(0.9),
          reason: 'Settings hardness should match preset hardness');
    });
  });

  group('BrushTool', () {
    late BrushTool brushTool;

    setUp(() {
      brushTool = BrushTool();
    });

    test('should have correct id, name, icon, and shortcut', () {
      // Assert
      expect(brushTool.id, equals('brush'),
          reason: 'Tool id should be "brush"');
      expect(brushTool.name, equals('画笔'),
          reason: 'Tool name should be "画笔"');
      expect(brushTool.icon, equals(Icons.brush),
          reason: 'Tool icon should be Icons.brush');
      expect(brushTool.shortcutKey, equals(LogicalKeyboardKey.keyB),
          reason: 'Tool shortcut should be B key');
      expect(brushTool.isPaintTool, isTrue,
          reason: 'Brush tool should be a paint tool');
    });

    test('should start with default selected preset index', () {
      // Assert
      expect(brushTool.selectedPresetIndex, equals(2),
          reason: 'Default selected preset should be index 2 (标准笔刷)');
    });

    test('applyPreset should update settings and selected index', () {
      // Arrange
      const preset = BrushPreset(
        name: 'Test Brush',
        icon: Icons.brush,
        size: 30.0,
        opacity: 0.6,
        hardness: 0.4,
      );

      // Act
      brushTool.applyPreset(preset, 5);

      // Assert
      expect(brushTool.settings.size, equals(30.0),
          reason: 'Settings size should be updated to preset size');
      expect(brushTool.settings.opacity, equals(0.6),
          reason: 'Settings opacity should be updated to preset opacity');
      expect(brushTool.settings.hardness, equals(0.4),
          reason: 'Settings hardness should be updated to preset hardness');
      expect(brushTool.selectedPresetIndex, equals(5),
          reason: 'Selected preset index should be updated');
    });

    test('setSelectedPresetIndex should update index without changing settings',
        () {
      // Arrange
      brushTool.applyPreset(defaultBrushPresets[0], 0);

      // Act
      brushTool.setSelectedPresetIndex(3);

      // Assert
      expect(brushTool.selectedPresetIndex, equals(3),
          reason: 'Selected preset index should be updated');
      expect(brushTool.settings.size, equals(defaultBrushPresets[0].size),
          reason: 'Settings should remain unchanged');
    });

    test('setSize should clamp value between 1.0 and 500.0', () {
      // Act & Assert - Below minimum
      brushTool.setSize(0.5);
      expect(brushTool.settings.size, equals(1.0),
          reason: 'Size should be clamped to minimum 1.0');

      // Act & Assert - Above maximum
      brushTool.setSize(600.0);
      expect(brushTool.settings.size, equals(500.0),
          reason: 'Size should be clamped to maximum 500.0');

      // Act & Assert - Within range
      brushTool.setSize(50.0);
      expect(brushTool.settings.size, equals(50.0),
          reason: 'Size should remain unchanged when within range');
    });

    test('setOpacity should clamp value between 0.0 and 1.0', () {
      // Act & Assert - Below minimum
      brushTool.setOpacity(-0.5);
      expect(brushTool.settings.opacity, equals(0.0),
          reason: 'Opacity should be clamped to minimum 0.0');

      // Act & Assert - Above maximum
      brushTool.setOpacity(1.5);
      expect(brushTool.settings.opacity, equals(1.0),
          reason: 'Opacity should be clamped to maximum 1.0');

      // Act & Assert - Within range
      brushTool.setOpacity(0.7);
      expect(brushTool.settings.opacity, equals(0.7),
          reason: 'Opacity should remain unchanged when within range');
    });

    test('setHardness should clamp value between 0.0 and 1.0', () {
      // Act & Assert - Below minimum
      brushTool.setHardness(-0.2);
      expect(brushTool.settings.hardness, equals(0.0),
          reason: 'Hardness should be clamped to minimum 0.0');

      // Act & Assert - Above maximum
      brushTool.setHardness(1.8);
      expect(brushTool.settings.hardness, equals(1.0),
          reason: 'Hardness should be clamped to maximum 1.0');

      // Act & Assert - Within range
      brushTool.setHardness(0.6);
      expect(brushTool.settings.hardness, equals(0.6),
          reason: 'Hardness should remain unchanged when within range');
    });

    test('updateSettings should replace current settings', () {
      // Arrange
      const newSettings = BrushSettings(
        size: 100.0,
        opacity: 0.9,
        hardness: 0.8,
      );

      // Act
      brushTool.updateSettings(newSettings);

      // Assert
      expect(brushTool.settings, equals(newSettings),
          reason: 'Settings should be replaced with new settings');
    });

    test('getCursorRadius should return half of brush size', () {
      // Arrange
      brushTool.setSize(40.0);

      // Act
      final editorState = EditorState();
      final radius = brushTool.getCursorRadius(editorState);

      // Assert
      expect(radius, equals(20.0),
          reason: 'Cursor radius should be half of brush size');

      editorState.dispose();
    });

    test('onPointerDown should execute', () {
      // Arrange
      TestWidgetsFlutterBinding.ensureInitialized();
      final editorState = EditorState();
      final event = PointerDownEvent(
        position: Offset.zero,
      );

      // Act & Assert - Should execute
      brushTool.onPointerDown(event, editorState);
      // Note: isAltPressed is a getter that reads from HardwareKeyboard

      editorState.dispose();
    });

    test('onPointerMove should execute', () {
      // Arrange
      TestWidgetsFlutterBinding.ensureInitialized();
      final editorState = EditorState();
      final event = PointerMoveEvent(
        position: Offset.zero,
        delta: const Offset(10, 10),
      );

      // Act & Assert - Should execute
      brushTool.onPointerMove(event, editorState);

      editorState.dispose();
    });

    test('onPointerUp should execute', () {
      // Arrange
      TestWidgetsFlutterBinding.ensureInitialized();
      final editorState = EditorState();
      final event = PointerUpEvent(
        position: Offset.zero,
      );

      // Act & Assert - Should execute
      brushTool.onPointerUp(event, editorState);

      editorState.dispose();
    });
  });


  group('defaultBrushPresets', () {
    test('should have 8 presets', () {
      // Assert
      expect(defaultBrushPresets.length, equals(8),
          reason: 'Should have 8 default brush presets');
    });

    test('all presets should have valid properties', () {
      // Assert
      for (final preset in defaultBrushPresets) {
        expect(preset.name, isNotEmpty,
            reason: 'Preset name should not be empty');
        expect(preset.size, isPositive,
            reason: 'Preset size should be positive');
        expect(preset.opacity, greaterThanOrEqualTo(0.0),
            reason: 'Preset opacity should be >= 0');
        expect(preset.opacity, lessThanOrEqualTo(1.0),
            reason: 'Preset opacity should be <= 1');
        expect(preset.hardness, greaterThanOrEqualTo(0.0),
            reason: 'Preset hardness should be >= 0');
        expect(preset.hardness, lessThanOrEqualTo(1.0),
            reason: 'Preset hardness should be <= 1');
      }
    });

    test('preset settings should be clamped within valid ranges', () {
      // Assert - All presets should produce valid BrushSettings
      for (final preset in defaultBrushPresets) {
        final settings = preset.toSettings();
        expect(settings.size, greaterThanOrEqualTo(1.0),
            reason: 'Preset size should be >= 1');
        expect(settings.size, lessThanOrEqualTo(500.0),
            reason: 'Preset size should be <= 500');
        expect(settings.opacity, greaterThanOrEqualTo(0.0),
            reason: 'Preset opacity should be >= 0');
        expect(settings.opacity, lessThanOrEqualTo(1.0),
            reason: 'Preset opacity should be <= 1');
        expect(settings.hardness, greaterThanOrEqualTo(0.0),
            reason: 'Preset hardness should be >= 0');
        expect(settings.hardness, lessThanOrEqualTo(1.0),
            reason: 'Preset hardness should be <= 1');
      }
    });
  });

  group('BrushSettings', () {
    test('should create with default values', () {
      // Act
      const settings = BrushSettings();

      // Assert
      expect(settings.size, equals(20.0),
          reason: 'Default size should be 20.0');
      expect(settings.opacity, equals(1.0),
          reason: 'Default opacity should be 1.0');
      expect(settings.hardness, equals(0.8),
          reason: 'Default hardness should be 0.8');
    });

    test('copyWith should create new instance with updated values', () {
      // Arrange
      const original = BrushSettings(
        size: 10.0,
        opacity: 0.5,
        hardness: 0.5,
      );

      // Act
      final updated = original.copyWith(size: 20.0);

      // Assert
      expect(original.size, equals(10.0),
          reason: 'Original settings should remain unchanged');
      expect(updated.size, equals(20.0),
          reason: 'Updated settings should have new size');
      expect(updated.opacity, equals(original.opacity),
          reason: 'Unchanged properties should match original');
      expect(updated.hardness, equals(original.hardness),
          reason: 'Unchanged properties should match original');
    });

    test('toJson and fromJson should serialize correctly', () {
      // Arrange
      const original = BrushSettings(
        size: 45.0,
        opacity: 0.7,
        hardness: 0.9,
      );

      // Act
      final json = original.toJson();
      final restored = BrushSettings.fromJson(json);

      // Assert
      expect(restored.size, equals(original.size),
          reason: 'Size should be preserved through serialization');
      expect(restored.opacity, equals(original.opacity),
          reason: 'Opacity should be preserved through serialization');
      expect(restored.hardness, equals(original.hardness),
          reason: 'Hardness should be preserved through serialization');
    });
  });
}
