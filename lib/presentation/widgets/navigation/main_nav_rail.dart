import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/constants/community_links.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/update_provider.dart';
import '../../router/app_branch.dart';
import '../../themes/theme_extension.dart';
import 'nav_rail_account_button.dart';
import 'nav_rail_expansion.dart';
import 'nav_rail_items.dart';
import 'nav_rail_metrics.dart';

export 'github_logo.dart' show GitHubLogo;

class MainNavRail extends ConsumerWidget {
  static const double collapsedWidth = navRailCollapsedWidth;
  static const double expandedWidth = navRailExpandedWidth;

  static double expandedWidthFor(BuildContext context) =>
      navRailExpandedWidthFor(context);

  static const List<AppBranch> _railBranches = [
    AppBranch.generation,
    AppBranch.localGallery,
    AppBranch.onlineGallery,
    AppBranch.vibeLibrary,
    AppBranch.preciseRefLibrary,
    AppBranch.promptConfig,
    AppBranch.tagLibrary,
    AppBranch.statistics,
    AppBranch.settings,
  ];

  final StatefulNavigationShell navigationShell;
  final bool isAgentVisible;
  final bool isAgentRunning;
  final bool isQueueVisible;
  final bool allowExpansion;
  final FocusNode? agentFocusNode;
  final FocusNode? queueFocusNode;
  final ValueChanged<bool> onAgentVisibilityChanged;
  final ValueChanged<bool> onQueueVisibilityChanged;

  const MainNavRail({
    super.key,
    required this.navigationShell,
    this.isAgentVisible = false,
    this.isAgentRunning = false,
    this.isQueueVisible = false,
    this.allowExpansion = true,
    this.agentFocusNode,
    this.queueFocusNode,
    this.onAgentVisibilityChanged = _ignorePanelVisibilityChange,
    this.onQueueVisibilityChanged = _ignorePanelVisibilityChange,
  });

  static void _ignorePanelVisibilityChange(bool _) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final storedExpansion = ref.watch(
      layoutStateNotifierProvider.select((state) => state.mainNavRailExpanded),
    );
    final isExpanded = allowExpansion && storedExpansion;

    final showUpdateBadge = ref.watch(
      updateStateProvider.select((state) => state.hasNewVersion),
    );
    final queueCount = ref.watch(
      replicationQueueNotifierProvider.select((state) => state.count),
    );
    final queueExecutionStatus = ref.watch(
      queueExecutionNotifierProvider.select((state) => state.status),
    );
    final currentIndex = navigationShell.currentIndex;
    final selectedIndex = _railBranches.indexWhere(
      (branch) => branch.index == currentIndex,
    );
    final motion = theme.appTheme;
    final animationDuration = boundedNavRailMotionDuration(
      context,
      motion.slowDuration,
      minMilliseconds: 180,
      maxMilliseconds: 240,
    );

    return NavRailWidthTransition(
      isExpanded: isExpanded,
      expandedWidth: expandedWidthFor(context),
      duration: animationDuration,
      enterCurve: motion.enterCurve,
      exitCurve: motion.exitCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 账户头像区域
          NavRailAccountButton(ref: ref),

          Expanded(
            child: SingleChildScrollView(
              key: const Key('main-nav-primary-scroll'),
              child: Column(
                children: [
                  // Navigation Items
                  NavRailIcon(
                    key: const Key('nav-branch-0'),
                    icon: Icons.brush, // Canvas/Edit
                    label: context.l10n.nav_canvas,
                    isSelected: selectedIndex == 0,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.generation.index),
                  ),

                  // 本地图库（App生成的图片）
                  NavRailIcon(
                    key: const Key('nav-branch-1'),
                    icon: Icons.folder, // Local Generated Images
                    label: context.l10n.nav_localGallery,
                    isSelected: selectedIndex == 1,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.localGallery.index),
                  ),

                  // 在线画廊
                  NavRailIcon(
                    key: const Key('nav-branch-2'),
                    icon: Icons.photo_library, // Online Gallery
                    label: context.l10n.nav_onlineGallery,
                    isSelected: selectedIndex == 2,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.onlineGallery.index),
                  ),

                  // Vibe库
                  NavRailIcon(
                    key: const Key('nav-branch-3'),
                    icon: Icons.auto_awesome, // Vibe Library
                    label: context.l10n.vibeLibrary_title,
                    isSelected: selectedIndex == 3,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.vibeLibrary.index),
                  ),

                  // 精准参考库
                  NavRailIcon(
                    key: const Key('nav-branch-4'),
                    icon: Icons.center_focus_strong,
                    label: context.l10n.nav_preciseRefLibrary,
                    isSelected: selectedIndex == 4,
                    onTap: () => navigationShell.goBranch(
                      AppBranch.preciseRefLibrary.index,
                    ),
                  ),

                  // 词库
                  NavRailIcon(
                    key: const Key('nav-branch-6'),
                    icon: Icons.book,
                    label: context.l10n.nav_dictionary,
                    isSelected: selectedIndex == 6,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.tagLibrary.index),
                  ),

