import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/localization_extension.dart';
import 'mosaic_editor_screen.dart';

class MosaicEditorLauncher {
  const MosaicEditorLauncher._();

  static Future<String?> pickSourceAndOpen({
    required BuildContext context,
  }) async {
    final selected = await _pickSource();
    final path = selected?.path;
    if (selected == null || path == null || !context.mounted) return null;
    return open(
      context: context,
      sourceBytes: selected.bytes,
      sourceFileName: selected.fileName,
      sourcePath: path,
    );
  }

  static Future<String?> open({
    required BuildContext context,
    required Uint8List sourceBytes,
    required String sourceFileName,
    String? sourcePath,
  }) => _present(
    context: context,
    sourceBytes: sourceBytes,
    sourceFileName: sourceFileName,
    sourcePath: sourcePath,
    defaultsOnly: false,
  );

  static Future<String?> openForLocalPath({
    required BuildContext context,
    required String path,
    Uint8List? fallbackBytes,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final registry = MosaicDerivativeRegistry(
      container.read(localStorageServiceProvider),
    );
    final link = registry.find(path);
    final inferredDerivative =
        link == null && MosaicDerivativeRegistry.looksLikeDerivativePath(path);
    var source = File(link?.sourcePath ?? path);
    String? resolvedSourcePath;
    Uint8List? bytes;
    if (!inferredDerivative && await source.exists()) {
      bytes = await source.readAsBytes();
      resolvedSourcePath = source.path;
    } else if (!inferredDerivative && link == null && fallbackBytes != null) {
      bytes = fallbackBytes;
    } else {
      if (!context.mounted) return null;
      final choose = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.mosaic_sourceMissing),
          content: Text(context.l10n.mosaic_sourceMissingHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.mosaic_chooseOriginal),
            ),
          ],
        ),
      );
      if (choose != true) return null;
      final selected = await _pickSource();
      final pickedPath = selected?.path;
      if (selected == null || pickedPath == null) return null;
      source = File(pickedPath);
      resolvedSourcePath = pickedPath;
      bytes = selected.bytes;
    }
    if (!context.mounted || bytes == null) return null;
    return open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: p.basename(source.path),
      sourcePath: resolvedSourcePath,
    );
  }

  static Future<void> editDefaults({required BuildContext context}) async {
    final sample = await _buildSampleImage();
    if (!context.mounted) return;
    await _present(
      context: context,
      sourceBytes: sample,
      sourceFileName: 'redaction_preview.png',
      defaultsOnly: true,
    );
  }

  static Future<String?> _present({
    required BuildContext context,
    required Uint8List sourceBytes,
    required String sourceFileName,
    required bool defaultsOnly,
    String? sourcePath,
  }) {
    final page = MosaicEditorScreen(
      sourceBytes: sourceBytes,
      sourceFileName: sourceFileName,
      sourcePath: sourcePath,
      defaultsOnly: defaultsOnly,
      onChooseSource: defaultsOnly ? null : _pickSource,
    );
    if (MediaQuery.sizeOf(context).width >= 840) {
      return showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320, maxHeight: 920),
            child: page,
          ),
        ),
      );
    }
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => page, fullscreenDialog: true),
    );
  }

  static Future<MosaicEditorSource?> _pickSource() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return MosaicEditorSource(
      bytes: await file.readAsBytes(),
      fileName: p.basename(path),
      path: path,
    );
  }

  static Future<Uint8List> _buildSampleImage() async {
    const size = ui.Size(1200, 800);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final background = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(size.width, size.height),
        const [Color(0xFF1D2636), Color(0xFF566C8D), Color(0xFFC88E7A)],
        const [0, 0.52, 1],
      );
    canvas.drawRect(ui.Offset.zero & size, background);
    canvas.drawCircle(
      const ui.Offset(390, 340),
      150,
      ui.Paint()..color = const Color(0xFFE9C7A9),
    );
    canvas.drawCircle(
      const ui.Offset(345, 315),
      18,
      ui.Paint()..color = const Color(0xFF2D3441),
    );
    canvas.drawCircle(
      const ui.Offset(435, 315),
      18,
      ui.Paint()..color = const Color(0xFF2D3441),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(655, 205, 350, 220),
        const ui.Radius.circular(30),
      ),
      ui.Paint()..color = const Color(0x44FFFFFF),
    );
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
