import 'package:flutter/widgets.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/services/file_export_service.dart';
import '../../core/services/image_save_as_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/image_card_action.dart';

/// Save-as flows shared by generation cards, batch actions and the detail view.
class ImageSaveAsWorkflow {
  const ImageSaveAsWorkflow._();

  static const String _logTag = 'ImageSaveAs';

  static Future<void> saveOne(
    BuildContext context,
    ImageSaveAsSource source, {
    required bool preventOverwrite,
  }) async {
    final l10n = context.l10n;
    // The native dialog can outlive a card rebuilt by its list.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    try {
      final location = await ImageSaveAsService.saveOne(
        source,
        dialogTitle: l10n.image_saveAsDialogTitle,
        preventOverwrite: preventOverwrite,
      );
      if (location == null) return;
      AppToast.successOnOverlay(
        overlay,
        _returnsDocumentUris
            ? l10n.image_savedAsToChosenLocation
            : l10n.image_savedAs(location),
      );
    } catch (error, stackTrace) {
      AppLogger.e('Save-as failed', error, stackTrace, _logTag);
      AppToast.errorOnOverlay(overlay, l10n.image_saveFailed('$error'));
    }
  }

  /// Returns null when nothing was attempted, e.g. the folder dialog was
  /// cancelled.
  static Future<ImageCardBatchResult<ImageSaveAsSource>?> saveAllToFolder(
    BuildContext context,
    List<ImageSaveAsSource> sources,
  ) async {
    if (sources.isEmpty) return null;
    final l10n = context.l10n;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final directory = await _pickFolder(l10n, overlay);
    if (directory == null) return null;

    final result = await ImageCardBatchResult.execute<ImageSaveAsSource>(
      sources,
      (source) =>
          ImageSaveAsService.writeToDirectory(source, directory: directory),
    );
    for (final failure in result.failures.values) {
      AppLogger.e(
        'Save-as to folder failed',
        failure.error,
        failure.stackTrace,
        _logTag,
      );
    }

    final saved = result.succeeded.length;
    final failed = result.failures.length;
    if (failed == 0) {
      AppToast.successOnOverlay(
        overlay,
        _returnsDocumentUris
            ? l10n.image_savedAsToChosenFolder(saved)
            : l10n.image_savedAsToFolder(saved, directory),
      );
    } else {
      final firstError = '${result.failures.values.first.error}';
      if (saved == 0) {
        AppToast.errorOnOverlay(overlay, l10n.image_saveFailed(firstError));
      } else {
        AppToast.warningOnOverlay(
          overlay,
          l10n.image_savedAsPartial(saved, failed, firstError),
        );
      }
    }
    return result;
  }

  static Future<String?> _pickFolder(
    AppLocalizations l10n,
    OverlayState? overlay,
  ) async {
    try {
      final directory = await FileExportService.pickExportDirectory(
        dialogTitle: l10n.image_saveAsFolderDialogTitle,
      );
      return directory == null || directory.isEmpty ? null : directory;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Save-as folder selection failed',
        error,
        stackTrace,
        _logTag,
      );
      AppToast.errorOnOverlay(overlay, l10n.image_saveFailed('$error'));
      return null;
    }
  }

  // Android returns content:// URIs, which mean nothing to users as paths.
  static bool get _returnsDocumentUris =>
      PlatformCapabilities.current.supportsDocumentFileExport;
}
