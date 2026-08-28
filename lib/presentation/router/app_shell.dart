import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/shortcuts/default_shortcuts.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/window_size_class.dart';
import '../providers/auth_provider.dart';
import '../providers/prompt_maximize_provider.dart';
import '../widgets/app_branch_visibility.dart';
import '../widgets/drop/global_drop_handler.dart';
import '../widgets/shortcuts/shortcut_aware_widget.dart';
import '../widgets/shortcuts/shortcut_help_dialog.dart';
import 'app_branch.dart';
import 'app_routes.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';
import 'queue_shell_overlay.dart';

export 'desktop_shell.dart' show DesktopShell;
export 'mobile_shell.dart' show MobileShell;
export 'queue_shell_overlay.dart' show queueManagementVisibleProvider;

/// 主布局 Shell - 包含导航 (StatefulShellRoute 版本)
///
/// 使用混合保活策略：画廊、Vibe 库和精准参考库分支使用 Offstage
/// 保活，其他分支离开时销毁。
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

    final contentStack = IndexedStack(
      index: currentIndex,
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final isActive = index == currentIndex;
        final branch = AppBranch.values[index];
        final branchNavigator =
            widget.navigationShell.route.branches[index].navigatorKey;

        Widget branchContent;
        if (keptAliveAppBranches.contains(branch)) {
          branchContent = AppBranchVisibility(
            isVisible: isActive,
            child: TickerMode(enabled: isActive, child: child),
          );
        } else if (!isActive) {
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

    final globalShortcuts = <String, VoidCallback>{
      for (final entry in globalNavigationShortcutBranches.entries)
        entry.key: () => widget.navigationShell.goBranch(entry.value.index),
      ShortcutIds.showShortcutHelp: () {
        ShortcutHelpDialog.show(context);
      },
      ShortcutIds.toggleQueue: () {
        final isVisible = ref.read(queueManagementVisibleProvider);
        ref.read(queueManagementVisibleProvider.notifier).state = !isVisible;
      },
    };

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
