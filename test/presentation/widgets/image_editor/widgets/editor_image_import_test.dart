import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_save_file_picker.dart';
import '../image_editor_workspace_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the layer panel imports JPEG data with a .jfif suffix', (
    tester,
  ) async {
    _selectFile('scan.jfif', img.encodeJpg(img.Image(width: 8, height: 6)));
    final (_, session) = await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1600, 900),
    );
    final state = session.editorState;
    final layersBefore = state.layerManager.layerCount;

    await _pressPickerButton(tester, 'Import Image');
    await tester.pumpWidget(const SizedBox.shrink());

    expect(state.layerManager.layerCount, layersBefore + 1);
    expect(state.layerManager.activeLayer!.name, 'scan.jfif');
    expect(state.layerManager.activeLayer!.hasBaseImage, isTrue);
    expect(state.layerTransformer.isActive, isTrue);
  });

  testWidgets('Load Mask adds a mask layer from an extensionless PNG', (
    tester,
  ) async {
    final mask = img.Image(width: 8, height: 6)
      ..clear(img.ColorRgb8(255, 255, 255));
    _selectFile('mask', img.encodePng(mask));
    final (_, session) = await pumpEditorWorkspace(
      tester,
      viewSize: const Size(1600, 900),
      mode: ImageEditorMode.inpaint,
    );
    final layers = session.editorState.layerManager;
    final masksBefore = layers.maskLayers.length;

    await _pressPickerButton(tester, 'Load Mask');
    await tester.pumpWidget(const SizedBox.shrink());

    expect(layers.maskLayers, hasLength(masksBefore + 1));
    expect(layers.activeLayer!.isMask, isTrue);
    expect(layers.activeLayer!.hasBaseImage, isTrue);
  });

  for (final (name, message) in [
    ('scan.bin', 'Unsupported file format: .bin'),
    ('scan.png', 'Failed to parse image file'),
  ]) {
    testWidgets('invalid image data in $name shows $message', (tester) async {
      _selectFile(name, Uint8List.fromList([0, 1, 2]));
      final (_, session) = await pumpEditorWorkspace(
        tester,
        viewSize: const Size(1600, 900),
      );
      final layers = session.editorState.layerManager;
      final layersBefore = layers.layerCount;

      await _pressPickerButton(tester, 'Import Image');

      expect(layers.layerCount, layersBefore);
      expect(find.textContaining(message), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _pressPickerButton(WidgetTester tester, String tooltip) async {
  final button = tester.widget<IconButton>(
    find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    ),
  );
  final onPressed = button.onPressed! as Future<void> Function();
  await tester.runAsync(onPressed);
  await tester.pump();
}

void _selectFile(String name, Uint8List bytes) {
  final tempRoot = Directory('tool/.tmp')..createSync(recursive: true);
  final directory = tempRoot.createTempSync('editor-image-import-');
  addTearDown(directory.deleteSync);
  final file = File(p.join(directory.path, name))..writeAsBytesSync(bytes);
  addTearDown(file.deleteSync);
  useFakeFilePicker(
    _PickedFile(PlatformFile(name: name, size: bytes.length, path: file.path)),
  );
}

class _PickedFile extends FilePicker {
  _PickedFile(this.file);

  final PlatformFile file;

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
  }) async => FilePickerResult([file]);
}
