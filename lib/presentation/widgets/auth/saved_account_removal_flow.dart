import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../../data/services/saved_account_removal_service.dart';
import '../common/app_toast.dart';
import '../common/themed_confirm_dialog.dart';

/// 确认后从启动器移除已保存账号，返回是否已移除。
///
/// [beforeRemove] 在确认后、执行移除前调用，供调用方关闭移除后会失效的面板。
Future<bool> confirmAndRemoveSavedAccount({
  required BuildContext context,
  required WidgetRef ref,
  required SavedAccount account,
  Future<void> Function()? beforeRemove,
}) async {
  // beforeRemove 可能卸载调用方，之后不能再碰 ref 与 context
  final service = ref.read(savedAccountRemovalServiceProvider);
  final l10n = context.l10n;
  final details = l10n.auth_removeSavedAccountConfirm(account.displayName);

  final confirmed = await ThemedConfirmDialog.show(
    context: context,
    title: l10n.auth_removeSavedAccount,
    content: service.isSessionAccount(account.id)
        ? '${l10n.auth_removeSessionAccountNotice}\n\n$details'
        : details,
    confirmText: l10n.auth_removeSavedAccountAction,
    type: ThemedConfirmDialogType.danger,
    icon: Icons.person_remove_outlined,
  );
  if (!confirmed || !context.mounted) return false;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final successMessage = l10n.auth_removeSavedAccountSuccess(
    account.displayName,
  );
  final failureMessage = l10n.auth_removeSavedAccountFailed;

  await beforeRemove?.call();
  try {
    await service.remove(account.id);
  } catch (error, stackTrace) {
    AppLogger.e('Failed to remove saved account', error, stackTrace, 'Auth');
    AppToast.errorOnOverlay(overlay, failureMessage);
    return false;
  }
  AppToast.successOnOverlay(overlay, successMessage);
  return true;
}
