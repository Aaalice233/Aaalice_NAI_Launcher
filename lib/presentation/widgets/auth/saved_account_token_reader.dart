import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_unavailable_exception.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../../data/services/account_manager_provider.dart';
import '../common/app_toast.dart';

/// 切换到已保存账号前读取其 Token；读不到时提示原因并返回 null。
///
/// 调用方可能在读取期间关闭所在面板，提示走根 Overlay 而不依赖调用方存活。
Future<String?> readSavedAccountTokenForSwitch({
  required BuildContext context,
  required WidgetRef ref,
  required SavedAccount account,
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final l10n = context.l10n;
  final accountManager = ref.read(accountManagerNotifierProvider.notifier);

  final String? token;
  try {
    token = await accountManager.getAccountToken(account.id);
  } on SecureStorageUnavailableException {
    AppToast.errorOnOverlay(overlay, l10n.common_secureStorageUnavailable);
    return null;
  }
  if (token == null || token.isEmpty) {
    AppToast.infoOnOverlay(overlay, l10n.auth_tokenNotFound);
    return null;
  }
  return token;
}
