import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../router/app_routes.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/internal_drag_protocol.dart';
import '../../utils/metadata_import_coordinator.dart';
import '../../utils/precise_ref_library_import_helper.dart';
import '../common/app_toast.dart';
import '../metadata/metadata_import_dialog.dart';
import 'dropped_image_inspector.dart';
import 'image_destination_dialog.dart';
import 'tag_library_drop_handler.dart';

@visibleForTesting
Future<T> runWithVibeNameController<T>(
  String initialText,
  Future<T> Function(TextEditingController controller) action,
) async {
  final controller = TextEditingController(text: initialText);
  try {
    return await action(controller);
  } finally {
    controller.dispose();
  }
}

@visibleForTesting
Future<void> appendDroppedCharacterReference({
  required GenerationParamsNotifier notifier,
  required Uint8List image,
}) {
  // The notifier stages these original bytes synchronously before it begins
  // Director Reference normalization.
  unawaited(
    notifier.addPreciseReferenceFromImage(
      image,
      type: PreciseRefType.characterAndStyle,
      strength: 1.0,
      fidelity: 1.0,
    ),
  );
  return Future<void>.value();
}

class GlobalDropActionCoordinator {
  GlobalDropActionCoordinator({
    required this.context,
    required this.ref,
    DroppedImageInspector inspector = const DroppedImageInspector(),
    this.openGenerationAfterAction = false,
    this.respectCurrentRouteDropTarget = true,
  }) : _inspector = inspector;

  final BuildContext context;
  final WidgetRef ref;
  final DroppedImageInspector _inspector;
  final bool openGenerationAfterAction;
  final bool respectCurrentRouteDropTarget;

