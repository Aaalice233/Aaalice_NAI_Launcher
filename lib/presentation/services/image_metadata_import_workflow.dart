import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/metadata_import_selection_store.dart';
import '../../l10n/app_localizations.dart';
import '../router/app_routes.dart';
import '../providers/fixed_tags_provider.dart';
import '../utils/fixed_tag_import_resolution.dart';
import '../utils/metadata_import_coordinator.dart';
import '../utils/prompt_preset_import_utils.dart' show ProviderReader;
import '../widgets/common/app_toast.dart';
import '../widgets/metadata/metadata_import_dialog.dart';

enum ImageMetadataImportResult {
  cancelled,
  noMetadata,
  noParametersSelected,
  characterModelConflict,
  characterLimitReached,
  applied,
}

typedef ImageMetadataReader =
    Future<NaiImageMetadata?> Function(Uint8List bytes);
typedef MetadataImportOptionsPicker =
    Future<MetadataImportOptions?> Function(
      BuildContext context,
      NaiImageMetadata metadata,
      MetadataImportOptions initialOptions,
    );
typedef MetadataImportApplier =
    Future<MetadataImportOutcome> Function(
      ProviderReader read,
      NaiImageMetadata metadata,
      MetadataImportOptions options,
      AppLocalizations l10n,
    );
typedef MetadataImportResultReporter =
    void Function(
      BuildContext context,
      ImageMetadataImportResult result,
      MetadataImportOutcome outcome,
    );
typedef GenerationPageOpener = void Function(BuildContext context);

/// Reusable image-metadata import flow for direct byte-based entry points.
class ImageMetadataImportWorkflow {
  ImageMetadataImportWorkflow({
    ImageMetadataReader? metadataReader,
    MetadataImportOptionsPicker? optionsPicker,
    MetadataImportApplier? metadataApplier,
    MetadataImportResultReporter? resultReporter,
    GenerationPageOpener? generationPageOpener,
  }) : _metadataReader =
           metadataReader ?? ImageMetadataService().getMetadataFromBytes,
       _optionsPicker = optionsPicker,
       _metadataApplier = metadataApplier,
       _resultReporter = resultReporter ?? _reportResult,
       _generationPageOpener =
           generationPageOpener ?? ((context) => context.go(AppRoutes.home));

  static final ImageMetadataImportWorkflow shared =
      ImageMetadataImportWorkflow();

  final ImageMetadataReader _metadataReader;
  final MetadataImportOptionsPicker? _optionsPicker;
  final MetadataImportApplier? _metadataApplier;
  final MetadataImportResultReporter _resultReporter;
  final GenerationPageOpener _generationPageOpener;

  Future<ImageMetadataImportResult> run({
    required BuildContext context,
    required ProviderReader read,
    Uint8List? bytes,
    NaiImageMetadata? metadata,
    bool openGenerationPage = true,
  }) async {
    assert(bytes != null || metadata != null);
    final parsedMetadata = metadata ?? await _metadataReader(bytes!);
    if (!context.mounted) return ImageMetadataImportResult.cancelled;

    if (parsedMetadata == null || !parsedMetadata.hasData) {
      _resultReporter(
        context,
        ImageMetadataImportResult.noMetadata,
        const MetadataImportOutcome(0),
      );
      return ImageMetadataImportResult.noMetadata;
    }

    final resolution = resolveFixedTagImport(
      metadata: parsedMetadata,
      entries: read(fixedTagsNotifierProvider).entries,
    );
    final resolvedMetadata = resolution.metadata;
    final selectionStore = read(metadataImportSelectionStoreProvider);
    final initialOptions = selectionStore.load();
    final options = _optionsPicker == null
        ? await MetadataImportDialog.show(
            context,
            metadata: resolvedMetadata,
            fixedTagResolution: resolution,
            initialOptions: initialOptions,
          )
        : await _optionsPicker(context, resolvedMetadata, initialOptions);
    if (options == null) return ImageMetadataImportResult.cancelled;
    await _rememberSelection(selectionStore, options);
    if (!context.mounted) return ImageMetadataImportResult.cancelled;

    final outcome = _metadataApplier == null
        ? await MetadataImportCoordinator.apply(
            read: read,
            metadata: resolvedMetadata,
            options: options,
            l10n: context.l10n,
            fixedTagResolution: resolution,
          )
        : await _metadataApplier(read, resolvedMetadata, options, context.l10n);
    if (!context.mounted) return ImageMetadataImportResult.cancelled;

    final result = switch (outcome) {
      MetadataImportOutcome(characterConflictLimit: != null) =>
        ImageMetadataImportResult.characterModelConflict,
      MetadataImportOutcome(appliedCount: 0, characterAppend: != null) =>
        ImageMetadataImportResult.characterLimitReached,
      MetadataImportOutcome(appliedCount: 0) =>
        ImageMetadataImportResult.noParametersSelected,
      _ => ImageMetadataImportResult.applied,
    };
    _resultReporter(context, result, outcome);
    if (result == ImageMetadataImportResult.applied && openGenerationPage) {
      _generationPageOpener(context);
    }
    return result;
  }

  // 记忆写入失败不能拦下用户已确认的导入。
  static Future<void> _rememberSelection(
    MetadataImportSelectionStore store,
    MetadataImportOptions options,
  ) async {
    try {
      await store.save(options);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to remember metadata import selection',
        error,
        stackTrace,
        'MetadataImport',
      );
    }
  }

  static void _reportResult(
    BuildContext context,
    ImageMetadataImportResult result,
    MetadataImportOutcome outcome,
  ) {
    final l10n = context.l10n;
    switch (result) {
      case ImageMetadataImportResult.characterModelConflict:
        final limit = outcome.characterConflictLimit!;
        final count = outcome.existingCharacterCount;
        final message = count == null
            ? l10n.metadataImport_characterModelConflict(limit)
            : l10n.metadataImport_characterAppendModelConflict(count, limit);
        AppToast.warning(context, message);
        return;
      case ImageMetadataImportResult.noMetadata:
        AppToast.warning(context, l10n.metadataImport_noDataFound);
        return;
      case ImageMetadataImportResult.noParametersSelected:
        AppToast.warning(context, l10n.metadataImport_noParamsSelected);
        return;
      case ImageMetadataImportResult.characterLimitReached:
      case ImageMetadataImportResult.applied:
        final append = outcome.characterAppend;
        final applied = l10n.metadataImport_appliedCount(outcome.appliedCount);
        if (append != null && append.skipped > 0) {
          final counts = l10n.metadataImport_characterAppendResult(
            append.added,
            append.skipped,
            append.limit,
          );
          AppToast.warning(
            context,
            outcome.appliedCount == 0 ? counts : '$applied\n$counts',
          );
        } else {
          AppToast.success(context, applied);
        }
        return;
      case ImageMetadataImportResult.cancelled:
        return;
    }
  }
}
