import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/community_links.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/services/auth_error_service.dart';
import '../../core/shortcuts/default_shortcuts.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/adaptive_presenter.dart';
import '../adaptive/window_size_class.dart';
import '../providers/auth_provider.dart';
import '../providers/mobile_shell_overlay_provider.dart';
import '../providers/prompt_maximize_provider.dart';
import '../providers/replication_queue_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/app_branch_visibility.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/update_notice_banner.dart';
import '../widgets/drop/global_drop_handler.dart';
import '../widgets/navigation/main_nav_rail.dart';
import '../widgets/queue/queue_management_page.dart';
import '../widgets/shortcuts/shortcut_aware_widget.dart';
import '../widgets/shortcuts/shortcut_help_dialog.dart';
import 'app_branch.dart';
import 'app_routes.dart';

/// 队列管理面板显示状态 Provider
final queueManagementVisibleProvider = StateProvider<bool>((ref) => false);

/// 主布局 Shell - 包含导航 (StatefulShellRoute 版本)
///
/// 使用混合保活策略：
/// - 画廊页面（索引 1, 2）使用 Offstage 保活
/// - Vibe库页面（索引 7）使用 Offstage 保活
/// - 其他页面不保活
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const MainShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int? _previousIndex;
  bool _authPromptVisible = false;
  ProviderSubscription<AuthPromptRequest?>? _authPromptSubscription;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;
    _authPromptSubscription = ref.listenManual<AuthPromptRequest?>(
      authPromptRequestProvider,
      (previous, next) {
        if (next == null || next.id == previous?.id) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAuthPrompt(next);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authPromptSubscription?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndex = widget.navigationShell.currentIndex;

    if (_previousIndex == AppBranch.generation.index &&
        currentIndex != AppBranch.generation.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.navigationShell.currentIndex == AppBranch.generation.index) {
          return;
        }
        ref.read(promptMaximizeNotifierProvider.notifier).setMaximized(false);
      });
    }
    _previousIndex = currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // 构建混合保活内容栈
    // - 索引 1 (localGallery) 和 2 (onlineGallery) 使用 Offstage 保活
    // - 索引 7 (vibeLibrary) 和 8 (preciseRefLibrary) 使用 Offstage 保活
    // - 其他索引不保活，切换时销毁重建
    final contentStack = IndexedStack(
      index: currentIndex,
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final isActive = index == currentIndex;
        final branchNavigator =
            widget.navigationShell.route.branches[index].navigatorKey;

        Widget branchContent;
        // 保活页面：画廊（1, 2）、Vibe 库（7）和精准参考库（8）
        // 始终保持在树中，通过 TickerMode 控制动画
        if (index == 1 || index == 2 || index == 7 || index == 8) {
          branchContent = AppBranchVisibility(
            isVisible: isActive,
            child: TickerMode(enabled: isActive, child: child),
          );
        } else if (!isActive) {
          // 其他索引：非活动时显示空容器（不保活）
          branchContent = const SizedBox.shrink();
        } else {
          branchContent = AppBranchVisibility(isVisible: true, child: child);
        }

        // 分支根页面中的 PopScope 不能直接接收根 Router 的系统返回。
        // 由 Shell 把当前分支的返回能力提升到根路由，再交还对应 Navigator。
        return NavigatorPopHandler<void>(
          enabled: isActive,
          onPopWithResult: (_) {
            if (isActive) branchNavigator.currentState?.maybePop();
          },
          child: branchContent,
        );
      }).toList(),
    );

    // 外部拖放只在系统提供桌面拖放会话时挂载，避免触控平台创建无效通道。
    final dropEnabledContent =
        PlatformCapabilities.current.supportsExternalFileDrop
        ? GlobalDropHandler(child: contentStack)
        : contentStack;

    // 定义全局快捷键动作映射（使用 ShortcutIds 常量）
    final globalShortcuts = <String, VoidCallback>{
      for (final entry in globalNavigationShortcutBranches.entries)
        entry.key: () => widget.navigationShell.goBranch(entry.value.index),
      // 显示快捷键帮助
      ShortcutIds.showShortcutHelp: () {
        ShortcutHelpDialog.show(context);
      },
      // 显示/隐藏队列
      ShortcutIds.toggleQueue: () {
        final isVisible = ref.read(queueManagementVisibleProvider);
        ref.read(queueManagementVisibleProvider.notifier).state = !isVisible;
      },
    };

    // 使用 ShortcutAwareWidget 包装全局快捷键
    final shortcutEnabledContent = ShortcutAwareWidget(
      contextType: ShortcutContext.global,
      shortcuts: globalShortcuts,
      autofocus: true,
      child: dropEnabledContent,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
        if (!sizeClass.isCompact) {
          return DesktopShell(
            navigationShell: widget.navigationShell,
            content: shortcutEnabledContent,
          );
        }

        return MobileShell(
          navigationShell: widget.navigationShell,
          content: shortcutEnabledContent,
        );
      },
    );
  }

  Future<void> _showAuthPrompt(AuthPromptRequest request) async {
    if (_authPromptVisible) return;
    _authPromptVisible = true;
    try {
      final details = switch (request.reason) {
        AuthPromptReason.imageGeneration =>
          context.l10n.auth_loginRequiredImageGeneration,
        AuthPromptReason.queueExecution =>
          context.l10n.auth_loginRequiredQueueExecution,
        AuthPromptReason.directorTools =>
          context.l10n.auth_loginRequiredDirectorTools,
        AuthPromptReason.novelAiUpscale =>
          context.l10n.auth_loginRequiredNovelAiUpscale,
        AuthPromptReason.kritaBridge =>
          context.l10n.auth_loginRequiredKritaBridge,
        AuthPromptReason.vibeEncoding =>
          context.l10n.auth_loginRequiredVibeEncoding,
        AuthPromptReason.sessionExpired => context.l10n.api_error_401_hint,
      };
      final openLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.auth_login),
          content: Text(details),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.settings_goToLogin),
            ),
          ],
        ),
      );
      if (openLogin == true && mounted) {
        context.push(AppRoutes.login);
      }
    } finally {
      ref.read(authPromptRequestProvider.notifier).consume(request.id);
      _authPromptVisible = false;
      final pending = ref.read(authPromptRequestProvider);
      if (pending != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAuthPrompt(pending);
        });
      }
    }
  }
}

