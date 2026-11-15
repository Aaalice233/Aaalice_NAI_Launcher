import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/services/auth_error_service.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../../data/services/account_manager_provider.dart';
import '../../../data/services/auth_provider.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/content_sized_adaptive_form.dart';
import '../../providers/auth_mode_provider.dart';
import '../../router/app_routes.dart';
import '../../themes/theme_extension.dart';
import '../auth/account_avatar.dart';
import '../auth/login_form_container.dart';
import '../auth/saved_account_token_reader.dart';
import '../common/app_toast.dart';
import '../common/menu_action_label.dart';
import '../settings/account_profile_sheet.dart';
import 'nav_rail_expansion.dart';
import 'nav_rail_metrics.dart';

/// 账户头像按钮组件
class NavRailAccountButton extends StatefulWidget {
  final WidgetRef ref;

  const NavRailAccountButton({super.key, required this.ref});

  @override
  State<NavRailAccountButton> createState() => _NavRailAccountButtonState();
}

class _NavRailAccountButtonState extends State<NavRailAccountButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pressDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.fastDuration,
      minMilliseconds: 100,
      maxMilliseconds: 140,
    );
    final hoverDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.normalDuration,
      minMilliseconds: 120,
      maxMilliseconds: 180,
    );
    final authState = widget.ref.watch(authNotifierProvider);
    final accounts = widget.ref.watch(accountManagerNotifierProvider).accounts;

    // 获取当前账户
    SavedAccount? currentAccount;
    if (authState.isAuthenticated && authState.accountId != null) {
      try {
        currentAccount = accounts.firstWhere(
          (a) => a.id == authState.accountId,
        );
      } catch (_) {
        currentAccount = null;
      }
    }
    if (currentAccount == null &&
        (authState.status == AuthStatus.loading || authState.hasError)) {
      final sortedAccounts = widget.ref
          .read(accountManagerNotifierProvider.notifier)
          .sortedAccounts;
      if (sortedAccounts.isNotEmpty) {
        currentAccount = sortedAccounts.first;
      }
    }

    final avatar = currentAccount != null
        ? AccountAvatarSmall(account: currentAccount, size: 40)
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 12),
      constraints: BoxConstraints(minHeight: navRailItemMinHeight(context)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('main-nav-account-menu-button'),
          onTap: () => _showAccountMenu(context, currentAccount),
          onHover: (val) => setState(() => _isHovering = val),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: pressDuration,
            curve: theme.appTheme.standardCurve,
            child: AnimatedContainer(
              duration: hoverDuration,
              decoration: BoxDecoration(
                color: _isHovering
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message:
                        currentAccount?.displayName ?? context.l10n.auth_login,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(child: avatar),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExpandedRailContent(
                      child: Text(
                        currentAccount?.displayName ?? context.l10n.auth_login,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ExpandedRailContent(
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示账户菜单
  Future<void> _showAccountMenu(
    BuildContext context,
    SavedAccount? currentAccount,
  ) async {
    final theme = Theme.of(context);
    final authState = widget.ref.read(authNotifierProvider);
    final accounts = authState.isAuthenticated
        ? widget.ref.read(accountManagerNotifierProvider).accounts
        : const <SavedAccount>[];
    final menuCurrentAccount = authState.isAuthenticated
        ? currentAccount
        : null;

    Widget accountAction(
      IconData icon,
      String label, {
      bool destructive = false,
    }) => MenuActionLabel(
      leading: Icon(icon),
      label: label,
      destructive: destructive,
      iconColor: theme.colorScheme.onSurface,
      iconSize: 20,
      gap: 12,
    );

    // 获取按钮的位置用于定位菜单
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 使用 Rect 定义菜单弹出的锚点位置
    final railWidth = NavRailExpansionScope.isExpandedOf(context)
        ? navRailExpandedWidthFor(context)
        : navRailCollapsedWidth;
    final menuAnchor = Rect.fromLTWH(
      railWidth + 8,
      offset.dy,
      1,
      button.size.height,
    );

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(menuAnchor, Offset.zero & screenSize),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'login',
            child: accountAction(Icons.login, context.l10n.auth_login),
          ),

        // 当前账号标题
        if (menuCurrentAccount != null)
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Text(
              '${context.l10n.auth_currentAccount}: ${menuCurrentAccount.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),

        // 分割线
        if (menuCurrentAccount != null && accounts.length > 1)
          const PopupMenuDivider(),

        // 账号列表
        ...accounts.map(
          (account) => PopupMenuItem<String>(
            value: 'switch_${account.id}',
            child: Row(
              children: [
                AccountAvatarSmall(account: account, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (account.id == authState.accountId)
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),

        if (authState.isAuthenticated) const PopupMenuDivider(),

        // 添加账号
        if (authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'add',
            child: accountAction(Icons.add, context.l10n.auth_addAccount),
          ),

        if (menuCurrentAccount != null)
          PopupMenuItem<String>(
            key: const Key('main-nav-manage-accounts'),
            value: 'manage',
            child: accountAction(
              Icons.manage_accounts_outlined,
              context.l10n.auth_manageAccounts,
            ),
          ),

        // 退出登录
        if (authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'logout',
            child: accountAction(
              Icons.logout,
              context.l10n.auth_logout,
              destructive: true,
            ),
          ),
      ],
    );

    if (value == null || !mounted) return;

    if (value == 'login') {
      // ignore: use_build_context_synchronously
      context.push(AppRoutes.login);
    } else if (value == 'add') {
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showAddAccountDialog(context);
      }
    } else if (value == 'manage' &&
        menuCurrentAccount != null &&
        context.mounted) {
      AccountProfileBottomSheet.show(
        context: context,
        account: menuCurrentAccount,
      );
    } else if (value == 'logout') {
      // Use SchedulerBinding.endOfFrame to ensure logout happens AFTER the menu is fully disposed
      // This prevents the "ref.listen can only be used within build method" error that occurs when
      // The router auth listener can run during menu disposal. endOfFrame is more reliable
      // than addPostFrameCallback because it waits for the entire frame to complete, including all
      // post-frame callbacks and microtasks, ensuring the widget tree is stable.
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          widget.ref.read(authNotifierProvider.notifier).logout();
        }
      });
    } else if (value.startsWith('switch_')) {
      final accountId = value.substring(7);
      _switchAccount(accountId);
    }
  }

  /// 切换账号
  Future<void> _switchAccount(String accountId) async {
    final accounts = widget.ref.read(accountManagerNotifierProvider).accounts;
    final account = accounts.firstWhere((a) => a.id == accountId);

    final token = await readSavedAccountTokenForSwitch(
      context: context,
      ref: widget.ref,
      account: account,
    );
    if (token == null) return;

    // 使用 switchAccount（根据账号类型选择验证方式）
    final success = await widget.ref
        .read(authNotifierProvider.notifier)
        .switchAccount(
          account.id,
          token,
          displayName: account.displayName,
          accountType: account.accountType,
        );

    if (success) {
      // 更新最后使用时间
      widget.ref
          .read(accountManagerNotifierProvider.notifier)
          .updateLastUsed(account.id);
    } else {
      // 切换失败，显示错误提示并停留在当前账号
      if (mounted) {
        final authState = widget.ref.read(authNotifierProvider);
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
          case AuthErrorCode.credentialsLoginUnavailable:
            errorMessage = context.l10n.auth_error_credentialsLoginUnavailable;
            break;
          case AuthErrorCode.endpointIncompatible:
            errorMessage = context.l10n.auth_error_endpointIncompatible;
            break;
          case AuthErrorCode.serverError:
            errorMessage = context.l10n.auth_error_serverError;
            break;
          case AuthErrorCode.secureStorageUnavailable:
            errorMessage = context.l10n.common_secureStorageUnavailable;
            break;
          default:
            errorMessage = context.l10n.auth_loginFailed;
        }

        AppToast.error(context, errorMessage);
      }
    }
  }

  /// 显示添加账号对话框
  void _showAddAccountDialog(BuildContext context) {
    // 重置 AuthMode 为当前默认登录模式
    widget.ref.read(authModeNotifierProvider.notifier).reset();
    // 立即清除之前的登录错误状态（无延迟）
    widget.ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);

    AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.auth_addAccount,
      dialogWidth: 450,
      headerScrollsWithContent: true,
      builder: (panelContext, scrollController) => ContentSizedAdaptiveForm(
        scrollViewKey: const Key('main-nav-add-account-form'),
        scrollController: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 32),
        content: [
          LoginFormContainer(onLoginSuccess: () => Navigator.pop(panelContext)),
        ],
      ),
    );
  }
}
