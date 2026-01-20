import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../auth/account_avatar.dart';

/// 账号信息设置项
///
/// 用于在设置页面显示账号信息，包括头像、昵称、邮箱等
/// 支持编辑功能（点击编辑按钮触发回调）
class AccountDetailTile extends ConsumerWidget {
  /// 编辑按钮点击回调
  final VoidCallback? onEdit;

  /// 登录按钮点击回调（未登录状态）
  final VoidCallback? onLogin;

  const AccountDetailTile({
    super.key,
    this.onEdit,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    if (authState.isAuthenticated && authState.accountId != null) {
      // 已登录状态
      return _buildAuthenticatedContent(context, ref, authState.accountId!);
    } else {
      // 未登录状态
      return _buildUnauthenticatedContent(context);
    }
  }

  /// 构建已登录状态的内容
  Widget _buildAuthenticatedContent(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) {
    final theme = Theme.of(context);
    // 使用 ref.watch 响应账号数据变化
    final accounts = ref.watch(accountManagerNotifierProvider).accounts;
    final account = accounts.where((a) => a.id == accountId).firstOrNull;

    if (account == null) {
      return _buildUnauthenticatedContent(context);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 头像行
            Row(
              children: [
                // 头像（点击可编辑）
                GestureDetector(
                  onTap: onEdit,
                  child: AccountAvatar(
                    account: account,
                    size: 64,
                  ),
                ),
                const SizedBox(width: 16),
                // 名称和邮箱信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 昵称或邮箱
                      Text(
                        account.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 邮箱/标识符
                      Text(
                        account.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 编辑按钮
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: onEdit,
                  tooltip: context.l10n.common_edit,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分割线
            Divider(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            // 账号类型
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.settings_accountType,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                Text(
                  account.accountType == AccountType.credentials
                      ? context.l10n.auth_credentialsLogin
                      : context.l10n.auth_tokenLogin,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建未登录状态的内容
  Widget _buildUnauthenticatedContent(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 头像占位
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 32,
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            // 提示文本
            Text(
              context.l10n.settings_notLoggedIn,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 登录按钮
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: Text(context.l10n.settings_goToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
