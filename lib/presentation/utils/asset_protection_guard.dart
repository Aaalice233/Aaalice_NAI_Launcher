import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_export_service.dart';
import '../providers/cost_estimate_provider.dart';
import '../providers/share_image_settings_provider.dart';
import '../widgets/common/themed_confirm_dialog.dart';
import '../../core/utils/localization_extension.dart';

class AssetProtectionGuard {
  const AssetProtectionGuard._();

  static ShareImageSettings settings(WidgetRef ref) =>
      ref.read(shareImageSettingsProvider);

  static bool isEnabled(WidgetRef ref) =>
      ref.read(shareImageSettingsProvider).protectionMode;

  static bool shouldPreventOverwrite(WidgetRef ref) =>
      ref.read(shareImageSettingsProvider).effectivePreventOverwrite;

  static Future<bool> confirmDangerousAction({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String content,
    String? confirmText,
    IconData icon = Icons.shield_outlined,
  }) async {
    if (!ref
        .read(shareImageSettingsProvider)
        .effectiveConfirmDangerousActions) {
      return true;
    }
    return ThemedConfirmDialog.show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText ?? context.l10n.common_continue,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: icon,
    );
  }

  static Future<bool> confirmExternalImageSend({
    required BuildContext context,
    required WidgetRef ref,
    required String targetName,
    int imageCount = 1,
  }) {
    if (!ref.read(shareImageSettingsProvider).effectiveWarnExternalImageSend) {
      return Future.value(true);
    }
    final l10n = context.l10n;
    return ThemedConfirmDialog.show(
      context: context,
      title: l10n.settings_confirmExternalSendTitle,
      content: l10n.settings_confirmExternalSendContent(
        imageCount,
        targetName,
      ),
      confirmText: l10n.settings_confirmExternalSend,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.cloud_upload_outlined,
    );
  }

  static Future<bool> confirmHighAnlasCost({
    required BuildContext context,
    required WidgetRef ref,
    int? cost,
  }) {
    final settings = ref.read(shareImageSettingsProvider);
    if (!settings.effectiveWarnHighAnlasCost) {
      return Future.value(true);
    }

    final estimatedCost = cost ?? ref.read(estimatedCostProvider) ?? 0;
    if (estimatedCost < settings.highAnlasCostThreshold) {
      return Future.value(true);
    }

    final l10n = context.l10n;
    return ThemedConfirmDialog.show(
      context: context,
      title: l10n.settings_highAnlasCostTitle,
      content: l10n.settings_highAnlasCostContent(
        estimatedCost,
        settings.highAnlasCostThreshold,
      ),
      confirmText: l10n.settings_continueGeneration,
      cancelText: l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.toll_outlined,
    );
  }

  static Future<String> resolveNonOverwritingPath(String requestedPath) =>
      FileExportService.resolveNonOverwritingPath(requestedPath);
}
