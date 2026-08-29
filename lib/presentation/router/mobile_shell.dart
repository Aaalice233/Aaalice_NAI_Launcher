import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/localization_extension.dart';
import '../providers/mobile_shell_overlay_provider.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/update_provider.dart';
import 'app_branch.dart';
import 'global_status_banners.dart';
import 'mobile_more_panel.dart';
import 'shell_panels_overlay.dart';

/// Compact touch-first shell. Secondary destinations remain explicit in the
/// labelled “more” panel instead of disappearing behind desktop-only routes.
class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final Widget content;

  const MobileShell({
    super.key,
    required this.navigationShell,
    required this.content,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePanel = ref.watch(shellPanelProvider);
    final showUpdateBadge = ref.watch(
      updateStateProvider.select((state) => state.hasNewVersion),
    );
    final queueCount = ref.watch(
      replicationQueueNotifierProvider.select((state) => state.count),
    );
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final shellOverlayActive = ref.watch(
      mobileShellOverlayNotifierProvider.select(
        (overlays) => overlays.isNotEmpty,
      ),
    );

    void closePanel() {
      ref.read(shellPanelProvider.notifier).state = null;
    }

    return CallbackShortcuts(
      bindings: {
        if (activePanel != null)
          const SingleActivator(LogicalKeyboardKey.escape): closePanel,
      },
      child: PopScope<void>(
        canPop: activePanel == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && activePanel != null) closePanel();
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
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
                ShellPanelsOverlay(
                  activePanel: activePanel,
                  desktop: false,
                  onClose: closePanel,
                  onQueueStarted: () =>
                      navigationShell.goBranch(AppBranch.generation.index),
                  onOpenAgentSettings: () =>
                      navigationShell.goBranch(AppBranch.settings.index),
                ),
              ],
            ),
          ),
          bottomNavigationBar: keyboardVisible || shellOverlayActive
              ? null
              : NavigationBar(
                  selectedIndex: activePanel != null
                      ? mobileMoreNavigationIndex
                      : mobileNavigationIndexForBranch(
                          navigationShell.currentIndex,
                        ),
                  onDestinationSelected: (index) =>
                      _onNavigate(context, index, ref),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.auto_awesome_outlined),
                      selectedIcon: const Icon(Icons.auto_awesome),
                      label: context.l10n.nav_generate,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.photo_library_outlined),
                      selectedIcon: const Icon(Icons.photo_library),
                      label: context.l10n.nav_gallery,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.travel_explore_outlined),
                      selectedIcon: const Icon(Icons.travel_explore),
                      label: context.l10n.nav_explore,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.library_books_outlined),
                      selectedIcon: const Icon(Icons.library_books),
                      label: context.l10n.nav_dictionary,
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: queueCount > 0 || showUpdateBadge,
                        label: queueCount > 0
                            ? Text(
                                queueCount > 99 ? '99+' : queueCount.toString(),
                              )
                            : null,
                        smallSize: 7,
                        child: const Icon(Icons.apps_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: queueCount > 0 || showUpdateBadge,
                        label: queueCount > 0
                            ? Text(
                                queueCount > 99 ? '99+' : queueCount.toString(),
                              )
                            : null,
                        smallSize: 7,
                        child: const Icon(Icons.apps),
                      ),
                      label: context.l10n.nav_more,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _onNavigate(BuildContext context, int mobileIndex, WidgetRef ref) {
    if (mobileIndex == mobileMoreNavigationIndex) {
      showMobileMorePanel(
        context: context,
        ref: ref,
        navigationShell: navigationShell,
      );
      return;
    }

    if (mobileIndex < 0 || mobileIndex >= mobileNavigationBranches.length) {
      return;
    }
    navigationShell.goBranch(mobileNavigationBranches[mobileIndex].index);
  }
}
