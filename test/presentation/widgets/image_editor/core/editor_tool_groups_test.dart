import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_tool_groups.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/closed_region_fill_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  EditorState createState() {
    final state = EditorState();
    addTearDown(state.dispose);
    return state;
  }

  /// 与重绘会话一致：蒙版压在图片层之上，原图层受保护
  ({EditorState state, Layer source, Layer mask}) createInpaintState() {
    final state = createState();
    final source = state.layerManager.addLayer(name: 'Source');
    final mask = state.layerManager.addLayer(
      name: 'Mask',
      index: 0,
      role: LayerRole.mask,
    );
    state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: source.id));
    state.setClosedRegionFillHandler((_) async {});
    return (state: state, source: source, mask: mask);
  }

  List<String> entryIds(EditorToolSection section) =>
      section.entries.map((entry) => entry.tool.id).toList();

  EditorToolEntry entryOf(
    EditorState state,
    EditorToolGroup group,
    String toolId,
  ) {
    return editorToolSections(state)
        .singleWhere((section) => section.group == group)
        .entries
        .singleWhere((entry) => entry.tool.id == toolId);
  }

  group('editorToolSections', () {
    test('inpaint sessions split mask, image and shared tools', () {
      final (:state, source: _, mask: _) = createInpaintState();

      final sections = editorToolSections(state);

      expect(sections.map((section) => section.group), [
        EditorToolGroup.inpaint,
        EditorToolGroup.edit,
        EditorToolGroup.common,
      ]);
      expect(entryIds(sections[0]), [
        'brush',
        'eraser',
        ClosedRegionFillTool.toolId,
        'fill',
        'magic_wand',
      ]);
      expect(entryIds(sections[1]), [
        'brush',
        'eraser',
        'fill',
        'magic_wand',
        'blur',
        'clone_stamp',
        'color_picker',
      ]);
      expect(entryIds(sections[2]), [
        'move',
        'rect_selection',
        'ellipse_selection',
        'lasso_selection',
      ]);
      expect(
        sections[0].entries.map((entry) => entry.targetRole).toSet(),
        {LayerRole.mask},
      );
      expect(
        sections[1].entries.map((entry) => entry.targetRole).toSet(),
        {LayerRole.image},
      );
      expect(sections[2].entries.map((entry) => entry.targetRole).toSet(), {
        null,
      });
      expect(showsEditorToolGroupTitles(state), isTrue);
    });

    test('edit sessions have no inpaint group and no titles', () {
      final state = createState();
      state.layerManager.addLayer(name: 'Layer 1');

      final sections = editorToolSections(state);

      expect(sections.map((section) => section.group), [
        EditorToolGroup.edit,
        EditorToolGroup.common,
      ]);
      expect(
        sections
            .expand((section) => section.entries)
            .map((entry) => entry.tool.id),
        isNot(contains(ClosedRegionFillTool.toolId)),
      );
      expect(
        sections
            .expand((section) => section.entries)
            .every((entry) => entry.targetRole == null),
        isTrue,
      );
      expect(showsEditorToolGroupTitles(state), isFalse);
    });

    test('a role without layers hides its whole group', () {
      final state = createState();
      final mask = state.layerManager.addLayer(
        name: 'Mask',
        role: LayerRole.mask,
      );
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: mask.id));

      expect(editorToolSections(state).map((section) => section.group), [
        EditorToolGroup.inpaint,
        EditorToolGroup.common,
      ]);
    });
  });

  group('activateEditorToolEntry', () {
    test('switches to the layer the entry edits before changing tool', () {
      final (:state, :source, :mask) = createInpaintState();
      state.layerManager.setActiveLayer(source.id);
      state.setToolById('blur');

      activateEditorToolEntry(
        state,
        entryOf(state, EditorToolGroup.inpaint, 'brush'),
      );

      expect(state.layerManager.activeLayer, same(mask));
      expect(state.currentTool?.id, 'brush');
      expect(
        isEditorToolEntrySelected(
          state,
          entryOf(state, EditorToolGroup.inpaint, 'brush'),
        ),
        isTrue,
      );
      expect(
        isEditorToolEntrySelected(
          state,
          entryOf(state, EditorToolGroup.edit, 'brush'),
        ),
        isFalse,
      );

      activateEditorToolEntry(
        state,
        entryOf(state, EditorToolGroup.edit, 'blur'),
      );

      expect(state.layerManager.activeLayer, same(source));
      expect(state.currentTool?.id, 'blur');
    });

    test('returns to the image layer the user was last editing', () {
      final (:state, :source, mask: _) = createInpaintState();
      final upper = state.layerManager.addLayer(name: 'Upper', index: 1);
      state.layerManager.setActiveLayer(source.id);

      activateEditorToolEntry(
        state,
        entryOf(state, EditorToolGroup.inpaint, 'eraser'),
      );
      activateEditorToolEntry(
        state,
        entryOf(state, EditorToolGroup.edit, 'eraser'),
      );

      expect(state.layerManager.activeLayer, same(source));
      expect(state.layerManager.activeLayer, isNot(same(upper)));
    });

    test('shared tools keep the current layer', () {
      final (:state, source: _, :mask) = createInpaintState();
      state.layerManager.setActiveLayer(mask.id);

      activateEditorToolEntry(
        state,
        entryOf(state, EditorToolGroup.common, 'move'),
      );

      expect(state.layerManager.activeLayer, same(mask));
      expect(state.currentTool?.id, 'move');
      expect(
        isEditorToolEntrySelected(
          state,
          entryOf(state, EditorToolGroup.common, 'move'),
        ),
        isTrue,
      );
    });
  });

  group('LayerManager.preferredLayerFor', () {
    test('skips a locked remembered layer for the topmost unlocked one', () {
      final state = createState();
      final layers = state.layerManager;
      final bottom = layers.addLayer(name: 'Bottom');
      final top = layers.addLayer(name: 'Top', index: 0)..locked = true;

      expect(layers.activeLayer, same(top));
      expect(layers.preferredLayerFor(LayerRole.image), same(bottom));

      top.locked = false;
      expect(layers.preferredLayerFor(LayerRole.image), same(top));
      expect(layers.preferredLayerFor(LayerRole.mask), isNull);
    });

    test('ignores a remembered layer whose role has changed', () {
      final state = createState();
      final layers = state.layerManager;
      final source = layers.addLayer(name: 'Source');
      final drawing = layers.addLayer(name: 'Drawing', index: 0);
      layers.setActiveLayer(drawing.id);

      drawing.role = LayerRole.mask;

      expect(layers.preferredLayerFor(LayerRole.image), same(source));
    });
  });

  group('ClosedRegionFillTool', () {
    test('forwards the canvas point and drops taps while filling', () async {
      final (:state, source: _, mask: _) = createInpaintState();
      final points = <Offset>[];
      final pending = <Completer<void>>[];
      state.setClosedRegionFillHandler((point) {
        points.add(point);
        final completer = Completer<void>();
        pending.add(completer);
        return completer.future;
      });
      final tool = ClosedRegionFillTool();

      tool.onPointerDown(
        const PointerDownEvent(position: Offset(10, 20)),
        state,
      );
      tool.onPointerDown(
        const PointerDownEvent(position: Offset(30, 40)),
        state,
      );
      expect(points, [const Offset(10, 20)]);

      pending.single.complete();
      await Future<void>.delayed(Duration.zero);
      tool.onPointerDown(
        const PointerDownEvent(position: Offset(30, 40)),
        state,
      );
      expect(points, [const Offset(10, 20), const Offset(30, 40)]);
      pending.last.complete();
    });

    test('only targets mask layers and needs a fill handler', () {
      final state = createState();
      final tool = ClosedRegionFillTool();

      expect(tool.supportsRole(LayerRole.mask), isTrue);
      expect(tool.supportsRole(LayerRole.image), isFalse);
      expect(tool.isEnabledInSession(state), isFalse);

      state.setClosedRegionFillHandler((_) async {});
      expect(tool.isEnabledInSession(state), isTrue);
    });
  });
}
