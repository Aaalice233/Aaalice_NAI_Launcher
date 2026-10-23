import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/storage/secure_storage_unavailable_exception.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../widgets/common/app_toast.dart';

/// 设置页读取 MCP 令牌；安全存储暂不可用时提示并返回 null
Future<String?> readMcpTokenOrNotify(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(mcpServerNotifierProvider.notifier);
  return _notifyWhenStorageUnavailable(context, notifier.readToken);
}

/// 换发 MCP 令牌，返回是否已写入；安全存储暂不可用时提示并保留旧令牌
Future<bool> regenerateMcpTokenOrNotify(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(mcpServerNotifierProvider.notifier);
  final regenerated = await _notifyWhenStorageUnavailable(context, () async {
    await notifier.regenerateToken();
    return true;
  });
  return regenerated ?? false;
}

Future<T?> _notifyWhenStorageUnavailable<T extends Object>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final message = context.l10n.common_secureStorageUnavailable;
  try {
    return await action();
  } on SecureStorageUnavailableException {
    AppToast.errorOnOverlay(overlay, message);
    return null;
  }
}