class _GlobalStatusBanners extends StatelessWidget {
  const _GlobalStatusBanners();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [UpdateNoticeBanner(), _AuthRecoveryBanner()],
    );
  }
}

class _AuthRecoveryBanner extends ConsumerWidget {
  const _AuthRecoveryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final errorCode = authState.errorCode;
    if (authState.status != AuthStatus.error || errorCode == null) {
      return const SizedBox.shrink();
    }

    final message = AuthErrorService().getErrorText(
      context.l10n,
      errorCode,
      authState.httpStatusCode,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              key: const ValueKey('auth-recovery-banner'),
              color: colorScheme.surfaceContainerHigh,
              elevation: 4,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = MediaQuery.sizeOf(context).width < 520;
                  final messageRow = Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (compact)
                        IconButton(
                          key: const ValueKey('auth-recovery-dismiss'),
                          onPressed: () => authNotifier.clearError(delayMs: 0),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  );
                  final actions = [
                    TextButton.icon(
                      key: const ValueKey('auth-recovery-retry'),
                      onPressed: authNotifier.retryAutoLogin,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(context.l10n.common_retry),
                    ),
                    FilledButton.tonalIcon(
                      key: const ValueKey('auth-recovery-login'),
                      onPressed: () => context.push(AppRoutes.login),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(context.l10n.settings_goToLogin),
                    ),
                  ];

                  if (compact) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          messageRow,
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(spacing: 8, children: actions),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    child: Row(
                      children: [
                        Expanded(child: messageRow),
                        const SizedBox(width: 8),
                        ...actions,
                        IconButton(
                          key: const ValueKey('auth-recovery-dismiss'),
                          onPressed: () => authNotifier.clearError(delayMs: 0),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    content,
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _GlobalStatusBanners(),
                    ),
                    _QueuePanel(
                      isVisible: isQueueVisible,
                      desktop: true,
                      onQueueStarted: () =>
                          navigationShell.goBranch(AppBranch.generation.index),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
    final isQueueVisible = ref.watch(queueManagementVisibleProvider);
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

    return PopScope<void>(
      canPop: !isQueueVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isQueueVisible) {
          ref.read(queueManagementVisibleProvider.notifier).state = false;
        }
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
                child: _GlobalStatusBanners(),
              ),
              _QueuePanel(
                isVisible: isQueueVisible,
                desktop: false,
                onQueueStarted: () =>
                    navigationShell.goBranch(AppBranch.generation.index),
              ),
            ],
          ),
        ),
        bottomNavigationBar: keyboardVisible || shellOverlayActive
            ? null
            : NavigationBar(
                selectedIndex: isQueueVisible
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
  }

