import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/account_manager_provider.dart';
import '../../../router/app_routes.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/settings/account_detail_tile.dart';
import '../../../widgets/settings/account_profile_sheet.dart';
import '../widgets/settings_card.dart';

/// 账户设置板块
///
/// 显示当前账户信息，支持编辑账户资料和登录功能。
class AccountSettingsSection extends ConsumerStatefulWidget {
  const AccountSettingsSection({super.key});

  @override
  ConsumerState<AccountSettingsSection> createState() =>
      _AccountSettingsSectionState();
}

class _AccountSettingsSectionState
    extends ConsumerState<AccountSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final accountTile = AccountDetailTile(
      onEdit: () => _showProfileSheet(context),
      onLogin: () => _navigateToLogin(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return accountTile;
        }
        return SettingsCard(
          title: context.l10n.settings_account,
          icon: Icons.person,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: accountTile,
          ),
        );
      },
    );
  }

  /// 显示账号资料编辑底部面板
  void _showProfileSheet(BuildContext context) {
    final authState = ref.read(authNotifierProvider);
    final accountId = authState.accountId;

    if (accountId == null) {
      AppToast.info(context, context.l10n.settings_pleaseLoginFirst);
      return;
    }

    final accounts = ref.read(accountManagerNotifierProvider).accounts;
    final account = accounts.where((a) => a.id == accountId).firstOrNull;

    if (account == null) {
      AppToast.info(context, context.l10n.settings_accountNotFound);
      return;
    }

    AccountProfileBottomSheet.show(context: context, account: account);
  }

  /// 导航到登录页面
  void _navigateToLogin(BuildContext context) {
    context.push(AppRoutes.login);
  }
}
