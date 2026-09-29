import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/constants/community_links.dart';
import '../../core/utils/localization_extension.dart';
import '../../data/models/auth/saved_account.dart';
import '../adaptive/adaptive_presenter.dart';
import '../adaptive/content_sized_adaptive_form.dart';
import '../agent_chat/providers/agent_chat_notifier.dart';
import '../providers/account_manager_provider.dart';
import '../providers/auth_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/update_provider.dart';
import '../services/mobile_image_metadata_importer.dart';
import '../widgets/auth/login_form_container.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/navigation/main_nav_rail.dart';
import '../widgets/settings/account_profile_sheet.dart';
import 'app_branch.dart';
import 'app_routes.dart';
import 'shell_panels_overlay.dart';

typedef MobileMetadataImportAction =
    Future<void> Function(BuildContext context, WidgetRef ref);

Future<void> showMobileMorePanel({
  required BuildContext context,
  required WidgetRef ref,
  required StatefulNavigationShell navigationShell,
  MobileMetadataImportAction? onImportImageMetadata,
}) {
  final importImageMetadata =
      onImportImageMetadata ??
      // 偏离上游：上游直接开 FilePicker，iOS 上那是「文件」App，选不了相册，
      // 而 iOS 上生成的图存在相册里。iOS 改走来源面板（相册 / 文件 / 剪贴板），
      // 落地仍是上游的去向对话框；其它平台原样保留上游。
      (PlatformCapabilities.current.isIOS
          ? (context, ref) => showMobileImageMetadataImportSheet(
              context: context,
              ref: ref,
              askDestination: true,
            )
          : (context, ref) => MobileImageMetadataImporter.shared.run(
              context: context,
              ref: ref,
            ));
  final queueCount = ref.read(replicationQueueNotifierProvider).count;
  final hasUpdate = ref.read(updateStateProvider).hasNewVersion;
  final activePanel = ref.read(shellPanelProvider);
  final authState = ref.read(authNotifierProvider);
  final accounts = ref.read(accountManagerNotifierProvider).accounts;
  SavedAccount? currentAccount;
  if (authState.isAuthenticated && authState.accountId != null) {
    for (final account in accounts) {
      if (account.id == authState.accountId) {
        currentAccount = account;
        break;
      }
    }
  }
  final accountForMenu = currentAccount;
  final agentRunning =
      ref.read(agentChatNotifierProvider).status == AgentChatRunStatus.running;

  return AdaptivePresenter.showPanel<void>(
    context: context,
    initialChildSize: 0.80,
    minChildSize: 0.52,
    titleBuilder: (context) => Text(
      context.l10n.nav_more,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    builder: (panelContext, scrollController) {
      final largeText = MediaQuery.textScalerOf(panelContext).scale(14) > 18.2;
      return Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                children: [
                  _MobileMoreDestination(
                    key: const ValueKey('mobile-more-account'),
                    icon: accountForMenu == null
                        ? Icons.login_rounded
                        : Icons.account_circle_outlined,
                    label:
                        accountForMenu?.displayName ??
                        panelContext.l10n.auth_login,
                    onTap: () async {
                      final panelRoute = ModalRoute.of(panelContext);
                      Navigator.of(panelContext).pop();
                      if (panelRoute != null) await panelRoute.completed;
                      if (!context.mounted) return;
                      if (accountForMenu case final account?) {
                        await AccountProfileBottomSheet.show(
                          context: context,
                          account: account,
                        );
                      } else {
                        context.push(AppRoutes.login);
                      }
                    },
                  ),
                  // 偏离上游：上游移动端登录后没有任何添加第二账号的路径——
                  // AccountDetailTile 只在未登录时渲染登录按钮，
                  // AccountProfileBottomSheet 只有「切换账号 / 退出登录」，
                  // 而 auth_addAccount 的唯一入口在桌面侧栏 MainNavRail 的弹出菜单里。
                  // 这里补一条，复用桌面同一套表单（push /login 行不通：
                  // app_routes 的 redirect 会把已登录用户从 /login 打回首页）。
                  if (accountForMenu != null)
                    _MobileMoreDestination(
                      key: const ValueKey('mobile-more-add-account'),
                      icon: Icons.person_add_alt_1_outlined,
                      label: panelContext.l10n.auth_addAccount,
                      onTap: () async {
                        final panelRoute = ModalRoute.of(panelContext);
                        Navigator.of(panelContext).pop();
                        if (panelRoute != null) await panelRoute.completed;
                        if (!context.mounted) return;
                        await _showAddAccountForm(context, ref);
                      },
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  _MobileMoreDestination(
                    key: const ValueKey('mobile-more-agent'),
                    icon: Icons.smart_toy_outlined,
                    label: panelContext.l10n.nav_agent,
                    selected: activePanel == ShellPanel.agent,
                    showBadge: agentRunning,
                    onTap: () {
                      Navigator.of(panelContext).pop();
                      ref.read(shellPanelProvider.notifier).state =
                          ShellPanel.agent;
                    },
                  ),
                  _MobileMoreDestination(
                    key: const ValueKey('mobile-more-queue'),
                    icon: Icons.playlist_play_rounded,
                    label: panelContext.l10n.queue_management,
                    selected: activePanel == ShellPanel.queue,
                    badgeCount: queueCount,
                    onTap: () {
                      Navigator.of(panelContext).pop();
                      ref.read(shellPanelProvider.notifier).state =
                          ShellPanel.queue;
                    },
                  ),
                  _MobileMoreDestination(
                    key: const ValueKey('mobile-more-read-image-metadata'),
                    icon: Icons.document_scanner_outlined,
                    label: panelContext.l10n.metadataImport_readImageMetadata,
                    onTap: () async {
                      final panelRoute = ModalRoute.of(panelContext);
                      Navigator.of(panelContext).pop();
                      if (panelRoute != null) {
                        await panelRoute.completed;
                      }
                      if (context.mounted) {
                        await importImageMetadata(context, ref);
                      }
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _MobileMoreDestination(
                    icon: Icons.style_outlined,
                    label: panelContext.l10n.vibeLibrary_title,
                    onTap: () => _selectBranch(
                      panelContext,
                      navigationShell,
                      AppBranch.vibeLibrary,
                    ),
                  ),
                  _MobileMoreDestination(
                    icon: Icons.center_focus_strong_outlined,
                    label: panelContext.l10n.nav_preciseRefLibrary,
                    onTap: () => _selectBranch(
                      panelContext,
                      navigationShell,
                      AppBranch.preciseRefLibrary,
                    ),
                  ),
                  _MobileMoreDestination(
                    icon: Icons.casino_outlined,
                    label: panelContext.l10n.nav_randomConfig,
                    onTap: () => _selectBranch(
                      panelContext,
                      navigationShell,
                      AppBranch.promptConfig,
                    ),
                  ),
                  _MobileMoreDestination(
                    icon: Icons.insights_outlined,
                    label: panelContext.l10n.nav_statistics,
                    onTap: () => _selectBranch(
                      panelContext,
                      navigationShell,
                      AppBranch.statistics,
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _MobileMoreDestination(
                    key: const ValueKey('mobile-more-settings'),
                    icon: Icons.settings_outlined,
                    label: panelContext.l10n.settings_title,
                    showBadge: hasUpdate,
                    onTap: () => _selectBranch(
                      panelContext,
                      navigationShell,
                      AppBranch.settings,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MobileCommunityButton(
                        key: const ValueKey('mobile-more-discord'),
                        icon: const Icon(Icons.discord, size: 20),
                        label: panelContext.l10n.nav_joinDiscord,
                        backgroundColor: const Color(0xFF5865F2),
                        onPressed: () => _openCommunityLink(
                          panelContext,
                          CommunityLinks.discord,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MobileCommunityButton(
                        key: const ValueKey('mobile-more-github'),
                        icon: const GitHubLogo(color: Colors.white, size: 20),
                        label: panelContext.l10n.nav_projectRepository,
                        backgroundColor: const Color(0xFF2D333B),
                        onPressed: () => _openCommunityLink(
                          panelContext,
                          CommunityLinks.github,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _MobileCommunityButton(
                          key: const ValueKey('mobile-more-discord'),
                          icon: const Icon(Icons.discord, size: 20),
                          label: panelContext.l10n.nav_joinDiscord,
                          backgroundColor: const Color(0xFF5865F2),
                          onPressed: () => _openCommunityLink(
                            panelContext,
                            CommunityLinks.discord,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MobileCommunityButton(
                          key: const ValueKey('mobile-more-github'),
                          icon: const GitHubLogo(color: Colors.white, size: 20),
                          label: panelContext.l10n.nav_projectRepository,
                          backgroundColor: const Color(0xFF2D333B),
                          onPressed: () => _openCommunityLink(
                            panelContext,
                            CommunityLinks.github,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

Future<void> _openCommunityLink(BuildContext panelContext, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && panelContext.mounted) {
    AppToast.error(panelContext, panelContext.l10n.cannotOpenUrl);
  }
}

/// 移动端「添加账号」表单，与桌面侧栏 MainNavRail 的添加账号走同一套内容。
Future<void> _showAddAccountForm(BuildContext context, WidgetRef ref) async {
  // 与桌面一致：先把登录模式复位并立刻清掉上一次的错误，避免表单带着旧报错打开。
  ref.read(authModeNotifierProvider.notifier).reset();
  ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);

  await AdaptivePresenter.showForm<void>(
    context: context,
    title: context.l10n.auth_addAccount,
    dialogWidth: 450,
    builder: (formContext, scrollController) => ContentSizedAdaptiveForm(
      scrollViewKey: const Key('mobile-more-add-account-form'),
      scrollController: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 32),
      content: [
        LoginFormContainer(onLoginSuccess: () => Navigator.pop(formContext)),
      ],
    ),
  );
}

void _selectBranch(
  BuildContext panelContext,
  StatefulNavigationShell navigationShell,
  AppBranch branch,
) {
  Navigator.of(panelContext).pop();
  navigationShell.goBranch(branch.index);
}

class _MobileCommunityButton extends StatelessWidget {
  const _MobileCommunityButton({
    super.key,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: icon,
      label: Text(
        label,
        maxLines: largeText ? null : 1,
        overflow: largeText ? TextOverflow.visible : TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MobileMoreDestination extends StatelessWidget {
  const _MobileMoreDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.showBadge = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool showBadge;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasCount = badgeCount > 0;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
    return ListTile(
      minTileHeight: 56,
      leading: Badge(
        isLabelVisible: hasCount || showBadge,
        label: hasCount
            ? Text(badgeCount > 99 ? '99+' : badgeCount.toString())
            : null,
        smallSize: 7,
        child: Icon(icon),
      ),
      title: Text(
        label,
        maxLines: largeText ? null : 1,
        overflow: largeText ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded)
          : const Icon(Icons.chevron_right),
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
