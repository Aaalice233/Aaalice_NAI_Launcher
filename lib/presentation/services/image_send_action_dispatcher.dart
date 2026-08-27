import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../../core/utils/nai_resolution_adapter.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/services/image_metadata_service.dart';
import '../providers/fixed_tags_provider.dart';
import '../providers/image_generation_provider.dart';
import '../providers/reverse_prompt_provider.dart';
import '../router/app_router.dart';
import '../utils/fixed_tag_metadata_matcher.dart';
import '../utils/krita_send_helper.dart';
import '../utils/local_gallery_reference_factory.dart';
import '../utils/metadata_import_coordinator.dart';
import '../utils/precise_ref_library_import_helper.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/precise_reference_type_dialog.dart';
import '../widgets/discord_share/discord_share_dialog.dart';
import '../widgets/gallery/local_image_context_menu.dart';
import '../widgets/metadata/metadata_import_dialog.dart';
import 'image_workflow_launcher.dart';

/// Dispatches the reusable "send image to..." actions shared by image menus.
class ImageSendActionDispatcher {
  const ImageSendActionDispatcher._();

  static Future<void> handle({
    required BuildContext context,
    required WidgetRef ref,
    required LocalImageContextAction action,
    required String fileName,
    required Future<Uint8List> Function() loadBytes,
  }) async {
    try {
      final bytes = await loadBytes();
      if (!context.mounted) return;

      switch (action) {
        case LocalImageContextAction.sendToTextToImage:
        case LocalImageContextAction.importMetadata:
          await _importMetadata(context, ref, bytes);
        case LocalImageContextAction.sendToImg2Img:
          ImageWorkflowLauncher.openImageToImage(ref, bytes);
          context.go(AppRoutes.home);
          AppToast.success(
            context,
            context.l10n.localGallery_sentToImageToImage,
          );
        case LocalImageContextAction.sendToReversePrompt:
          await ref
              .read(reversePromptProvider.notifier)
              .addImage(bytes, name: fileName);
          if (!context.mounted) return;
          context.go(AppRoutes.home);
          AppToast.success(
            context,
            context.l10n.localGallery_sentToReversePrompt,
          );
        case LocalImageContextAction.sendToStyleTransfer:
          _sendToStyleTransfer(context, ref, bytes, fileName);
        case LocalImageContextAction.sendToPreciseReference:
          await _sendToPreciseReference(context, ref, bytes);
        case LocalImageContextAction.saveToPreciseRefLibrary:
          await saveBytesToPreciseRefLibrary(
            ref,
            context,
            bytes,
            suggestedName: _baseName(fileName),
          );
        case LocalImageContextAction.sendToKrita:
          KritaSendHelper.sendImageBytes(context, ref, bytes, name: fileName);
        case LocalImageContextAction.upscale:
          ImageWorkflowLauncher.openUpscale(ref, bytes);
          context.go(AppRoutes.home);
          AppToast.info(context, context.l10n.gallery_upscalePanelLoaded);
        case LocalImageContextAction.shareToDiscord:
          await _shareToDiscord(context, ref, bytes, fileName);
        case LocalImageContextAction.copyPrompt:
        case LocalImageContextAction.copySeed:
        case LocalImageContextAction.showInFolder:
        case LocalImageContextAction.delete:
          return;
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Image send action failed',
        error,
        stackTrace,
        'ImageSendAction',
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.localGallery_sendFailed('$error'));
      }
    }
  }

  static Future<void> _importMetadata(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
  ) async {
    final metadata = await ImageMetadataService().getMetadataFromBytes(bytes);
    if (!context.mounted) return;
    if (metadata == null || !metadata.hasData) {
      AppToast.warning(context, context.l10n.metadataImport_noDataFound);
      return;
    }
    final options = await MetadataImportDialog.show(
      context,
      metadata: metadata,
    );
    if (options == null || !context.mounted) return;
    final appliedCount = await MetadataImportCoordinator.apply(
      read: ref.read,
      metadata: metadata,
      options: options,
      l10n: context.l10n,
    );
    if (!context.mounted) return;
    if (appliedCount == 0) {
      AppToast.warning(context, context.l10n.metadataImport_noParamsSelected);
      return;
    }
    AppToast.success(
      context,
      context.l10n.metadataImport_appliedCount(appliedCount),
    );
    context.go(AppRoutes.home);
  }

  static void _sendToStyleTransfer(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
    String fileName,
  ) {
    const maxCount = 16;
    final currentCount = ref
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .length;
    if (currentCount >= maxCount) {
      AppToast.warning(
        context,
        context.l10n.toast_styleReferenceLimit(maxCount),
      );
      return;
    }
    ref
        .read(generationParamsNotifierProvider.notifier)
        .addVibeReference(
          LocalGalleryReferenceFactory.createRawStyleReference(
            fileName: fileName,
            imageBytes: bytes,
          ),
        );
    context.go(AppRoutes.home);
    AppToast.success(
      context,
      currentCount == 0
          ? context.l10n.drop_addedToVibe
          : context.l10n.toast_appendedStyleReferences(1),
    );
  }

  static Future<void> _sendToPreciseReference(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
  ) async {
    final selectedType = await PreciseReferenceTypeDialog.show(context);
    if (selectedType == null || !context.mounted) return;
    unawaited(
      ref
          .read(generationParamsNotifierProvider.notifier)
          .addPreciseReferenceFromImage(
            bytes,
            type: selectedType,
            strength: 1.0,
            fidelity: 1.0,
          ),
    );
    context.go(AppRoutes.home);
    AppToast.success(context, context.l10n.drop_addedToCharacterRef);
  }

  static Future<void> _shareToDiscord(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
    String fileName,
  ) async {
    NaiImageMetadata? metadata;
    try {
      metadata = await ImageMetadataService().getMetadataFromBytes(bytes);
      if (metadata != null) {
        final fixedTags = ref.read(fixedTagsNotifierProvider);
        metadata = matchMetadataFixedTags(
          metadata: metadata,
          positiveEntries: fixedTags.positiveEntries,
          negativeEntries: fixedTags.negativeEntries,
        );
      }
    } catch (error) {
      AppLogger.w(
        'Could not read image metadata for Discord sharing: $error',
        'ImageSendAction',
      );
    }
    if (!context.mounted) return;
    final dimensions = NaiResolutionAdapter.readImageSize(bytes);
    await DiscordShareDialog.show(
      context,
      imageBytes: bytes,
      fileName: fileName,
      metadata: metadata,
      width: dimensions?.$1,
      height: dimensions?.$2,
    );
  }

  static String _baseName(String fileName) {
    final normalized = fileName.split(RegExp(r'[/\\]')).last;
    final dot = normalized.lastIndexOf('.');
    return dot > 0 ? normalized.substring(0, dot) : normalized;
  }
}
