import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/community_links.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/adaptive_presenter.dart';
import '../agent_chat/providers/agent_chat_notifier.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/update_provider.dart';
import '../services/mobile_image_metadata_importer.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/navigation/main_nav_rail.dart';
import 'app_branch.dart';
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
      ((context, ref) =>
          MobileImageMetadataImporter.shared.run(context: context, ref: ref));
  final queueCount = ref.read(replicationQueueNotifierProvider).count;
  final hasUpdate = ref.read(updateStateProvider).hasNewVersion;
  final activePanel = ref.read(shellPanelProvider);
  final agentRunning =
      ref.read(agentChatNotifierProvider).status == AgentChatRunStatus.running;

  return AdaptivePresenter.showPanel<void>(
    context: context,
    initialChildSize: 0.68,
    minChildSize: 0.52,
    titleBuilder: (context) => Text(
      context.l10n.nav_more,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    builder: (panelContext, scrollController) => ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        _MobileMoreDestination(
          key: const ValueKey('mobile-more-agent'),
          icon: Icons.smart_toy_outlined,
          label: panelContext.l10n.nav_agent,
          selected: activePanel == ShellPanel.agent,
          showBadge: agentRunning,
          onTap: () {
            Navigator.of(panelContext).pop();
            ref.read(shellPanelProvider.notifier).state = ShellPanel.agent;
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
            ref.read(shellPanelProvider.notifier).state = ShellPanel.queue;
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
          icon: Icons.settings_outlined,
          label: panelContext.l10n.settings_title,
          showBadge: hasUpdate,
          onTap: () =>
              _selectBranch(panelContext, navigationShell, AppBranch.settings),
        ),
        const Divider(indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: _MobileCommunityButton(
                  key: const ValueKey('mobile-more-discord'),
                  icon: const Icon(Icons.discord, size: 20),
                  label: panelContext.l10n.nav_joinDiscord,
                  backgroundColor: const Color(0xFF5865F2),
                  onPressed: () =>
                      _openCommunityLink(panelContext, CommunityLinks.discord),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MobileCommunityButton(
                  key: const ValueKey('mobile-more-github'),
                  icon: const GitHubLogo(color: Colors.white, size: 20),
                  label: panelContext.l10n.nav_projectRepository,
                  backgroundColor: const Color(0xFF2D333B),
                  onPressed: () =>
                      _openCommunityLink(panelContext, CommunityLinks.github),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      icon: icon,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected
          ? const Icon(Icons.check_rounded)
          : const Icon(Icons.chevron_right),
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
