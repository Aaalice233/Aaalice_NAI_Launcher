import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/metadata/metadata_import_options.dart';
import '../../data/services/image_metadata_service.dart';
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
  applied,
}

typedef ImageMetadataReader =
    Future<NaiImageMetadata?> Function(Uint8List bytes);
typedef MetadataImportOptionsPicker =
    Future<MetadataImportOptions?> Function(
      BuildContext context,
      NaiImageMetadata metadata,
    );
typedef MetadataImportApplier =
    Future<int> Function(
      ProviderReader read,
      NaiImageMetadata metadata,
      MetadataImportOptions options,
      AppLocalizations l10n,
    );
typedef MetadataImportResultReporter =
    void Function(
      BuildContext context,
      ImageMetadataImportResult result,
      int appliedCount,
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
      _resultReporter(context, ImageMetadataImportResult.noMetadata, 0);
      return ImageMetadataImportResult.noMetadata;
    }

    final resolution = resolveFixedTagImport(
      metadata: parsedMetadata,
      entries: read(fixedTagsNotifierProvider).entries,
    );
    final resolvedMetadata = resolution.metadata;
    final options = _optionsPicker == null
        ? await MetadataImportDialog.show(
            context,
            metadata: resolvedMetadata,
            fixedTagResolution: resolution,
          )
        : await _optionsPicker(context, resolvedMetadata);
    if (options == null || !context.mounted) {
      return ImageMetadataImportResult.cancelled;
    }

    final appliedCount = _metadataApplier == null
        ? await MetadataImportCoordinator.apply(
            read: read,
            metadata: resolvedMetadata,
            options: options,
            l10n: context.l10n,
            fixedTagResolution: resolution,
          )
        : await _metadataApplier(read, resolvedMetadata, options, context.l10n);
    if (!context.mounted) return ImageMetadataImportResult.cancelled;

    if (appliedCount == 0) {
      _resultReporter(
        context,
        ImageMetadataImportResult.noParametersSelected,
        0,
      );
      return ImageMetadataImportResult.noParametersSelected;
    }

    _resultReporter(context, ImageMetadataImportResult.applied, appliedCount);
    if (openGenerationPage) _generationPageOpener(context);
    return ImageMetadataImportResult.applied;
  }

  static void _reportResult(
    BuildContext context,
    ImageMetadataImportResult result,
    int appliedCount,
  ) {
    switch (result) {
      case ImageMetadataImportResult.noMetadata:
        AppToast.warning(context, context.l10n.metadataImport_noDataFound);
        return;
      case ImageMetadataImportResult.noParametersSelected:
        AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
        return;
      case ImageMetadataImportResult.applied:
        AppToast.success(
          context,
          context.l10n.metadataImport_appliedCount(appliedCount),
        );
        return;
      case ImageMetadataImportResult.cancelled:
        return;
    }
  }
}
