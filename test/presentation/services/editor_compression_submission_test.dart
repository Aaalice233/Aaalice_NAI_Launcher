import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/utils/decoded_image_size.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_input_exception.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/services/image_workflow_launcher.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/editor_canvas_resize_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/editor_compression_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/export/editor_result_exporter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/image_layer_source.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/image_generation_test_environment.dart';

void main() {
  setUpImageGenerationTestEnvironment();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a fixed frame whose last mask pixel disappears during export never submits a whole image',
    () async {
      const size = Size(2048, 2048);
      final editor = _openEditor(size, mode: ImageEditorMode.inpaint);
      final layers = editor.session.editorState.layerManager;
      final source = await layers.addLayerFromImage(
        img.encodePng(
          img.Image(width: 2048, height: 2048, numChannels: 1),
          level: 1,
        ),
      );
      editor.session.sourceLayerId = source!.id;
      editor.frameController.attachSource(Offset.zero & size);
      editor.frameController.restoreFrame(
        const Rect.fromLTWH(0, 0, 1024, 1024),
      );
      final white = img.Image(width: 1, height: 1)
        ..setPixelRgb(0, 0, 255, 255, 255);
      await layers.addLayerFromImage(
        img.encodePng(white),
        role: LayerRole.mask,
        offset: const Offset(600, 600),
      );
      _selectSize(editor, 1024, 1024);
      final result = await editor.exportResult();
      expect(DecodedImageSize.readHeader(result.focusOutpaint!.sourceImage), (
        1024,
        1024,
      ));
      expect(result.focusOutpaint!.crop, const Rect.fromLTWH(0, 0, 512, 512));
      final mask = result.maskImage!;
      final hasPixels = await InpaintMaskUtils.hasMaskedPixelsAsync(mask);
      expect(hasPixels, isFalse);

      final api = MockNAIImageGenerationApiService();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(AuthenticatedAuthNotifier.new),
          naiImageGenerationApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      ImageWorkflowLauncher.applyInpaintEditorResult(
        container.read(imageWorkflowControllerProvider.notifier),
        result,
        hasPixels ? mask : null,
      );
      final params = container.read(generationParamsNotifierProvider);
      await container
          .read(imageGenerationNotifierProvider.notifier)
          .generate(params);
      final state = container.read(imageGenerationNotifierProvider);
      expect(state.status, GenerationStatus.error);
      expect(state.errorMessage, FocusedInpaintInputException.invalidCropCode);
      verifyZeroInteractions(api);
    },
  );

  test(
    'rounded resize, undo and redo export 1152, 1280 and 1152 pixels',
    () async {
      final editor = _openEditor(const Size(1536, 1536));
      final state = editor.editorState;
      _selectSize(editor, 1280, 1280);
      Future<void> expectOutput(int side) async {
        expect(editor.session.compressionTarget!.matches(side, side), isTrue);
        final result = await editor.exportResult();
        expect(DecodedImageSize.readHeader(result.modifiedImage!), (
          side,
          side,
        ));
      }

      state.resizeCanvas(const Size(1408, 1408), CanvasResizeMode.pad);
      await expectOutput(1152);
      expect(state.undo(), isTrue);
      await expectOutput(1280);
      expect(state.redo(), isTrue);
      await expectOutput(1152);
    },
  );

  test(
    'returning to a non-grid canvas restores the manually chosen short side',
    () {
      final editor = _openEditor(const Size(1536, 1499));
      _selectSize(editor, 1536, 1472);
      editor.editorState.resizeCanvas(
        const Size(1408, 1408),
        CanvasResizeMode.pad,
      );
      expect(editor.editorState.undo(), isTrue);
      expect(editor.session.compressionTarget!.matches(1536, 1472), isTrue);
      _selectSize(editor, 1280, 1280);
      expect(editor.editorState.redo(), isTrue);
      expect(editor.session.compressionTarget!.matches(1152, 1152), isTrue);
    },
  );
}

void _selectSize(EditorResultExporter editor, int width, int height) {
  final index = editor.session.compressionPlan!.targets.indexWhere(
    (target) => target.matches(width, height),
  );
  expect(index, isNonNegative);
  editor.compressionController.selectTargetAt(index);
}

EditorResultExporter _openEditor(
  Size size, {
  ImageEditorMode mode = ImageEditorMode.edit,
}) {
  final config = ImageEditorSessionConfig(
    initialSize: size,
    mode: mode,
    supportsFocusOutpaint: mode == ImageEditorMode.inpaint,
  );
  final session = ImageEditorController(config: config)
    ..initializeSession(
      canvasSize: size,
      initialFocusRect: null,
      minimumContextMegaPixels: 96,
      focusedInpaintEnabled: false,
      outpaintCommitPending: false,
    );
  addTearDown(session.dispose);
  final state = session.editorState..initNewCanvas(size);
  final frame = EditorFrameController(session: session, editorState: state)
    ..supportsPasteBack = config.supportsFocusOutpaint;
  addTearDown(frame.dispose);
  final compression = EditorCompressionController(
    session: () => session,
    config: () => config,
    frameController: frame,
  )..refreshPlan();
  final resize = EditorCanvasResizeController(
    session: () => session,
    config: () => config,
    frameController: frame,
    compressionController: compression,
  );
  session.isInitialized = true;
  state.frameNotifier.addListener(resize.syncOnFrameChanged);
  addTearDown(
    () => state.frameNotifier.removeListener(resize.syncOnFrameChanged),
  );
  return EditorResultExporter(
    session: () => session,
    config: () => config,
    frameController: frame,
    imageSource: ImageLayerSource(state.layerManager),
    compressionController: compression,
  );
}
