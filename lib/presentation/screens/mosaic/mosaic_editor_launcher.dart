import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/utils/localization_extension.dart';
import '../derivatives/derivative_editor_launcher.dart';
import 'mosaic_editor_screen.dart';

class MosaicEditorLauncher {
  const MosaicEditorLauncher._();

  static final _config = DerivativeEditorConfig(
    kind: DerivativeKind.mosaic,
    sourceMissingTitle: (context) => context.l10n.mosaic_sourceMissing,
    sourceMissingHint: (context) => context.l10n.mosaic_sourceMissingHint,
    chooseOriginalLabel: (context) => context.l10n.mosaic_chooseOriginal,
    sampleFileName: 'redaction_preview.png',
    dialogWidth: 1320,
    maxDialogHeight: 920,
    paintSample: _paintSample,
    buildPage: _buildPage,
  );

  static Future<String?> pickSourceAndOpen({required BuildContext context}) =>
      DerivativeEditorLauncher.pickSourceAndOpen(
        context: context,
        config: _config,
      );

  static Future<String?> open({
    required BuildContext context,
    required Uint8List sourceBytes,
    required String sourceFileName,
    String? sourcePath,
  }) => DerivativeEditorLauncher.open(
    context: context,
    config: _config,
    sourceBytes: sourceBytes,
    sourceFileName: sourceFileName,
    sourcePath: sourcePath,
  );

  static Future<String?> openForLocalPath({
    required BuildContext context,
    required String path,
    Uint8List? fallbackBytes,
  }) => DerivativeEditorLauncher.openForLocalPath(
    context: context,
    config: _config,
    path: path,
    fallbackBytes: fallbackBytes,
  );

  static Future<void> editDefaults({required BuildContext context}) =>
      DerivativeEditorLauncher.editDefaults(context: context, config: _config);

  static Widget _buildPage(DerivativeEditorPage page) => MosaicEditorScreen(
    sourceBytes: page.sourceBytes,
    sourceFileName: page.sourceFileName,
    sourcePath: page.sourcePath,
    defaultsOnly: page.defaultsOnly,
    onChooseSource: page.defaultsOnly ? null : _chooseSource,
  );

  static Future<MosaicEditorSource?> _chooseSource() async {
    final selected = await DerivativeEditorLauncher.pickSource();
    if (selected == null) return null;
    return MosaicEditorSource(
      bytes: selected.bytes,
      fileName: selected.fileName,
      path: selected.path,
    );
  }

  static void _paintSample(ui.Canvas canvas, ui.Size size) {
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
  }
}
