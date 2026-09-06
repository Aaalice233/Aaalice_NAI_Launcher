import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/utils/localization_extension.dart';
import '../providers/mobile_shell_overlay_provider.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/update_notice_banner.dart';
import 'android_root_back_guard.dart';
import 'app_branch.dart';
import 'global_status_banners.dart';
import 'mobile_more_panel.dart';
import 'shell_panels_overlay.dart';

/// Compact touch-first shell. Secondary destinations remain explicit in the
/// labelled “more” panel instead of disappearing behind desktop-only routes.
class MobileShell extends ConsumerWidget {
  static const double compactNavigationBarHeight = 64;
  static const double maximumNavigationBarHeight = 84;

  final StatefulNavigationShell navigationShell;
  final bool branchCanHandlePop;
  final Widget content;

  const MobileShell({
    super.key,
    required this.navigationShell,
    required this.branchCanHandlePop,
    required this.content,
    this.panelOverlayKey,
  });

  final Key? panelOverlayKey;

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

    final scaffold = Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (constraints.maxHeight * 0.45).clamp(
                        0.0,
                        300.0,
                      ),
                    ),
                    child: const SingleChildScrollView(
                      child: GlobalStatusBanners(),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
              const UpdateNoticeOverlay(),
              ShellPanelsOverlay(
                key: panelOverlayKey,
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
      ),
      bottomNavigationBar: keyboardVisible || shellOverlayActive
          ? null
          : SafeArea(
              top: false,
              child: NavigationBar(
                height: _navigationBarHeight(context),
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
    );

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
        child: AndroidRootBackGuard(
          enabled:
              PlatformCapabilities.current.isAndroid &&
              activePanel == null &&
              !branchCanHandlePop,
          resetKey: navigationShell.currentIndex,
          onExitHint: () =>
              AppToast.info(context, context.l10n.router_backAgainToExit),
          child: scaffold,
        ),
      ),
    );
  }

  double _navigationBarHeight(BuildContext context) {
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(12);
    return (48 + scaledLabelHeight).clamp(
      compactNavigationBarHeight,
      maximumNavigationBarHeight,
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
