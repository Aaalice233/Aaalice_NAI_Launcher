import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/navigation/main_nav_rail.dart';
import 'app_branch.dart';
import 'global_status_banners.dart';
import 'queue_shell_overlay.dart';

/// 桌面端布局
class DesktopShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final Widget content;

  const DesktopShell({
    super.key,
    required this.navigationShell,
    required this.content,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQueueVisible = ref.watch(queueManagementVisibleProvider);

    return Scaffold(
      body: Row(
        children: [
          MainNavRail(
            navigationShell: navigationShell,
            isQueueVisible: isQueueVisible,
            onQueueVisibilityChanged: (isVisible) {
              ref.read(queueManagementVisibleProvider.notifier).state =
                  isVisible;
            },
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: GlobalStatusBanners(),
                ),
                QueueShellOverlay(
                  isVisible: isQueueVisible,
                  desktop: true,
                  onQueueStarted: () =>
                      navigationShell.goBranch(AppBranch.generation.index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
