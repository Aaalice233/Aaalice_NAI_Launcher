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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // 使用渐变背景增加层次感
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 头像和信息行
                  Row(
                    children: [
                      // 头像（带装饰环）
                      _buildAvatarWithRing(context, account),
                      const SizedBox(width: 16),
                      // 名称和邮箱信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 昵称
                            Text(
                              account.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 邮箱
                            Text(
                              account.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // 编辑按钮
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: onEdit,
                          tooltip: context.l10n.common_edit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 分割线
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          theme.colorScheme.outlineVariant.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 账号类型标签
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              account.accountType == AccountType.credentials
                                  ? Icons.lock_outlined
                                  : Icons.key_outlined,
                              size: 14,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              account.accountType == AccountType.credentials
                                  ? context.l10n.auth_credentialsLogin
                                  : context.l10n.auth_tokenLogin,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 状态指示器
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.auth_loggedIn,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatarWithRing(BuildContext context, SavedAccount account) {
    return AccountAvatar(
      account: account,
      size: 64,
    );
  }

  /// 构建未登录状态的内容
  Widget _buildUnauthenticatedContent(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onLogin,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // 头像占位（带动画效果的虚线圆环）
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 36,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 提示文本
                  Text(
                    context.l10n.settings_notLoggedIn,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // 登录按钮
                  FilledButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(context.l10n.settings_goToLogin),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
