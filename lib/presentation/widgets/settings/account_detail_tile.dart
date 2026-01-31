import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/user/user_subscription.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/subscription_provider.dart';
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

  /// 构建已登录状态的内容 - 极简单行式
  Widget _buildAuthenticatedContent(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountManagerNotifierProvider).accounts;
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    final subscriptionState = ref.watch(subscriptionNotifierProvider);

    if (account == null) {
      return _buildUnauthenticatedContent(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // 使用主题颜色，无边框
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 头像
                AccountAvatar(account: account, size: 44),
                const SizedBox(width: 12),
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 名字 + 徽章
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 订阅徽章
                          _buildCompactBadges(context, subscriptionState),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 编辑箭头
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建紧凑徽章区域
  Widget _buildCompactBadges(
    BuildContext context,
    SubscriptionState subscriptionState,
  ) {
    final theme = Theme.of(context);

    return subscriptionState.when(
      initial: () => const SizedBox.shrink(),
      loading: () => SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.outline,
        ),
      ),
      loaded: (subscription) {
        final tierColor = _getTierColor(subscription.tier);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier 徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subscription.tierName,
                style: TextStyle(
                  color: tierColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Anlas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.diamond_outlined,
                    size: 12,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(subscription.anlasBalance),
                    style: TextStyle(
                      color: theme.colorScheme.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      error: (_) => Icon(
        Icons.error_outline,
        size: 16,
        color: theme.colorScheme.error,
      ),
    );
  }

  /// 格式化数字 (1000 -> 1K)
  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// 获取订阅等级对应的颜色
  Color _getTierColor(int tier) {
    switch (tier) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// 构建未登录状态 - 紧凑版
  Widget _buildUnauthenticatedContent(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onLogin,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 头像占位
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 24,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                // 提示文本
                Expanded(
                  child: Text(
                    context.l10n.settings_notLoggedIn,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                // 登录按钮
                FilledButton.tonal(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.settings_goToLogin,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
