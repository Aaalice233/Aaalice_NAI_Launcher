import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/hard_edge_mask_exporter.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/export/image_exporter_new.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_commands.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_processing_service.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';

/// 扩图物化在当前 isolate 内完成，测试不依赖后台 isolate 调度
class _InlineProcessingService extends ImageEditorProcessingService {
  @override
  Future<OutpaintVirtualMaterializeResult> materializeOutpaint({
    required Uint8List sourceImage,
    required OutpaintVirtualFrame frame,
    int? targetWidth,
    int? targetHeight,
  }) async {
    return InpaintOutpaintUtils.materializeVirtualFrame(
      sourceImage: sourceImage,
      frame: frame,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
  }
}

class _Harness {
  _Harness._(this.session, this.frames, this.source, this.mask);

  final ImageEditorController session;
  final EditorFrameController frames;
  final Layer source;
  final Layer mask;

  EditorState get state => session.editorState;

  static Future<_Harness> create({int width = 256, int height = 128}) async {
    final session = ImageEditorController(
      processingService: _InlineProcessingService(),
    );
    final state = session.editorState;
    final size = Size(width.toDouble(), height.toDouble());
    state.initNewCanvas(size, initialLayerName: 'mask');
    final mask = state.layerManager.layers.single;
    final source = await state.layerManager.addLayerFromImage(
      _gradientPng(width, height),
      name: 'source',
    );
    session.sourceLayerId = source!.id;
    final frames = EditorFrameController(session: session, editorState: state);
    frames.attachSource(Offset.zero & size);
    return _Harness._(session, frames, source, mask);
  }

  void moveFrame(Offset delta) {
    final start = state.frame;
    frames.commitMove(start, frames.resolveMove(start, delta));
  }

  Future<HardEdgeMaskRaster> maskRaster() async {
    final raster = await ImageExporterNew.tryExportHardEdgeMaskRasterFromLayers(
      state.layerManager,
      state.frame,
      excludedBaseImageLayerIds: {source.id},
    );
    return raster!;
  }

  Future<img.Image> materializedSource() async {
    final result = await session.processingService.materializeOutpaint(
      sourceImage: source.baseImageBytes!,
      frame: frames.virtualFrame!,
    );
    return img.decodePng(result.sourceImage)!;
  }

