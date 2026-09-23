import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';

class DerivativeEditorSource {
  const DerivativeEditorSource({
    required this.bytes,
    required this.fileName,
    required this.path,
  });

  final Uint8List bytes;
  final String fileName;
  final String path;
}

class DerivativeEditorPage {
  const DerivativeEditorPage({
    required this.sourceBytes,
    required this.sourceFileName,
    required this.sourcePath,
    required this.defaultsOnly,
  });

  final Uint8List sourceBytes;
  final String sourceFileName;
  final String? sourcePath;
  final bool defaultsOnly;
}

typedef DerivativeEditorPageBuilder =
    Widget Function(DerivativeEditorPage page);
typedef DerivativeSamplePainter = void Function(ui.Canvas canvas, ui.Size size);
typedef DerivativeEditorText = String Function(BuildContext context);

/// Per-editor differences consumed by [DerivativeEditorLauncher].
class DerivativeEditorConfig {
  const DerivativeEditorConfig({
    required this.kind,
    required this.sourceMissingTitle,
    required this.chooseOriginalLabel,
    required this.sampleFileName,
    required this.paintSample,
    required this.buildPage,
    required this.dialogWidth,
    this.sourceMissingHint,
    this.maxDialogHeight,
  });

  final DerivativeKind kind;
  final DerivativeEditorText sourceMissingTitle;
  final DerivativeEditorText? sourceMissingHint;
  final DerivativeEditorText chooseOriginalLabel;
  final String sampleFileName;
  final DerivativeSamplePainter paintSample;
  final DerivativeEditorPageBuilder buildPage;
  final double dialogWidth;
  final double? maxDialogHeight;
}

/// Opens a derivative editor on the shared adaptive surface.
class DerivativeEditorLauncher {
  const DerivativeEditorLauncher._();

  static const sampleSize = ui.Size(1200, 800);

  static Future<String?> pickSourceAndOpen({
    required BuildContext context,
    required DerivativeEditorConfig config,
  }) async {
    final selected = await pickSource();
    if (selected == null || !context.mounted) return null;
    return open(
      context: context,
      config: config,
      sourceBytes: selected.bytes,
      sourceFileName: selected.fileName,
      sourcePath: selected.path,
    );
  }

  static Future<String?> open({
    required BuildContext context,
    required DerivativeEditorConfig config,
    required Uint8List sourceBytes,
    required String sourceFileName,
    String? sourcePath,
  }) => _present(
    context: context,
    config: config,
    page: DerivativeEditorPage(
      sourceBytes: sourceBytes,
      sourceFileName: sourceFileName,
      sourcePath: sourcePath,
      defaultsOnly: false,
    ),
  );

  static Future<String?> openForLocalPath({
    required BuildContext context,
    required DerivativeEditorConfig config,
    required String path,
    Uint8List? fallbackBytes,
  }) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final registry = DerivativeRegistry(
      container.read(localStorageServiceProvider),
      config.kind,
    );
    final link = registry.find(path);
    final inferredDerivative =
        link == null && config.kind.matchesFileName(path);
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
      final hint = config.sourceMissingHint?.call(context);
      final choose = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(config.sourceMissingTitle(context)),
          content: hint == null ? null : Text(hint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(config.chooseOriginalLabel(context)),
            ),
          ],
        ),
      );
      if (choose != true) return null;
      final selected = await pickSource();
      if (selected == null) return null;
      source = File(selected.path);
      resolvedSourcePath = selected.path;
      bytes = selected.bytes;
    }
    if (!context.mounted) return null;
    return open(
      context: context,
      config: config,
      sourceBytes: bytes,
      sourceFileName: p.basename(source.path),
      sourcePath: resolvedSourcePath,
    );
  }

  static Future<void> editDefaults({
    required BuildContext context,
    required DerivativeEditorConfig config,
  }) async {
    final sample = await buildSampleImage(config.paintSample);
    if (!context.mounted) return;
    await _present(
      context: context,
      config: config,
      page: DerivativeEditorPage(
        sourceBytes: sample,
        sourceFileName: config.sampleFileName,
        sourcePath: null,
        defaultsOnly: true,
      ),
    );
  }

  static Future<DerivativeEditorSource?> pickSource() async {
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
    return DerivativeEditorSource(
      bytes: await file.readAsBytes(),
      fileName: p.basename(path),
      path: path,
    );
  }

  static Future<Uint8List> buildSampleImage(
    DerivativeSamplePainter paint, {
    ui.Size size = sampleSize,
  }) async {
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder), size);
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

  static Future<String?> _present({
    required BuildContext context,
    required DerivativeEditorConfig config,
    required DerivativeEditorPage page,
  }) {
    final child = config.buildPage(page);
    return AdaptivePresenter.showForm<String>(
      context: context,
      dialogWidth: config.dialogWidth,
      maxCenteredHeight: config.maxDialogHeight,
      barrierDismissible: false,
      showHeader: false,
      builder: (context, scrollController) => child,
    );
  }
}
