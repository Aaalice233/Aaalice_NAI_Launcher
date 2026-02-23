import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';

import '../common/app_toast.dart';

/// 账号头像下拉菜单组件（Google 风格）
class AccountAvatarDropdown extends ConsumerWidget {
  /// 选择账号时的回调
  final void Function(SavedAccount account, String? token)? onAccountSelected;

  /// 点击添加账号时的回调
  final VoidCallback? onAddAccount;

  /// 点击管理账号时的回调
  final VoidCallback? onManageAccounts;

  const AccountAvatarDropdown({
    super.key,
    this.onAccountSelected,
    this.onAddAccount,
    this.onManageAccounts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听账号状态变化以触发重建
    ref.watch(accountManagerNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final accounts =
        ref.read(accountManagerNotifierProvider.notifier).sortedAccounts;

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final currentAccount = authState.accountId != null
        ? accounts.where((a) => a.id == authState.accountId).firstOrNull
        : accounts.firstOrNull;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.auth_savedAccounts,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onManageAccounts != null)
                  TextButton(
                    onPressed: onManageAccounts,
                    child: Text(context.l10n.auth_manageAccounts),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 账号列表
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < accounts.length && i < 5; i++)
                    _AccountListTile(
                      account: accounts[i],
                      isFirst: i == 0,
                      isLast: i == accounts.length - 1 || i == 4,
                      isSelected: currentAccount?.id == accounts[i].id &&
                          authState.isAuthenticated,
                      isDefault: i == 0, // 第一个为最近使用的账号
                      onTap: () => _onAccountTap(context, ref, accounts[i]),
                    ),
                  if (accounts.length > 5)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.more_horiz),
                      title: Text(
                        context.l10n.auth_moreAccounts(accounts.length - 5),
                      ),
                      onTap: onManageAccounts,
                    ),
                ],
              ),
            ),

            // 添加账号按钮
            if (onAddAccount != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAddAccount,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.auth_addAccount),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onAccountTap(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) async {
    // 获取 Token
    final token = await ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountToken(account.id);

    if (token == null) {
      if (context.mounted) {
        AppToast.info(context, context.l10n.auth_tokenNotFound);
      }
      return;
    }

    // 更新最后使用时间
    await ref
        .read(accountManagerNotifierProvider.notifier)
        .updateLastUsed(account.id);

    // 回调
    onAccountSelected?.call(account, token);
  }
}

/// 账号列表项
class _AccountListTile extends StatelessWidget {
  final SavedAccount account;
  final bool isFirst;
  final bool isLast;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback? onTap;

  const _AccountListTile({
    required this.account,
    required this.isFirst,
    required this.isLast,
    this.isSelected = false,
    this.isDefault = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.15),
                  ),
                ),
        ),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 18,
              backgroundColor: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              child: Text(
                account.displayName[0].toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.common_default,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isSelected)
                    Text(
                      context.l10n.auth_loggedIn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            // 选中图标
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              )
            else
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }
}
