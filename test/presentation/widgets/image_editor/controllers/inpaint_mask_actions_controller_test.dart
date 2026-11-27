import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/editor_compression_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/inpaint_mask_actions_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/input_handler.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/export/image_exporter_new.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'fills a rectangle, restores selection with Ctrl+Z, then undoes mask',
    () async {
      final (state, controller) = _createController();
      _selectRectangle(state);
      final bounds = state.selectionPath!.getBounds();
      expect(state.layerManager.maskLayers, isEmpty);
      expect(await _apply(controller), isTrue);
      expect(state.selectionPath, isNull);
      expect(state.historyManager.undoDescription, 'Fill Selection Into Mask');
      final mask = state.layerManager.maskLayers.single;
      expect(mask.name, 'Test Mask');
      expect(mask.contentBounds, bounds);
      final pixels = await LayerPixels.of(mask, state.frame);
      final overlay = await _encodedOverlayPixel();
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          expect(
            pixels.at(x.toDouble(), y.toDouble()),
            bounds.contains(Offset(x + 0.5, y + 0.5)) ? overlay : [0, 0, 0, 0],
            reason: 'rectangle pixel ($x, $y)',
          );
        }
      }

      final focus = FocusNode();
      addTearDown(focus.dispose);
      final input = InputHandler(
        state: state,
        focusNode: focus,
        onStateChanged: () {},
      );
      await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
      try {
        _undo(input);
        expect(state.selectionPath!.getBounds(), bounds);
        expect(state.layerManager.maskLayers, [mask]);
        // 选区工具优先撤销选区历史，原始矩形也占一步。
        _undo(input);
        _undo(input);
        expect(state.layerManager.maskLayers, isEmpty);
      } finally {
        await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
    },
  );

  test('a fully masked selection is painted again and cleared', () async {
    final (state, controller) = _createController();
    _selectRectangle(state);
    expect(await _apply(controller), isTrue);
    final layer = state.layerManager.maskLayers.single;
    final before = await LayerPixels.of(layer, state.frame);
    final steps = state.historyManager.undoStackSize;

    _selectRectangle(state);
    expect(await _apply(controller), isTrue);
    expect(state.selectionPath, isNull);
    expect(state.layerManager.maskLayers, [layer]);
    expect(state.historyManager.undoStackSize, steps + 1);
    final after = await LayerPixels.of(layer, state.frame);
    expect(after.alphaAt(5, 7), greaterThan(before.alphaAt(5, 7)));
    expect(after.at(2, 2), before.at(2, 2));
  });

  test(
    'freeform fill has hard edges and preserves pixels outside the frame',
    () async {
      final (state, controller) = _createController();
      const frame = Rect.fromLTRB(-4, -5, 20, 18);
      state.allowsDetachedFrame = true;
      state.setFrame(frame);
      final layer = state.layerCommands.addLayer(
        name: 'Existing Mask',
        role: LayerRole.mask,
      );
      await fillLayer(
        state.layerManager,
        layer,
        size: const Size(8, 12),
        offset: const Offset(-8, -9),
        color: const Color(0x80FFFFFF),
      );
      const sample = Rect.fromLTRB(-9, -10, 22, 20);
      final before = await LayerPixels.of(layer, sample);
      final selection = Path()
        ..moveTo(-6.75, -8.25)
        ..lineTo(14.75, -8.25)
        ..lineTo(14.75, 3.25)
        ..lineTo(3.25, 3.25)
        ..lineTo(3.25, 14.75)
        ..lineTo(-6.75, 14.75)
        ..close();
      state.setSelection(selection);
      expect(await _apply(controller), isTrue);
      expect(state.selectionPath, isNull);
      expect(state.layerManager.maskLayers, [layer]);
      expect(layer.contentBounds, const Rect.fromLTRB(-8, -9, 15, 15));

      final after = await LayerPixels.of(layer, sample);
      final overlay = await _encodedOverlayPixel();
      final exported = await ImageExporterNew.exportMaskFromLayers(
        [layer],
        frame,
        forceHardEdges: true,
      );
      final binary = InpaintMaskUtils.decodeBinaryMask(exported)!;
      for (var y = sample.top; y < sample.bottom; y++) {
        for (var x = sample.left; x < sample.right; x++) {
          final center = Offset(x + 0.5, y + 0.5);
          final old = before.at(x, y);
          final actual = after.at(x, y);
          final inFrame = frame.contains(center);
          final selected = inFrame && selection.contains(center);
          final reason = 'freeform pixel ($x, $y)';
          if (!selected) {
            expect(actual, old, reason: reason);
          } else if (old[3] == 0) {
            expect(actual, overlay, reason: reason);
          } else {
            expect(actual[3], greaterThan(old[3]), reason: reason);
          }
          if (inFrame) {
            final i =
                (y - frame.top).toInt() * binary.width +
                (x - frame.left).toInt();
            expect(
              binary.mask[i],
              selected || old[3] != 0 ? 1 : 0,
              reason: reason,
            );
          }
        }
      }
    },
  );

  test(
    'selection wholly outside the frame has no writes or undo step',
    () async {
      final (state, controller) = _createController();
      final selection = Path()..addRect(const Rect.fromLTWH(40, 10, 8, 8));
      state.setSelection(selection);
      final steps = state.historyManager.undoStackSize;
      expect(await _apply(controller), isFalse);
      expect(state.selectionPath, same(selection));
      expect(state.layerManager.maskLayers, isEmpty);
      expect(state.historyManager.undoStackSize, steps);
    },
  );

  test('a different selection supersedes a pending fill', () async {
    final (state, controller) = _createController();
    _selectRectangle(state);
    final pending = _apply(controller);
    final replacement = Path()..addRect(const Rect.fromLTWH(14, 15, 5, 6));
    state.setSelection(replacement);
    expect(await pending, isNull);
    expect(state.selectionPath, same(replacement));
    expect(state.layerManager.maskLayers, isEmpty);
  });

  for (final unmounts in [false, true]) {
    final reason = unmounts ? 'unmount' : 'session epoch change';
    test('$reason cancels a pending fill', () async {
      final (state, controller) = _createController();
      _selectRectangle(state);
      final selection = state.selectionPath;
      var mounted = true;
      final pending = controller.applySelectionMask(
        newLayerName: 'Test Mask',
        isMounted: () => mounted,
      );
      if (unmounts) {
        mounted = false;
      } else {
        controller.session.cancelPendingOperations();
      }
      expect(await pending, isNull);
      expect(state.selectionPath, same(selection));
      expect(state.layerManager.maskLayers, isEmpty);
    });
  }

  test('selection mask filling rasterizes directly without PNG or isolates', () {
    final source = File(
      'lib/presentation/widgets/image_editor/controllers/'
      'inpaint_mask_actions_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('applySelectionMask({');
    final end = source.indexOf('Future<void> loadMaskFile(');
    final method = source.substring(start, end);
    expect(method, contains('ui.PictureRecorder()'));
    expect(method, contains('picture.toImage('));
    expect(method, contains('state.layerCommands.addMaskPixels('));
    expect(
      method,
      isNot(
        matches(
          RegExp(
            r'ImageExporterNew\s*\.|InpaintMaskUtils\s*\.\s*\w+\s*\(|'
            r'\b(writeBinaryMask|toByteData|instantiateImageCodec|encodePng|'
            r'decodePng|ComputeGate|Isolate|compute)\s*[.(]|processingService\s*\.',
          ),
        ),
      ),
    );
  });
}

(EditorState, InpaintMaskActionsController) _createController() {
  final config = ImageEditorSessionConfig(mode: ImageEditorMode.inpaint);
  final session = ImageEditorController(config: config);
  final state = session.editorState..initNewCanvas(const Size(32, 32));
  final frame = EditorFrameController(session: session, editorState: state);
  addTearDown(session.dispose);
  addTearDown(frame.dispose);
  return (
    state,
    InpaintMaskActionsController(
      session: () => session,
      config: () => config,
      compressionController: EditorCompressionController(
        session: () => session,
        config: () => config,
        frameController: frame,
      ),
    ),
  );
}

Future<bool?> _apply(InpaintMaskActionsController controller) => controller
    .applySelectionMask(newLayerName: 'Test Mask', isMounted: () => true);

Future<List<int>> _encodedOverlayPixel() async {
  final patch = InpaintMaskUtils.encodeEditorOverlayPatch(
    Uint8List.fromList([1]),
    width: 1,
    height: 1,
  )!;
  final codec = await ui.instantiateImageCodec(patch.bytes);
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void _selectRectangle(EditorState state) {
  state.setToolById('rect_selection');
  final tool = state.currentTool!;
  tool.onPointerDown(const PointerDownEvent(position: Offset(4, 6)), state);
  tool.onPointerUp(const PointerUpEvent(position: Offset(14, 14)), state);
}

void _undo(InputHandler input) => expect(
  input.handleKeyEvent(
    input.focusNode,
    const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyZ,
      logicalKey: LogicalKeyboardKey.keyZ,
      timeStamp: Duration.zero,
    ),
  ),
  KeyEventResult.handled,
);
