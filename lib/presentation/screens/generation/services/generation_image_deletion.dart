import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/localization_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../utils/asset_protection_guard.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';

/// 只在本次运行内有效，不持久化，也不参与云同步。
final generationImageDeleteConfirmSkippedProvider = StateProvider<bool>(
  (ref) => false,
);

/// 删除生成结果的交互入口：确认、资产保护与结果提示；状态和文件变更由 notifier 完成。
class GenerationImageDeletion {
  const GenerationImageDeletion({required this.context, required this.ref});

  final BuildContext context;
  final WidgetRef ref;

  Future<void> confirmAndDelete(List<GeneratedImage> images) async {
    if (images.isEmpty) return;
    final l10n = context.l10n;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    final skipConfirmation = ref.read(
      generationImageDeleteConfirmSkippedProvider.notifier,
    );
    final requiresProtection = AssetProtectionGuard.settings(
      ref,
    ).effectiveConfirmDangerousActions;
    final state = ref.read(imageGenerationNotifierProvider);
    // 卡片持有的是构建时的快照，自动保存可能已在之后写入路径。
    final targets = [
      for (final image in images) state.findImageById(image.id) ?? image,
    ];
    final filePaths = <String>{
      for (final image in targets)
        if (image.filePath case final String path when path.isNotEmpty) path,
    }.toList();

    if (!skipConfirmation.state) {
      final outcome = await ThemedConfirmDialog.showWithOption(
        context: context,
        title: l10n.common_confirmDelete,
        content: _confirmationContent(l10n, targets.length, filePaths),
        optionLabel: l10n.generation_deleteConfirmSkipForSession,
        confirmText: l10n.common_delete,
        cancelText: l10n.common_cancel,
        type: ThemedConfirmDialogType.danger,
        icon: Icons.delete_outline,
      );
      if (!outcome.confirmed) return;
      if (outcome.optionChecked) skipConfirmation.state = true;
    }

    // 保护模式是持久的安全设置，不受本次运行的免确认影响。
    if (filePaths.isNotEmpty && requiresProtection) {
      if (!context.mounted) return;
      final confirmed = await AssetProtectionGuard.confirmDangerousAction(
        context: context,
        ref: ref,
        title: l10n.localGallery_protectedDeleteTitle,
        content: filePaths.length == 1
            ? l10n.localGallery_protectedDeleteImageContent(
                p.basename(filePaths.single),
              )
            : l10n.localGallery_protectedDeleteImagesContent(filePaths.length),
        confirmText: l10n.common_delete,
        icon: Icons.delete_forever_outlined,
      );
      if (!confirmed) return;
    }

    final result = await generation.removeImages(
      targets.map((image) => image.id),
    );
    _report(overlay, l10n, result);
  }

  static String _confirmationContent(
    AppLocalizations l10n,
    int count,
    List<String> filePaths,
  ) {
    if (count == 1) {
      return filePaths.isEmpty
          ? l10n.generation_deleteImageConfirm
          : l10n.generation_deleteImageWithFileConfirm(
              p.basename(filePaths.single),
            );
    }
    return filePaths.isEmpty
        ? l10n.generation_deleteImagesConfirm(count)
        : l10n.generation_deleteImagesWithFilesConfirm(
            count,
            filePaths.length,
          );
  }

  static void _report(
    OverlayState? overlay,
    AppLocalizations l10n,
    GeneratedImageRemovalResult result,
  ) {
    if (result.removedCount == 0) return;
    final failures = result.files.failures;
    if (failures.isNotEmpty) {
      AppToast.warningOnOverlay(
        overlay,
        l10n.generation_deleteImageFilesFailed(
          failures.length,
          failures.values.first,
        ),
      );
      return;
    }
    AppToast.successOnOverlay(
      overlay,
      result.removedCount == 1
          ? l10n.localGallery_imageDeleted
          : l10n.localGallery_deletedImages(result.removedCount),
    );
  }
}