  void dispose() {
    frames.dispose();
    session.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('moving the frame never touches layer content and is undoable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.state.layerManager.addStrokeToLayer(
        h.mask.id,
        _stroke(const [Offset(10, 64), Offset(40, 64)]),
      );
      final strokePoints = h.mask.strokes.single.points;
      final start = h.state.frame;

      h.moveFrame(const Offset(64, 0));

      expect(h.state.frame, const Rect.fromLTWH(64, 0, 256, 128));
      expect(h.source.baseImageOffset, Offset.zero);
      expect(h.mask.strokes.single.points, strokePoints);
      expect(h.frames.hasOutpaintChanges, isTrue);
      expect(h.frames.outpaintMaskRects, const [
        Rect.fromLTRB(191, 0, 256, 128),
      ]);

      expect(h.state.undo(), isTrue);
      expect(h.state.frame, start);
      expect(h.frames.hasOutpaintChanges, isFalse);

      expect(h.state.redo(), isTrue);
      expect(h.state.frame, const Rect.fromLTWH(64, 0, 256, 128));
    });
  });

  testWidgets('mask strokes keep document coordinates across frame history', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      expect(
        h.frames.applyFrameDelta(
          const OutpaintFrameDelta(left: 64),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        FrameResizeOutcome.applied,
      );
      expect(h.state.frame, const Rect.fromLTWH(-64, 0, 320, 128));

      // 笔画画在原图左侧的扩展区（负坐标）
      h.state.historyManager.execute(
        AddStrokeAction(
          layerId: h.mask.id,
          stroke: _stroke(const [Offset(-20, 64), Offset(-10, 64)]),
        ),
        h.state,
      );
      h.moveFrame(const Offset(-64, 0));
      expect(h.state.frame.left, -128);

      Future<void> expectStrokeAtLocalX(int? localX) async {
        final raster = await h.maskRaster();
        for (final x in const [49, 113]) {
          expect(
            _maskAt(raster, x, 64),
            x == localX ? 1 : 0,
            reason: 'frame=${h.state.frame}, x=$x',
          );
        }
      }

      await expectStrokeAtLocalX(113);
      h.state.undo();
      await expectStrokeAtLocalX(49);
      h.state.undo();
      await expectStrokeAtLocalX(null);
      h.state.redo();
      await expectStrokeAtLocalX(49);
      h.state.redo();
      await expectStrokeAtLocalX(113);
    });
  });

  testWidgets('mask export at negative coordinates matches both export paths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.frames.applyFrameDelta(
        const OutpaintFrameDelta(left: 64),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
      );
      h.state.layerManager.addStrokeToLayer(
        h.mask.id,
        _stroke(const [Offset(-60, 10), Offset(-30, 10)], size: 6),
      );
      await h.state.layerManager.addLayerFromImage(
        _solidPng(8, 8, const Color(0xFFFFFFFF)),
        name: 'imported',
        index: 0,
        offset: const Offset(-64, 100),
      );

      Future<img.Image> export({required bool preferCpu}) async {
        final bytes = await ImageExporterNew.exportMaskFromLayers(
          h.state.layerManager,
          h.state.frame,
          excludedBaseImageLayerIds: {h.source.id},
          forceHardEdges: true,
          preferCpuHardEdgeExport: preferCpu,
        );
        return img.decodePng(bytes)!;
      }

      final cpu = await export(preferCpu: true);
      final canvas = await export(preferCpu: false);
      for (final mask in [cpu, canvas]) {
        expect(mask.width, 320);
        expect(_red(mask, 19, 10), 255, reason: 'stroke at local x=19');
        expect(_red(mask, 3, 104), 255, reason: 'base mask at local (3,104)');
        expect(_red(mask, 150, 60), 0);
      }
    });
  });

  testWidgets('clear and replace actions restore base image offsets', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final layer = (await h.state.layerManager.addLayerFromImage(
        _solidPng(8, 8, const Color(0xFFFFFFFF)),
        name: 'imported',
        offset: const Offset(-16, 24),
      ))!;

      h.state.historyManager.execute(
        ClearLayerAction(layerId: layer.id),
        h.state,
      );
      expect(layer.hasBaseImage, isFalse);
      h.state.historyManager.undo(h.state);
      expect(layer.hasBaseImage, isTrue);
      expect(layer.baseImageOffset, const Offset(-16, 24));

      final replacementBytes = _solidPng(4, 4, const Color(0xFF000000));
      final replacement = await h.session.processingService.decode(
        replacementBytes,
      );
      h.state.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: layer.id,
          newImageBytes: replacementBytes,
          newImage: replacement,
          newImageOffset: const Offset(40, 8),
        ),
        h.state,
      );
      expect(layer.baseImage!.width, 4);
      expect(layer.baseImageOffset, const Offset(40, 8));

      h.state.historyManager.undo(h.state);
      expect(layer.baseImage!.width, 8);
      expect(layer.baseImageOffset, const Offset(-16, 24));

      h.state.historyManager.redo(h.state);
      expect(layer.baseImage!.width, 4);
      expect(layer.baseImageOffset, const Offset(40, 8));
    });
  });

  testWidgets('crop to frame keeps what is sent and undo restores content', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      // 蒙版笔画跨过取景框左边界
      h.state.layerManager.addStrokeToLayer(
        h.mask.id,
        _stroke(const [Offset(40, 64), Offset(120, 64)], size: 10),
      );
      h.moveFrame(const Offset(64, 0));
      expect(h.frames.canCropToFrame, isTrue);

      final sourceBefore = await h.materializedSource();
      final maskBefore = await h.maskRaster();

      await h.frames.cropToFrame();

      expect(h.source.baseImageOffset, const Offset(64, 0));
      expect(h.source.baseImage!.width, 192);
      expect(h.source.baseImage!.height, 128);
      expect(h.mask.strokes, isEmpty);
      expect(h.mask.baseImageOffset, const Offset(64, 0));
      expect(h.frames.canCropToFrame, isFalse);
      expect(h.frames.hasOutpaintChanges, isTrue);
      expect(h.state.historyManager.undoDescription, 'Crop to Frame');

      final sourceAfter = await h.materializedSource();
      expect(_pixels(sourceAfter), orderedEquals(_pixels(sourceBefore)));
      final maskAfter = await h.maskRaster();
      expect(maskAfter.mask, orderedEquals(maskBefore.mask));

      expect(h.state.undo(), isTrue);
      expect(h.source.baseImageOffset, Offset.zero);
      expect(h.source.baseImage!.width, 256);
      expect(h.mask.strokes, hasLength(1));
      expect(h.mask.hasBaseImage, isFalse);
      expect(h.frames.canCropToFrame, isTrue);

      expect(h.state.redo(), isTrue);
      expect(h.source.baseImageOffset, const Offset(64, 0));
      expect(h.source.baseImage!.width, 192);
      expect(h.mask.strokes, isEmpty);
    });
  });

  testWidgets('crop is dropped when the document changes while preparing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.moveFrame(const Offset(64, 0));

      final pending = h.frames.cropToFrame();
      expect(h.frames.isCroppingToFrame, isTrue);
      expect(h.frames.canMoveFrame, isFalse);
      h.state.layerManager.addStrokeToLayer(
        h.mask.id,
        _stroke(const [Offset(100, 20)]),
      );
      await pending;

      expect(h.frames.isCroppingToFrame, isFalse);
      expect(h.source.baseImageOffset, Offset.zero);
      expect(h.source.baseImage!.width, 256);
      expect(h.state.historyManager.undoDescription, 'Move Frame');
    });
  });

  testWidgets('crop requires the frame to overlap the source', (tester) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.state.setFrame(const Rect.fromLTWH(320, 0, 64, 64));

      expect(h.frames.canCropToFrame, isFalse);
    });
  });

  testWidgets('frame size changes anchor the top-left and align to 64', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);

      // 画布尺寸对话框在重绘模式下走同一入口
      final applied = h.frames.applyFrameDelta(
        const OutpaintFrameDelta(right: 1000 - 256, bottom: 300 - 128),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
        verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
      );

      expect(applied, FrameResizeOutcome.applied);
      expect(h.state.frame, const Rect.fromLTWH(0, 0, 1024, 320));
      expect(h.state.canvasSize, const Size(1024, 320));
      expect(h.state.undo(), isTrue);
      expect(h.state.frame, const Rect.fromLTWH(0, 0, 256, 128));
    });
  });

  testWidgets('reset fits the frame to the current source', (tester) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.moveFrame(const Offset(64, 32));
      expect(h.frames.canResetFrame, isTrue);

      h.frames.resetFrame();

      expect(h.state.frame, const Rect.fromLTWH(0, 0, 256, 128));
      expect(h.frames.hasOutpaintChanges, isFalse);
      expect(h.frames.canResetFrame, isFalse);
    });
  });

  testWidgets('frame editing is locked while the view is rotated or mirrored', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final controller = h.state.canvasController;
      expect(h.frames.canMoveFrame, isTrue);

      controller.rotateLeft();
      expect(h.frames.canMoveFrame, isFalse);
      controller.resetRotation();
      controller.toggleMirrorHorizontal();
      expect(h.frames.canMoveFrame, isFalse);
      controller.toggleMirrorHorizontal();
      expect(h.frames.canMoveFrame, isTrue);
    });
  });

  testWidgets('outpaint mask rects follow a preview frame', (tester) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);

      expect(
        h.frames.outpaintMaskRectsFor(const Rect.fromLTWH(-64, 0, 256, 128)),
        const [Rect.fromLTRB(0, 0, 65, 128)],
      );
      expect(h.frames.outpaintMaskRects, isEmpty);
    });
  });

  group('paste-back canvas', () {
    testWidgets('stays off unless the session supports pasting back', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.moveFrame(const Offset(64, 0));

        expect(h.frames.hasOutpaintChanges, isTrue);
        expect(h.frames.pasteBackCanvas, isNull);
      });
    });

    testWidgets('is the union of source and frame while the frame leaves '
        'part of the source outside', (tester) async {
      await tester.runAsync(() async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        var notifications = 0;
        h.frames.addListener(() => notifications++);
        h.frames.supportsPasteBack = true;
        expect(notifications, 1);
        expect(h.frames.pasteBackCanvas, isNull);

        h.moveFrame(const Offset(64, 0));
        expect(h.frames.pasteBackCanvas, const Rect.fromLTWH(0, 0, 320, 128));

        // 框缩进原图内：整张画布就是原图
        h.frames.resetFrame();
        h.frames.applyFrameDelta(
          const OutpaintFrameDelta(right: -64),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        );
        expect(h.state.frame, const Rect.fromLTWH(0, 0, 192, 128));
        expect(h.frames.pasteBackCanvas, const Rect.fromLTWH(0, 0, 256, 128));
      });
    });

    testWidgets('is null once the frame covers the whole source', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.frames.supportsPasteBack = true;

        h.frames.applyFrameDelta(
          const OutpaintFrameDelta(left: 64),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        );

        expect(h.frames.hasOutpaintChanges, isTrue);
        expect(h.frames.pasteBackCanvas, isNull);
      });
    });

    testWidgets('is null after cropping to the frame', (tester) async {
      await tester.runAsync(() async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.frames.supportsPasteBack = true;
        h.moveFrame(const Offset(64, 0));
        expect(h.frames.pasteBackCanvas, isNotNull);

        await h.frames.cropToFrame();

        expect(h.frames.hasOutpaintChanges, isTrue);
        expect(h.frames.pasteBackCanvas, isNull);
        expect(h.state.undo(), isTrue);
        expect(h.frames.pasteBackCanvas, const Rect.fromLTWH(0, 0, 320, 128));
      });
    });
  });

  testWidgets('resizes that break the overlap are rejected', (tester) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.moveFrame(const Offset(5000, 0));
      expect(h.state.frame, const Rect.fromLTWH(192, 0, 256, 128));

      final outcome = h.frames.applyFrameDelta(
        const OutpaintFrameDelta(left: -64),
        horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
        verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
      );

      expect(outcome, FrameResizeOutcome.rejected);
      expect(h.state.frame, const Rect.fromLTWH(192, 0, 256, 128));
      expect(
        h.frames.isFrameAllowed(const Rect.fromLTWH(256, 0, 192, 128)),
        isFalse,
      );
      expect(
        h.frames.applyFrameDelta(
          const OutpaintFrameDelta(right: 10),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        FrameResizeOutcome.unchanged,
      );
      expect(h.state.historyManager.undoDescription, 'Move Frame');
    });
  });

  testWidgets('request estimate updates notify only on change', (tester) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      var notifications = 0;
      h.frames.addListener(() => notifications++);
      const estimate = EditorRequestEstimate(
        requestWidth: 832,
        requestHeight: 1216,
        cost: 0,
      );

      h.frames.updateRequestEstimate(estimate);
      h.frames.updateRequestEstimate(
        const EditorRequestEstimate(
          requestWidth: 832,
          requestHeight: 1216,
          cost: 0,
        ),
      );

      expect(h.frames.requestEstimate, estimate);
      expect(notifications, 1);
    });
  });

  testWidgets('restoring a saved frame aligns it and skips the undo stack', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final h = await _Harness.create();
      addTearDown(h.dispose);

      h.frames.restoreFrame(const Rect.fromLTRB(70, -10, 330, 120));

      expect(h.state.frame, const Rect.fromLTWH(64, 0, 256, 128));
      expect(h.state.historyManager.canUndo, isFalse);
      expect(h.frames.hasOutpaintChanges, isTrue);
    });
  });

  test('edit mode keeps the frame at the origin', () {
    final state = EditorState();
    addTearDown(state.dispose);

    expect(
      () => state.setFrame(const Rect.fromLTWH(16, 0, 64, 64)),
      throwsAssertionError,
    );
  });
}

StrokeData _stroke(
  List<Offset> points, {
  double size = 8,
  bool isEraser = false,
}) {
  return StrokeData(
    points: points,
    size: size,
    color: const Color(0xFF60AAFF),
    opacity: 1,
    hardness: 1,
    isEraser: isEraser,
  );
}

int _maskAt(HardEdgeMaskRaster raster, int x, int y) {
  return raster.mask[y * raster.width + x];
}

int _red(img.Image image, int x, int y) => image.getPixel(x, y).r.toInt();

List<int> _pixels(img.Image image) {
  return image
      .convert(format: img.Format.uint8, numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
}

Uint8List _gradientPng(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 256, y % 256, 128, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _solidPng(int width, int height, Color color) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  img.fill(
    image,
    color: img.ColorRgba8(
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      (color.a * 255).round(),
    ),
  );
  return Uint8List.fromList(img.encodePng(image));
}
