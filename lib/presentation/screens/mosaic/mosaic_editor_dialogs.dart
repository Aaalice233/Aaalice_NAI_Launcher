import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/derivatives/derivative_registry.dart';
import '../../../core/derivatives/derivative_render.dart';
import '../../../core/mosaic/mosaic_render_service.dart';
import '../../../core/services/native_share_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../widgets/image_editor/widgets/color_picker.dart';
import '../derivatives/derivative_copy_save_run.dart';
import '../derivatives/derivative_copy_saver.dart';

Future<void> rememberMosaicStyle(
  MosaicSettingsNotifier notifier,
  MosaicSettings settings,
) async {
  try {
    await notifier.saveDefaults(settings);
  } on Object catch (error, stackTrace) {
    AppLogger.e(
      'Redacted copy saved but its style was not remembered',
      error,
      stackTrace,
      'MosaicEditor',
    );
  }
}

Future<void> showMosaicSavedDialog({
  required BuildContext context,
  required DerivativeRenderedCopy result,
  required String output,
  required Future<void> Function(DerivativeRenderedCopy result) onShare,
}) async {
  final l10n = context.l10n;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.mosaic_saved),
      content: SelectableText(output),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final uri = output.contains('://')
                ? Uri.parse(output)
                : Uri.file(output);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.mosaic_open),
        ),
        TextButton.icon(
          onPressed: () => onShare(result),
          icon: const Icon(Icons.share_outlined),
          label: Text(l10n.mosaic_share),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.common_close),
        ),
      ],
    ),
  );
}

Future<void> shareMosaicRenderedCopy({
  required WidgetRef ref,
  required DerivativeRenderedCopy result,
}) async {
  final stripMetadata = ref
      .read(shareImageSettingsProvider)
      .effectiveStripMetadataForCopyAndDrag;
  final prepared = await ImageShareSanitizer.prepareForCopyOrDragInBackground(
    result.bytes,
    fileName: result.fileName,
    stripMetadata: stripMetadata,
  );
  await NativeShareService.shareImage(
    bytes: prepared.bytes,
    fileName: prepared.fileName,
    mimeType: prepared.mimeType,
  );
}

Future<void> showMosaicColorPickerDialog({
  required BuildContext context,
  required Color initial,
  required ValueChanged<Color> onChanged,
}) async {
  final l10n = context.l10n;
  var selected = initial;
  final result = await showDialog<Color>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      title: Text(l10n.editor_toolColorPicker),
      content: SizedBox(
        width: math.min(320, MediaQuery.sizeOf(dialogContext).width - 64),
        child: HSVColorPicker(
          color: initial,
          hexLabel: l10n.editor_colorHex,
          saturationBrightnessLabel: l10n.editor_colorSaturationBrightness,
          hueLabel: l10n.editor_colorHue,
          hueHeight: 48,
          onColorChanged: (value) => selected = value,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(selected),
          child: Text(l10n.common_confirm),
        ),
      ],
    ),
  );
  if (result != null) onChanged(result);
}

Future<void> executeMosaicSaveCopy({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
  required MosaicRenderRequest request,
  required String? sourcePath,
  required MosaicRenderOperation renderCopy,
  required ValueChanged<DerivativeCopySaveRun?> onSaveRunChanged,
  required ValueChanged<Object> onError,
}) async {
  final l10n = context.l10n;
  final settingsNotifier = ref.read(mosaicSettingsProvider.notifier);
  final run = DerivativeCopySaveRun(
    saver: ref.read(derivativeCopySaverProvider(DerivativeKind.mosaic)),
    notices: DerivativeCopySaveNotices.capture(
      context,
      saved: l10n.mosaic_saved,
      failed: l10n.mosaic_failedGeneric,
      systemGalleryFailed: l10n.mosaic_systemGalleryExportFailed,
      galleryIndexFailed: l10n.mosaic_galleryRefreshFailed,
    ),
  );
  onSaveRunChanged(run);
  final outcome = await run.save(
    render: (cancellationToken) =>
        renderCopy(request, cancellationToken: cancellationToken),
    sourceBytes: request.sourceBytes,
    sourcePath: sourcePath,
  );
  if (outcome case DerivativeCopyFailed(:final error, :final stackTrace)) {
    AppLogger.e(
      'Failed to create redacted copy',
      error,
      stackTrace,
      'MosaicEditor',
    );
  }
  if (outcome is DerivativeCopySaved && request.settings.rememberLastStyle) {
    unawaited(rememberMosaicStyle(settingsNotifier, request.settings));
  }
  if (run.isClosed || !isMounted() || !context.mounted) return;
  onSaveRunChanged(null);
  switch (outcome) {
    case DerivativeCopySaved(:final copy, :final outputPath):
      await showMosaicSavedDialog(
        context: context,
        result: copy,
        output: outputPath,
        onShare: (rendered) =>
            shareMosaicRenderedCopy(ref: ref, result: rendered),
      );
      if (isMounted() && context.mounted) {
        Navigator.of(context).pop(outputPath);
      }
    case DerivativeCopyCancelled():
      return;
    case DerivativeCopyFailed(:final error):
      onError('${l10n.mosaic_failedGeneric}\n$error');
  }
}