                  // 随机配置
                  NavRailIcon(
                    key: const Key('nav-branch-5'),
                    icon: Icons.casino, // Random prompt config
                    label: context.l10n.nav_randomConfig,
                    isSelected: selectedIndex == 5,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.promptConfig.index),
                  ),

                  // 统计
                  NavRailIcon(
                    key: const Key('nav-branch-7'),
                    icon: Icons.bar_chart, // Gallery Statistics
                    label: context.l10n.nav_statistics,
                    isSelected: selectedIndex == 7,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.statistics.index),
                  ),
                ],
              ),
            ),
          ),

          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const Key('main-nav-secondary-scroll'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Discord 社群
                      NavRailExternalLinkIcon(
                        icon: Icons.discord,
                        label: context.l10n.nav_discordCommunity,
                        color: const Color(0xFF5865F2), // Discord 紫色
                        url: CommunityLinks.discord,
                      ),

                      // GitHub 仓库
                      NavRailGitHubIcon(
                        url: CommunityLinks.github,
                        label: context.l10n.nav_githubRepo,
                      ),

                      NavRailIcon(
                        key: const Key('agent-nav-item'),
                        focusNode: agentFocusNode,
                        icon: isAgentRunning
                            ? Icons.smart_toy_rounded
                            : Icons.smart_toy_outlined,
                        label: context.l10n.nav_agent,
                        isSelected: isAgentVisible,
                        showBadge: isAgentRunning,
                        onTap: () => onAgentVisibilityChanged(!isAgentVisible),
                      ),

                      NavRailIcon(
                        key: const Key('queue-nav-item'),
                        focusNode: queueFocusNode,
                        icon: switch (queueExecutionStatus) {
                          QueueExecutionStatus.running =>
                            Icons.play_arrow_rounded,
                          QueueExecutionStatus.paused => Icons.pause_rounded,
                          _ => Icons.playlist_play_rounded,
                        },
                        label: context.l10n.queue_management,
                        isSelected: isQueueVisible,
                        badgeLabel: queueCount > 0
                            ? (queueCount > 99 ? '99+' : queueCount.toString())
                            : null,
                        onTap: () => onQueueVisibilityChanged(!isQueueVisible),
                      ),

                      // Bottom Settings
                      NavRailIcon(
                        key: const Key('nav-branch-8'),
                        icon: Icons.settings,
                        label: context.l10n.nav_settings,
                        isSelected: selectedIndex == 8,
                        showBadge: showUpdateBadge,
                        onTap: () =>
                            navigationShell.goBranch(AppBranch.settings.index),
                      ),
                      if (allowExpansion) ...[
                        const SizedBox(height: 2),
                        NavRailToggle(
                          isExpanded: isExpanded,
                          onTap: () {
                            ref
                                .read(layoutStateNotifierProvider.notifier)
                                .toggleMainNavRail();
                          },
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