  static const Set<String> _plainImageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
  };

  Future<void> handleDrop(PerformDropEvent event) async {
    var handledAny = false;
    for (final item in event.session.items) {
      if (!context.mounted) return;
      final internalPayload = resolveInternalHistoryDropPayload(
        item.localData,
        ref.read(imageGenerationNotifierProvider),
      );
      if (internalPayload != null) {
        handledAny = true;
        await processDroppedFile(internalPayload);
        continue;
      }

      final reader = item.dataReader;
      if (reader == null) continue;
      final fileData = await DroppedFileReader.read(
        reader,
        allowVibeFiles: true,
        logTag: 'DropHandler',
      );
      if (fileData != null) {
        handledAny = true;
        await processDroppedFile(fileData);
      }
    }
    if (!handledAny && context.mounted) {
      _showError(context.l10n.toast_unreadableDroppedImageSource);
    }
  }

  Future<void> processDroppedFile(DroppedFileData fileData) async {
    if (!context.mounted) return;
    final fileName = fileData.fileName;
    if (!VibeFileParser.isSupportedFile(fileName)) {
      _showError(context.l10n.drop_unsupportedFormat);
      return;
    }

    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    if (respectCurrentRouteDropTarget &&
        currentPath == AppRoutes.tagLibraryPage) {
      final originalBytes = await _resolveOriginalImageBytes(fileData);
      if (originalBytes == null || !context.mounted) return;
      await TagLibraryDropHandler.handle(
        context: context,
        ref: ref,
        fileName: fileName,
        bytes: originalBytes,
      );
      return;
    }

    if (respectCurrentRouteDropTarget &&
        currentPath == AppRoutes.preciseRefLibrary &&
        _isPlainImageFile(fileName)) {
      final originalBytes = await _resolveOriginalImageBytes(fileData);
      if (originalBytes == null || !context.mounted) return;
      await saveBytesToPreciseRefLibrary(
        ref,
        context,
        originalBytes,
        suggestedName: p.basenameWithoutExtension(fileName),
        type: ref.read(preciseRefLibraryNotifierProvider).typeFilter,
      );
      return;
    }

    final l10n = context.l10n;
    final inspection = await _inspector.inspect(fileData);
    if (!context.mounted) return;
    final detectedMetadata = inspection.metadataDetection.metadata;
    final destination = await ImageDestinationDialog.show(
      context,
      imageBytes: inspection.previewBytes,
      fileName: fileName,
      showExtractMetadata: detectedMetadata != null,
      metadata: detectedMetadata,
      metadataParseError: inspection.metadataDetection.parseError,
      detectedVibe: inspection.detectedVibe,
      isBundle: inspection.detectedVibes.length > 1,
    );
    if (destination == null || !context.mounted) return;

    var destinationBytes = inspection.previewBytes;
    if (fileData.imageBytesArePreview &&
        imageDestinationRequiresOriginalBytes(destination)) {
      final originalBytes = await _resolveOriginalImageBytes(fileData);
      if (originalBytes == null || !context.mounted) return;
      destinationBytes = originalBytes;
    }

    final actionCompleted = await _handleDestination(
      destination,
      fileName,
      destinationBytes,
      inspection.detectedVibe,
      inspection.detectedVibes,
      detectedMetadata,
      ref.read(generationParamsNotifierProvider.notifier),
      l10n,
    );
    if (actionCompleted &&
        openGenerationAfterAction &&
        _isGenerationDestination(destination) &&
        context.mounted) {
      context.go(AppRoutes.home);
    }
  }

  static bool _isGenerationDestination(ImageDestination destination) {
    return switch (destination) {
      ImageDestination.img2img ||
      ImageDestination.reversePrompt ||
      ImageDestination.vibeTransfer ||
      ImageDestination.vibeTransferReuse ||
      ImageDestination.vibeTransferRaw ||
      ImageDestination.characterReference ||
      ImageDestination.extractMetadata => true,
      ImageDestination.saveToVibeLibrary ||
      ImageDestination.addToQueue => false,
    };
  }

  static bool _isPlainImageFile(String fileName) {
    final lower = fileName.toLowerCase();
    return _plainImageExtensions.any(lower.endsWith);
  }

  Future<Uint8List?> _resolveOriginalImageBytes(
    DroppedFileData fileData,
  ) async {
    final bytes = await _inspector.resolveOriginalBytes(fileData);
    if (!context.mounted) return null;
    if (bytes == null) {
      _showError(context.l10n.toast_unreadableDroppedImageSource);
    }
    return bytes;
  }

  Future<bool> _handleDestination(
    ImageDestination destination,
    String fileName,
    Uint8List bytes,
    VibeReference? detectedVibe,
    List<VibeReference> detectedVibes,
    NaiImageMetadata? detectedMetadata,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    switch (destination) {
      case ImageDestination.img2img:
        await _handleImg2Img(bytes, l10n);
        return true;
      case ImageDestination.reversePrompt:
        await _handleReversePrompt(fileName, bytes, l10n);
        return true;
      case ImageDestination.vibeTransfer:
        return _handleVibeTransfer(fileName, bytes, notifier, l10n);
      case ImageDestination.vibeTransferReuse:
        if (detectedVibe == null) return false;
        return _handleVibeReuse(detectedVibe, notifier, l10n);
      case ImageDestination.vibeTransferRaw:
        return _handleVibeTransfer(
          fileName,
          bytes,
          notifier,
          l10n,
          forceRaw: true,
        );
      case ImageDestination.saveToVibeLibrary:
        if (detectedVibes.isNotEmpty) {
          await _handleSaveToVibeLibrary(detectedVibes, l10n);
        }
        return false;
      case ImageDestination.characterReference:
        await _handleCharacterReference(bytes, notifier, l10n);
        return true;
      case ImageDestination.extractMetadata:
        return _handleExtractMetadata(detectedMetadata, bytes, l10n);
      case ImageDestination.addToQueue:
        await _handleAddToQueue(detectedMetadata, bytes, l10n);
        return false;
    }
  }

  Future<void> _handleImg2Img(Uint8List bytes, AppLocalizations l10n) async {
    await ref
        .read(imageWorkflowControllerProvider.notifier)
        .replaceSourceImageAsync(bytes);
    if (context.mounted) AppToast.success(context, l10n.drop_addedToImg2Img);
  }

  Future<void> _handleReversePrompt(
    String fileName,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    await ref
        .read(reversePromptProvider.notifier)
        .addImage(bytes, name: fileName);
    if (context.mounted) {
      AppToast.success(context, l10n.drop_addedToReversePrompt);
    }
  }

  Future<bool> _handleVibeTransfer(
    String fileName,
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n, {
    bool forceRaw = false,
  }) async {
    try {
      final currentState = ref.read(generationParamsNotifierProvider);
      final currentCount = currentState.vibeReferencesV4.length;
      const maxCount = 16;
      final vibes = await VibeFileParser.parseFile(fileName, bytes);
      if (currentCount + vibes.length > maxCount) {
        if (context.mounted) {
          AppToast.warning(
            context,
            context.l10n.toast_styleReferenceLimit(maxCount),
          );
        }
        return false;
      }
      for (final vibe in vibes) {
        final vibeToAdd = forceRaw && vibe.vibeEncoding.isNotEmpty
            ? vibe.copyWith(
                vibeEncoding: '',
                rawImageData: bytes,
                sourceType: VibeSourceType.rawImage,
              )
            : vibe;
        notifier.addVibeReference(vibeToAdd);
      }
      if (context.mounted) {
        AppToast.success(
          context,
          _buildVibeMessage(currentCount, vibes.length, l10n),
        );
      }
      return true;
    } catch (error) {
      if (kDebugMode) {
        AppLogger.d('Error parsing vibe file: $error', 'DropHandler');
      }
      _showError(error.toString());
      return false;
    }
  }

  String _buildVibeMessage(
    int currentCount,
    int addedCount,
    AppLocalizations l10n,
  ) {
    if (currentCount > 0) {
      return l10n.toast_appendedStyleReferences(addedCount);
    }
    return addedCount == 1
        ? l10n.drop_addedToVibe
        : l10n.drop_addedMultipleToVibe(addedCount);
  }

  Future<bool> _handleVibeReuse(
    VibeReference vibe,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    final currentState = ref.read(generationParamsNotifierProvider);
    const maxCount = 16;
    if (currentState.vibeReferencesV4.length >= maxCount) {
      if (context.mounted) {
        AppToast.warning(
          context,
          context.l10n.toast_styleReferenceLimit(maxCount),
        );
      }
      return false;
    }
    notifier.addVibeReference(vibe);
    if (context.mounted) {
      final message = currentState.vibeReferencesV4.isNotEmpty
          ? l10n.toast_appendedPreencodedVibe
          : l10n.toast_addedPreencodedVibe;
      AppToast.success(context, message);
    }
    return true;
  }

  Future<void> _handleSaveToVibeLibrary(
    List<VibeReference> vibes,
    AppLocalizations l10n,
  ) async {
    if (vibes.isEmpty) return;
    final invalidVibes = vibes.where((vibe) => vibe.vibeEncoding.isEmpty);
    if (invalidVibes.isNotEmpty) {
      AppToast.warning(
        context,
        l10n.toast_vibesMissingEncoding(invalidVibes.length),
      );
      return;
    }

    final isBundle = vibes.length > 1;
    final dialogResult = await runWithVibeNameController(vibes.first.displayName, (
      nameController,
    ) async {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            isBundle
                ? '${l10n.vibe_saveToLibrary_saveAsBundle} (${vibes.length})'
                : l10n.vibe_saveToLibrary_title,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBundle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${l10n.vibe_saveToLibrary_saveAsBundleDescription(vibes.length)}:\n'
                    '${vibes.map((vibe) => '• ${vibe.displayName}').join('\n')}',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.vibe_saveToLibrary_nameLabel,
                  hintText: l10n.vibe_saveToLibrary_nameHint,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.common_cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(l10n.common_save),
            ),
          ],
        ),
      );
      return (confirmed: result == true, name: nameController.text.trim());
    });
    if (!dialogResult.confirmed || !context.mounted) return;
    final name = dialogResult.name;

    try {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      if (isBundle) {
        await storageService.saveBundleEntry(vibes, name: name);
      } else {
        await storageService.saveEntry(
          VibeLibraryEntry.fromVibeReference(name: name, vibeData: vibes.first),
        );
      }
      ref.read(vibeLibraryNotifierProvider.notifier).reload();
      if (context.mounted) {
        AppToast.success(
          context,
          isBundle
              ? l10n.toast_savedBundle(vibes.length)
              : l10n.toast_savedToVibeLibrary,
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.image_saveFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _handleCharacterReference(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
    AppLocalizations l10n,
  ) async {
    await appendDroppedCharacterReference(notifier: notifier, image: bytes);
    if (context.mounted) {
      AppToast.success(context, l10n.drop_addedToCharacterRef);
    }
  }

  Future<bool> _handleExtractMetadata(
    NaiImageMetadata? detectedMetadata,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    try {
      final metadata =
          detectedMetadata ??
          await ImageMetadataService().getMetadataFromBytes(bytes);
      if (metadata == null || !metadata.hasData) {
        if (context.mounted) {
          AppToast.warning(context, l10n.metadataImport_noDataFound);
        }
        return false;
      }
      if (!context.mounted) return false;
      final options = await MetadataImportDialog.show(
        context,
        metadata: metadata,
      );
      if (options == null || !context.mounted) return false;
      final appliedCount = await MetadataImportCoordinator.apply(
        read: ref.read,
        metadata: metadata,
        options: options,
        l10n: context.l10n,
      );
      if (!context.mounted) return false;
      if (appliedCount > 0) {
        AppToast.success(
          context,
          l10n.metadataImport_appliedCount(appliedCount),
        );
        return true;
      }
      AppToast.warning(context, l10n.metadataImport_noParamsSelected);
      return false;
    } catch (error) {
      if (kDebugMode) {
        AppLogger.d('Error extracting metadata: $error', 'DropHandler');
      }
      _showError(l10n.toast_extractMetadataFailed(error.toString()));
      return false;
    }
  }

  Future<void> _handleAddToQueue(
    NaiImageMetadata? detectedMetadata,
    Uint8List bytes,
    AppLocalizations l10n,
  ) async {
    try {
      final metadata =
          detectedMetadata ??
          await ImageMetadataService().getMetadataFromBytes(bytes);
      if (metadata == null || metadata.prompt.isEmpty) {
        if (context.mounted) {
          AppToast.warning(context, context.l10n.toast_noValidPromptFound);
        }
        return;
      }
      ref
          .read(replicationQueueNotifierProvider.notifier)
          .add(ReplicationTask.create(prompt: metadata.prompt));
      if (context.mounted) {
        final displayPrompt = metadata.prompt.length > 50
            ? '${metadata.prompt.substring(0, 50)}...'
            : metadata.prompt;
        AppToast.success(
          context,
          context.l10n.toast_addedToQueue(displayPrompt),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        AppLogger.d('Error adding to queue: $error', 'DropHandler');
      }
      _showError(l10n.toast_extractPromptFailed(error.toString()));
    }
  }

  void _showError(String message) {
    if (context.mounted) AppToast.error(context, message);
  }
}
