import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../../widgets/common/app_toast.dart';
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
        context.l10n.auth_savedAccounts,
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

                    if (token == null) {
                      if (context.mounted) {
                        AppToast.error(
                            context, context.l10n.auth_tokenNotFound,);
                      }
                      return;
                    }

                    final success = await ref
                        .read(authNotifierProvider.notifier)
                        .switchAccount(
                          account.id,
                          token,
                          displayName: account.displayName,
                          accountType: account.accountType,
                        );

                    if (!success && context.mounted) {
                      final authState = ref.read(authNotifierProvider);
                      String errorMessage;

                      switch (authState.errorCode) {
                        case AuthErrorCode.networkTimeout:
                          errorMessage = context.l10n.auth_error_networkTimeout;
                          break;
                        case AuthErrorCode.networkError:
                          errorMessage = context.l10n.auth_error_networkError;
                          break;
                        case AuthErrorCode.authFailed:
                        case AuthErrorCode.tokenInvalid:
                          errorMessage = context.l10n.auth_error_authFailed;
                          break;
                        case AuthErrorCode.serverError:
                          errorMessage = context.l10n.auth_error_serverError;
                          break;
                        default:
                          errorMessage = context.l10n.auth_loginFailed;
                      }

                      AppToast.error(context, errorMessage);
                    }
                  },
                  onDelete: () async {
                    // 删除账号
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.auth_deleteAccount),
                        content: Text(context.l10n
                            .auth_deleteAccountConfirm(account.displayName),),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.l10n.common_cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            child: Text(context.l10n.common_delete),
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
          account.accountType == AccountType.credentials
              ? context.l10n.auth_credentialsLogin
              : context.l10n.auth_tokenLogin,
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
                    tooltip: context.l10n.auth_switchAccount,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.error.withOpacity(0.7),
                    ),
                    onPressed: onDelete,
                    tooltip: context.l10n.auth_deleteAccount,
                  ),
                ],
              ),
        onTap: isCurrent ? null : onTap,
      ),
    );
  }
}
