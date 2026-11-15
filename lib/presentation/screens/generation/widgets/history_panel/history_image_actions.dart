import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/enums/precise_ref_type.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../core/utils/vibe_file_parser.dart';
import '../../../../../data/services/image_metadata_service.dart';
import '../../../../providers/alias_resolver_service.dart';
import '../../../../providers/image_generation_provider.dart';
import '../../../../providers/reverse_prompt_provider.dart';
import '../../../../providers/tag_library_page_provider.dart';
import '../../../../services/image_workflow_launcher.dart';
import '../../../../widgets/common/app_toast.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../../tag_library_page/widgets/entry_add_dialog.dart';

String historyImageFileName(GeneratedImage image) {
  final filePath = image.filePath;
  if (filePath != null && filePath.isNotEmpty) {
    return p.basename(filePath);
  }
  return 'history_${image.id}.png';
}

Future<void> sendHistoryImageToReversePrompt(
  BuildContext context,
  WidgetRef ref,
  GeneratedImage image,
) async {
  final l10n = context.l10n;

  try {
    await ref
        .read(reversePromptProvider.notifier)
        .addImage(image.bytes, name: historyImageFileName(image));

    if (!context.mounted) return;
    AppToast.success(context, l10n.drop_addedToReversePrompt);
  } catch (e) {
    if (context.mounted) {
      AppToast.error(context, l10n.gallery_sendFailed(e.toString()));
    }
  }
}

void sendHistoryImageToImageToImage(
  BuildContext context,
  WidgetRef ref,
  GeneratedImage image,
) {
  ImageWorkflowLauncher.openImageToImage(ref, image.bytes);
  AppToast.success(context, context.l10n.drop_addedToImg2Img);
}

Future<void> sendHistoryImageToVibeTransfer(
  BuildContext context,
  WidgetRef ref,
  GeneratedImage image,
) async {
  final l10n = context.l10n;

  try {
    final currentState = ref.read(generationParamsNotifierProvider);
    final currentCount = currentState.vibeReferencesV4.length;
    const maxCount = 16;
    final vibes = await VibeFileParser.parseFile(
      historyImageFileName(image),
      image.bytes,
    );

    if (!context.mounted) return;
    if (currentCount + vibes.length > maxCount) {
      AppToast.warning(context, l10n.toast_styleReferenceLimit(maxCount));
      return;
    }

    ref
        .read(generationParamsNotifierProvider.notifier)
        .addVibeReferences(vibes);

    final message = currentCount > 0
        ? l10n.toast_appendedStyleReferences(vibes.length)
        : vibes.length == 1
        ? l10n.drop_addedToVibe
        : l10n.drop_addedMultipleToVibe(vibes.length);
    AppToast.success(context, message);
  } catch (e) {
    if (context.mounted) {
      AppToast.error(context, '${l10n.vibeParseFailed}: $e');
    }
  }
}

Future<void> sendHistoryImageToPreciseReference(
  BuildContext context,
  WidgetRef ref,
  GeneratedImage image,
) async {
  final l10n = context.l10n;

  try {
    await ref
        .read(generationParamsNotifierProvider.notifier)
        .addPreciseReferenceFromImage(
          image.bytes,
          type: PreciseRefType.character,
          strength: 1.0,
          fidelity: 1.0,
        );

    if (!context.mounted) return;
    AppToast.success(context, l10n.drop_addedToCharacterRef);
  } catch (e) {
    if (context.mounted) {
      AppToast.error(context, l10n.gallery_sendFailed(e.toString()));
    }
  }
}

/// 显示保存到词库对话框
Future<void> showSaveHistoryImageToLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  // 历史记录中的图像需要尝试从元数据解析提示词
  var prompt = '';

  try {
    final extractedMeta = await ImageMetadataService().getMetadataFromBytes(
      bytes,
    );
    if (extractedMeta != null && extractedMeta.prompt.isNotEmpty) {
      prompt = extractedMeta.prompt;
    }
  } catch (e) {
    debugPrint('解析图像元数据失败: $e');
  }

  // 解析别名引用，保存实际内容到词库
  final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
  final resolvedPrompt = aliasResolver.resolveAliases(prompt);

  final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);

  if (!context.mounted) return;

  await EntryAddDialog.show(
    context,
    categories: tagLibraryState.categories,
    initialContent: resolvedPrompt,
    initialImageBytes: bytes,
  );
}

void showClearHistoryConfirmDialog(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onCleared,
}) {
  unawaited(() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.generation_clearHistory,
      content: context.l10n.generation_clearHistoryConfirm,
      confirmText: context.l10n.common_clear,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed) {
      ref.read(imageGenerationNotifierProvider.notifier).clearHistory();
      onCleared();
    }
  }());
}