  void _onNavigate(BuildContext context, int mobileIndex, WidgetRef ref) {
    if (mobileIndex == mobileMoreNavigationIndex) {
      ref.read(queueManagementVisibleProvider.notifier).state = false;
      _showMorePanel(context, ref);
      return;
    }

    ref.read(queueManagementVisibleProvider.notifier).state = false;
    if (mobileIndex < 0 || mobileIndex >= mobileNavigationBranches.length) {
      return;
    }
    navigationShell.goBranch(mobileNavigationBranches[mobileIndex].index);
  }

  Future<void> _showMorePanel(BuildContext context, WidgetRef ref) {
    final queueCount = ref.read(replicationQueueNotifierProvider).count;
    final hasUpdate = ref.read(updateStateProvider).hasNewVersion;

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
            icon: Icons.playlist_play_rounded,
            label: panelContext.l10n.queue_management,
            badgeCount: queueCount,
            onTap: () {
              Navigator.of(panelContext).pop();
              ref.read(queueManagementVisibleProvider.notifier).state = true;
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          _MobileMoreDestination(
            icon: Icons.style_outlined,
            label: panelContext.l10n.vibeLibrary_title,
            onTap: () => _selectBranch(panelContext, AppBranch.vibeLibrary),
          ),
          _MobileMoreDestination(
            icon: Icons.center_focus_strong_outlined,
            label: panelContext.l10n.nav_preciseRefLibrary,
            onTap: () =>
                _selectBranch(panelContext, AppBranch.preciseRefLibrary),
          ),
          _MobileMoreDestination(
            icon: Icons.casino_outlined,
            label: panelContext.l10n.nav_randomConfig,
            onTap: () => _selectBranch(panelContext, AppBranch.promptConfig),
          ),
          _MobileMoreDestination(
            icon: Icons.insights_outlined,
            label: panelContext.l10n.statistics_title,
            onTap: () => _selectBranch(panelContext, AppBranch.statistics),
          ),
          const Divider(indent: 16, endIndent: 16),
          _MobileMoreDestination(
            icon: Icons.settings_outlined,
            label: panelContext.l10n.settings_title,
            showBadge: hasUpdate,
            onTap: () => _selectBranch(panelContext, AppBranch.settings),
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

  void _selectBranch(BuildContext panelContext, AppBranch branch) {
    Navigator.of(panelContext).pop();
    navigationShell.goBranch(branch.index);
  }
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool showBadge;

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
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

// ============================================
// 队列面板组件
// ============================================

/// 队列管理面板组件
///
/// 带背景遮罩、滑动动画和队列管理页面
class _QueuePanel extends ConsumerWidget {
  final bool isVisible;
  final bool desktop;
  final VoidCallback onQueueStarted;

  const _QueuePanel({
    required this.isVisible,
    required this.desktop,
    required this.onQueueStarted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 背景遮罩
            if (isVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(queueManagementVisibleProvider.notifier).state =
                          false,
                  child: ColoredBox(
                    color: theme.colorScheme.scrim.withValues(
                      alpha: desktop ? 0.28 : 0.36,
                    ),
                  ),
                ),
              ),
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: desktop ? const Offset(1, 0) : const Offset(0, 1),
                end: isVisible
                    ? Offset.zero
                    : (desktop ? const Offset(1, 0) : const Offset(0, 1)),
              ),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                final hidden = desktop ? offset.dx >= 0.5 : offset.dy >= 0.5;
                return ExcludeSemantics(
                  excluding: hidden,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: FractionalTranslation(
                      translation: offset,
                      child: child,
                    ),
                  ),
                );
              },
              child: Align(
                alignment: desktop
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                child: SizedBox(
                  width: desktop ? 460 : constraints.maxWidth,
                  child: Material(
                    color: theme.scaffoldBackgroundColor,
                    elevation: 18,
                    shadowColor: Colors.black.withValues(alpha: 0.28),
                    borderRadius: desktop
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          )
                        : const BorderRadius.vertical(top: Radius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: desktop
                            ? constraints.maxHeight
                            : constraints.maxHeight * 0.85,
                        child: QueueManagementPage(
                          onClose: () =>
                              ref
                                      .read(
                                        queueManagementVisibleProvider.notifier,
                                      )
                                      .state =
                                  false,
                          onQueueStarted: onQueueStarted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
