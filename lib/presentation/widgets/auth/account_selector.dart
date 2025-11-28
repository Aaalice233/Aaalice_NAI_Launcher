import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';

/// 账号选择器组件
class AccountSelector extends ConsumerWidget {
  /// 选择账号时的回调
  final void Function(SavedAccount account, String? password)? onAccountSelected;

  /// 点击管理账号时的回调
  final VoidCallback? onManageAccounts;

  const AccountSelector({
    super.key,
    this.onAccountSelected,
    this.onManageAccounts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountManagerNotifierProvider);
    final accounts = ref.read(accountManagerNotifierProvider.notifier).sortedAccounts;

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已保存的账号',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (onManageAccounts != null)
              TextButton(
                onPressed: onManageAccounts,
                child: const Text('管理'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 账号列表
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (int i = 0; i < accounts.length && i < 5; i++)
                _AccountTile(
                  account: accounts[i],
                  isFirst: i == 0,
                  isLast: i == accounts.length - 1 || i == 4,
                  onTap: () => _onAccountTap(context, ref, accounts[i]),
                ),
              if (accounts.length > 5)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.more_horiz),
                  title: Text('还有 ${accounts.length - 5} 个账号'),
                  onTap: onManageAccounts,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _onAccountTap(
    BuildContext context,
    WidgetRef ref,
    SavedAccount account,
  ) async {
    // 获取密码
    final password = await ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountPassword(account.id);

    // 更新最后使用时间
    await ref
        .read(accountManagerNotifierProvider.notifier)
        .updateLastUsed(account.id);

    // 回调
    onAccountSelected?.call(account, password);
  }
}

/// 账号项
class _AccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  const _AccountTile({
    required this.account,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(8) : Radius.zero,
        bottom: isLast ? const Radius.circular(8) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
        ),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                account.displayName[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
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
                      Text(
                        account.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (account.isDefault) ...[
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
                            '默认',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (account.nickname != null)
                    Text(
                      account.maskedEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            // 箭头
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
