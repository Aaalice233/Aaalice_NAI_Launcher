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
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/reverse_prompt_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../../router/app_routes.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/internal_drag_protocol.dart';
import '../../services/image_metadata_import_workflow.dart';
import '../../utils/precise_ref_library_import_helper.dart';
import '../common/app_toast.dart';
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
Future<String?> showVibeLibraryNamingForm({
  required BuildContext context,
  required List<VibeReference> vibes,
  required String initialName,
}) {
  final l10n = context.l10n;
  final isBundle = vibes.length > 1;
  return AdaptivePresenter.showForm<String>(
    context: context,
    title: isBundle
        ? '${l10n.vibe_saveToLibrary_saveAsBundle} (${vibes.length})'
        : l10n.vibe_saveToLibrary_title,
    sideSheetWidth: 520,
    builder: (dialogContext, scrollController) => _VibeLibraryNamingForm(
      vibes: vibes,
      initialName: initialName,
      scrollController: scrollController,
    ),
  );
}

class _VibeLibraryNamingForm extends StatefulWidget {
  const _VibeLibraryNamingForm({
    required this.vibes,
    required this.initialName,
    required this.scrollController,
  });

  final List<VibeReference> vibes;
  final String initialName;
  final ScrollController scrollController;

  @override
  State<_VibeLibraryNamingForm> createState() => _VibeLibraryNamingFormState();
}

class _VibeLibraryNamingFormState extends State<_VibeLibraryNamingForm> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBundle = widget.vibes.length > 1;
    return ListView(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        if (isBundle) ...[
          Text(
            '${l10n.vibe_saveToLibrary_saveAsBundleDescription(widget.vibes.length)}:\n'
            '${widget.vibes.map((vibe) => '• ${vibe.displayName}').join('\n')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const ValueKey('drop-vibe-library-name-field'),
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.vibe_saveToLibrary_nameLabel,
            hintText: l10n.vibe_saveToLibrary_nameHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.common_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('drop-vibe-library-save'),
              onPressed: _submit,
              child: Text(l10n.common_save),
            ),
          ],
        ),
      ],
    );
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
      ImageDestination.characterReference => true,
      // The shared metadata workflow owns navigation after its second dialog.
      ImageDestination.extractMetadata ||
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
    final name = await showVibeLibraryNamingForm(
      context: context,
      vibes: vibes,
      initialName: vibes.first.displayName,
    );
    if (name == null || !context.mounted) return;

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
      final result = await ImageMetadataImportWorkflow.shared.run(
        context: context,
        read: ref.read,
        metadata: metadata,
      );
      return result == ImageMetadataImportResult.applied;
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
