import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../../../data/models/auth/saved_account.dart';

/// 账号快速切换组件
class AccountQuickSwitch extends ConsumerWidget {
  const AccountQuickSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountManagerNotifierProvider);
    final accounts = accountState.accounts;
    final currentAccountId = ref.watch(authNotifierProvider).accountId;

    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: Text(
        '已保存账号 (${accounts.length})',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...accounts.map(
                (account) => _buildAccountTile(
                  context: context,
                  account: account,
                  isCurrent: account.id == currentAccountId,
                  onTap: () async {
                    // 切换到该账号
                    final token = await ref
                        .read(accountManagerNotifierProvider.notifier)
                        .getAccountToken(account.id);
                    if (token != null) {
                      await ref.read(authNotifierProvider.notifier).switchAccount(
                            account.id,
                            token,
                            displayName: account.displayName,
                            accountType: account.accountType,
                          );
                    }
                  },
                  onDelete: () async {
                    // 删除账号
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除账号'),
                        content: Text('确定要删除账号 "${account.displayName}" 吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref
                          .read(accountManagerNotifierProvider.notifier)
                          .removeAccount(account.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTile({
    required BuildContext context,
    required SavedAccount account,
    required bool isCurrent,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            account.displayName[0].toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          account.displayName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          account.accountType == AccountType.credentials ? '邮箱登录' : 'Token登录',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isCurrent
            ? Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    onPressed: onTap,
                    tooltip: '切换到该账号',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.error.withOpacity(0.7),
                    ),
                    onPressed: onDelete,
                    tooltip: '删除账号',
                  ),
                ],
              ),
        onTap: isCurrent ? null : onTap,
      ),
    );
  }
}
