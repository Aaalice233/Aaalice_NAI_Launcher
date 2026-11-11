import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/editor_compression_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/editor_session_initializer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/inpaint_mask_actions_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_commands.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/frame/editor_frame_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/image_layer_source.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_save_file_picker.dart';
import '../../../../helpers/log_capture.dart';

const _size = Size(4, 4);
final _maskPng = img.encodePng(img.Image(width: 4, height: 4));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('关闭会话后丢弃已有蒙版，不记录加载失败', (tester) async {
    final context = await _pumpLocalizedContext(tester);
    final config = ImageEditorSessionConfig(
      initialSize: _size,
      existingMask: _maskPng,
      mode: ImageEditorMode.inpaint,
    );
    final session = ImageEditorController(config: config);
    addTearDown(session.dispose);
    session.initializeSession(
      canvasSize: _size,
      initialFocusRect: null,
      minimumContextMegaPixels: 88,
      focusedInpaintEnabled: false,
      outpaintCommitPending: false,
    );
    final state = session.editorState;
    final frame = EditorFrameController(session: session, editorState: state);
    addTearDown(frame.dispose);
    final initializer = EditorSessionInitializer(
      session: () => session,
      config: () => config,
      frameController: frame,
      imageSource: ImageLayerSource(state.layerManager),
      compressionController: EditorCompressionController(
        session: () => session,
        config: () => config,
        frameController: frame,
      ),
    );

    ui.Image? decodedMask;
    final logs = await tester.runAsync(() async {
      final previousCreate = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        decodedMask = image;
        session.dispose();
      };
      try {
        return await captureLogs(
          () => initializer.initializeCanvas(
            context,
            isMounted: () => context.mounted,
            onMarkInitialized: () => fail('已关闭的会话不应初始化完成'),
          ),
        );
      } finally {
        ui.Image.onCreate = previousCreate;
      }
    });

    expect(decodedMask?.debugDisposed, isTrue);
    expect(
      logs,
      isNot(contains(contains('Failed to load existing mask as layer'))),
    );
  });

  for (final closeHost in [false, true]) {
    testWidgets(closeHost ? '外部蒙版解码期间关闭宿主不记录格式错误' : '宿主仍打开时记录外部蒙版解码失败', (
      tester,
    ) async {
      final context = await _pumpLocalizedContext(tester);
      useFakeFilePicker(_MaskFilePicker());
      final logs = await tester.runAsync(
        () => captureLogs(() async {
          final session = _MaskImportSession();
          final commands = session.editorState.layerCommands;
          final controller = InpaintMaskActionsController(
            session: () => session,
            config: () => const ImageEditorSessionConfig.empty(),
            compressionController: _UnusedCompressionController(),
          );
          var mounted = true;
          final pending = controller.loadMaskFile(
            context,
            isMounted: () => mounted,
          );
          expect(
            await Future.any([
              commands.started.future.then((_) => true),
              pending.then((_) => false),
            ]),
            isTrue,
          );
          mounted = !closeHost;
          commands.result.complete(null);
          await pending;
        }),
      );

      final warning = contains(
        contains('Failed to decode image or unsupported format'),
      );
      expect(logs, closeHost ? isNot(warning) : warning);
    });
  }
}

Future<BuildContext> _pumpLocalizedContext(WidgetTester tester) async {
  const child = SizedBox();
  await tester.pumpWidget(
    Localizations(
      locale: const Locale('en'),
      delegates: AppLocalizations.localizationsDelegates,
      child: child,
    ),
  );
  return tester.element(find.byWidget(child));
}

class _MaskImportSession extends Fake implements ImageEditorController {
  @override
  final _MaskImportState editorState = _MaskImportState();
}

class _MaskImportState extends Fake implements EditorState {
  @override
  final frame = Offset.zero & _size;

  @override
  final _PendingMaskCommands layerCommands = _PendingMaskCommands();
}

class _PendingMaskCommands extends Fake implements LayerCommands {
  final started = Completer<void>();
  final result = Completer<Layer?>();

  @override
  Future<Layer?> addImageLayer(
    Uint8List bytes, {
    required String name,
    Offset offset = Offset.zero,
    LayerRole role = LayerRole.image,
  }) {
    started.complete();
    return result.future;
  }
}

class _UnusedCompressionController extends Fake
    implements EditorCompressionController {}

class _MaskFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'mask.png', size: _maskPng.length, bytes: _maskPng),
  ]);
}
