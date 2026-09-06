import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/services/interactive_work_gate.dart';
import '../../core/shortcuts/default_shortcuts.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/window_size_class.dart';
import '../agent_chat/widgets/agent_question_notifications.dart';
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
import 'shell_panels_overlay.dart';

export 'desktop_shell.dart' show DesktopShell;
export 'mobile_shell.dart' show MobileShell;
export 'shell_panels_overlay.dart' show ShellPanel, shellPanelProvider;

/// 主布局 Shell - 包含导航 (StatefulShellRoute 版本)
///
/// 已访问分支统一保留 Element/Navigator 状态；隐藏分支通过 TickerMode
/// 与 AppBranchVisibility 暂停动画和主动后台工作。
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
  final Set<int> _visitedBranchIndices = <int>{};
  bool _authPromptVisible = false;
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'main-shell-content');
  final GlobalKey _panelOverlayKey = GlobalKey(
    debugLabel: 'main-shell-panel-overlay',
  );
  final Map<int, bool> _branchCanHandlePop = <int, bool>{};
  ProviderSubscription<AuthPromptRequest?>? _authPromptSubscription;
  late final TimingsCallback _frameTimingsCallback;
  Timer? _navigationTraceTimer;
  int? _tracedBranchIndex;
  int _tracedFrameCount = 0;
  int _slowFrameCount = 0;
  int _firstBuildMicros = 0;
  int _firstTotalMicros = 0;
  int _maxBuildMicros = 0;
  int _maxRasterMicros = 0;
  int _maxTotalMicros = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;
    _visitedBranchIndices.add(widget.navigationShell.currentIndex);
    _frameTimingsCallback = _recordNavigationFrameTimings;
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_frameTimingsCallback);
    }
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
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _beginNavigationTrace(
            widget.navigationShell.currentIndex,
            duration: const Duration(seconds: 4),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _navigationTraceTimer?.cancel();
    if (kDebugMode) {
      SchedulerBinding.instance.removeTimingsCallback(_frameTimingsCallback);
    }
    _authPromptSubscription?.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIndex = widget.navigationShell.currentIndex;
    if (_previousIndex != currentIndex) {
      _visitedBranchIndices.add(currentIndex);
      _beginNavigationTrace(currentIndex);
    }

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

  void _beginNavigationTrace(
    int branchIndex, {
    Duration duration = const Duration(milliseconds: 350),
  }) {
    InteractiveWorkGate.instance.markInteraction();
    if (!kDebugMode) return;
    // Rapid navigation replaces the sample instead of synchronously printing
    // the previous one from the next branch's build frame.
    _navigationTraceTimer?.cancel();
    _navigationTraceTimer = null;
    _tracedBranchIndex = branchIndex;
    _tracedFrameCount = 0;
    _slowFrameCount = 0;
    _firstBuildMicros = 0;
    _firstTotalMicros = 0;
    _maxBuildMicros = 0;
    _maxRasterMicros = 0;
    _maxTotalMicros = 0;
    _navigationTraceTimer = Timer(duration, _finishNavigationTrace);
  }

  void _recordNavigationFrameTimings(List<FrameTiming> timings) {
    if (_tracedBranchIndex == null) return;
    for (final timing in timings) {
      _tracedFrameCount++;
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      final totalMicros = timing.totalSpan.inMicroseconds;
      if (_tracedFrameCount == 1) {
        _firstBuildMicros = buildMicros;
        _firstTotalMicros = totalMicros;
      }
      if (totalMicros > 16667) _slowFrameCount++;
      if (totalMicros > 80000) {
        final branch = AppBranch.values[_tracedBranchIndex!];
        AppLogger.w(
          'Slow navigation frame ${branch.name}: '
              'sequence=$_tracedFrameCount '
              'build=${(buildMicros / 1000).toStringAsFixed(2)}ms '
              'raster=${(rasterMicros / 1000).toStringAsFixed(2)}ms '
              'total=${(totalMicros / 1000).toStringAsFixed(2)}ms',
          'NavigationPerformance',
        );
      }
      if (buildMicros > _maxBuildMicros) _maxBuildMicros = buildMicros;
      if (rasterMicros > _maxRasterMicros) _maxRasterMicros = rasterMicros;
      if (totalMicros > _maxTotalMicros) _maxTotalMicros = totalMicros;
    }
  }

  void _finishNavigationTrace() {
    final branchIndex = _tracedBranchIndex;
    if (branchIndex == null) return;
    _navigationTraceTimer?.cancel();
    _navigationTraceTimer = null;
    _tracedBranchIndex = null;
    final branch = AppBranch.values[branchIndex];
    AppLogger.i(
      'Branch navigation ${branch.name}: frames=$_tracedFrameCount, '
          'slow=$_slowFrameCount, '
          'firstBuild=${(_firstBuildMicros / 1000).toStringAsFixed(2)}ms, '
          'firstTotal=${(_firstTotalMicros / 1000).toStringAsFixed(2)}ms, '
          'maxBuild=${(_maxBuildMicros / 1000).toStringAsFixed(2)}ms, '
          'maxRaster=${(_maxRasterMicros / 1000).toStringAsFixed(2)}ms, '
          'maxTotal=${(_maxTotalMicros / 1000).toStringAsFixed(2)}ms',
      'NavigationPerformance',
    );
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
        final branchNavigator =
            widget.navigationShell.route.branches[index].navigatorKey;

        // 只在首次访问时挂载分支，避免启动时构建全部页面；挂载后始终
        // 保留 Element/Navigator/滚动状态，隐藏时暂停动画及后台工作。
        final branchContent = _visitedBranchIndices.contains(index)
            ? AppBranchVisibility(
                isVisible: isActive,
                child: TickerMode(enabled: isActive, child: child),
              )
            : const SizedBox.shrink();

        // 分支根页面中的 PopScope 不能直接接收根 Router 的系统返回。
        // 由 Shell 把当前分支的返回能力提升到根路由，再交还对应 Navigator。
        return NotificationListener<NavigationNotification>(
          onNotification: (notification) {
            _recordBranchCanHandlePop(index, notification.canHandlePop);
            return false;
          },
          child: NavigatorPopHandler<void>(
            enabled: isActive,
            onPopWithResult: (_) {
              if (isActive) branchNavigator.currentState?.maybePop();
            },
            child: branchContent,
          ),
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
        final activePanel = ref.read(shellPanelProvider);
        ref.read(shellPanelProvider.notifier).state =
            activePanel == ShellPanel.queue ? null : ShellPanel.queue;
      },
    };

    final shortcutEnabledContent = KeyedSubtree(
      key: _contentKey,
      child: ShortcutAwareWidget(
        contextType: ShortcutContext.global,
        shortcuts: globalShortcuts,
        autofocus: true,
        child: dropEnabledContent,
      ),
    );

    return AgentQuestionNotifications(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final safeUsableWidth =
              (constraints.maxWidth - mediaQuery.padding.horizontal)
                  .clamp(0.0, double.infinity)
                  .toDouble();
          final sizeClass = WindowSizeClass.fromWidth(safeUsableWidth);
          if (sizeClass.isExpandedOrWider) {
            return DesktopShell(
              navigationShell: widget.navigationShell,
              content: shortcutEnabledContent,
              panelOverlayKey: _panelOverlayKey,
            );
          }

          return MobileShell(
            navigationShell: widget.navigationShell,
            branchCanHandlePop: _branchCanHandlePop[currentIndex] ?? false,
            content: shortcutEnabledContent,
            panelOverlayKey: _panelOverlayKey,
          );
        },
      ),
    );
  }

  void _recordBranchCanHandlePop(int index, bool canHandlePop) {
    if (_branchCanHandlePop[index] == canHandlePop) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _branchCanHandlePop[index] == canHandlePop) return;
      setState(() => _branchCanHandlePop[index] = canHandlePop);
    });
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
