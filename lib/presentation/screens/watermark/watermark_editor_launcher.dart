import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/utils/localization_extension.dart';
import '../derivatives/derivative_editor_launcher.dart';
import 'watermark_editor_screen.dart';

class WatermarkEditorLauncher {
  const WatermarkEditorLauncher._();

  static final _config = DerivativeEditorConfig(
    kind: DerivativeKind.watermark,
    sourceMissingTitle: (context) => context.l10n.watermark_sourceMissing,
    chooseOriginalLabel: (context) => context.l10n.watermark_chooseOriginal,
    sampleFileName: 'watermark_preview.png',
    dialogWidth: 960,
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

  static Widget _buildPage(DerivativeEditorPage page) => WatermarkEditorScreen(
    sourceBytes: page.sourceBytes,
    sourceFileName: page.sourceFileName,
    sourcePath: page.sourcePath,
    defaultsOnly: page.defaultsOnly,
    onChooseSource: page.defaultsOnly ? null : _chooseSource,
  );

  static Future<WatermarkEditorSource?> _chooseSource() async {
    final selected = await DerivativeEditorLauncher.pickSource();
    if (selected == null) return null;
    return WatermarkEditorSource(
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
        const [Color(0xFF2B3241), Color(0xFF7D6B91), Color(0xFFD1A68A)],
        const [0, 0.55, 1],
      );
    canvas.drawRect(ui.Offset.zero & size, background);
    final glow = ui.Paint()
      ..color = const Color(0x44FFFFFF)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 90);
    canvas.drawCircle(const ui.Offset(820, 300), 180, glow);
  }
}
