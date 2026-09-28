import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/mask_paint_style.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/brush_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mask layers keep their own brush size, color and opacity', () {
    final session = _inpaintSession();
    final state = session.state;
    final brush = state.tools.whereType<BrushTool>().single;
    state.setTool(brush);
    state.setForegroundColor(const Color(0xFF123456));

    state.layerManager.setActiveLayer(session.image.id);
    state.setBrushSize(12);
    state.setBrushOpacity(0.3);
    expect(state.paintColor, const Color(0xFF123456));
    expect(state.brushOpacity, 0.3);

    state.layerManager.setActiveLayer(session.mask.id);
    expect(state.brushSize, brush.maskSize);
    expect(state.paintColor, MaskPaintStyle.color);
    expect(state.brushOpacity, MaskPaintStyle.opacity);

    state.setBrushSize(64);
    state.setBrushOpacity(0.9);
    expect(state.brushSize, 64);
    expect(state.brushOpacity, MaskPaintStyle.opacity);

    state.layerManager.setActiveLayer(session.image.id);
    expect(state.brushSize, 12);
    expect(brush.settings.opacity, 0.3);
  });

  test('strokes follow the active layer role', () {
    final session = _inpaintSession();
    final state = session.state;
    final brush = state.tools.whereType<BrushTool>().single;
    state.setTool(brush);
    state.setForegroundColor(const Color(0xFF123456));
    brush.setOpacity(0.4);
    brush.setHardness(0.2);

    state.layerManager.setActiveLayer(session.mask.id);
    _drawLine(brush, state);
    final maskStroke = session.mask.strokes.single;
    expect(maskStroke.color, MaskPaintStyle.color);
    expect(maskStroke.opacity, MaskPaintStyle.opacity);
    expect(maskStroke.hardness, MaskPaintStyle.hardness);
    expect(maskStroke.size, brush.maskSize);

    state.layerManager.setActiveLayer(session.image.id);
    _drawLine(brush, state);
    final imageStroke = session.image.strokes.single;
    expect(imageStroke.color, const Color(0xFF123456));
    expect(imageStroke.opacity, 0.4);
    expect(imageStroke.hardness, 0.2);
  });
}

({EditorState state, Layer image, Layer mask}) _inpaintSession() {
  final state = EditorState();
  addTearDown(state.dispose);
  final layers = state.layerManager;
  final image = layers.addLayer(name: 'image');
  final mask = layers.addLayer(name: 'mask', index: 0, role: LayerRole.mask);
  state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: image.id));
  state.setFrame(const Rect.fromLTWH(0, 0, 100, 100));
  return (state: state, image: image, mask: mask);
}

void _drawLine(BrushTool brush, EditorState state) {
  brush.onPointerDown(const PointerDownEvent(position: Offset(10, 10)), state);
  brush.onPointerMove(const PointerMoveEvent(position: Offset(30, 30)), state);
  brush.onPointerUp(const PointerUpEvent(position: Offset(30, 30)), state);
}
