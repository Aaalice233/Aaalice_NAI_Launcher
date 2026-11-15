import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/replication_queue_provider.dart';
import 'shell_panels_overlay.dart';

/// 系统返回与 Escape 共用的面板退出顺序：先退出队列多选，再关闭面板。
class ShellPanelDismissScope extends ConsumerStatefulWidget {
  const ShellPanelDismissScope({
    super.key,
    required this.activePanel,
    required this.onClose,
    required this.child,
  });

  final ShellPanel? activePanel;
  final VoidCallback onClose;
  final Widget child;

  @override
  ConsumerState<ShellPanelDismissScope> createState() =>
      _ShellPanelDismissScopeState();
}

class _ShellPanelDismissScopeState
    extends ConsumerState<ShellPanelDismissScope> {
  BackButtonDispatcher? _parentDispatcher;
  ChildBackButtonDispatcher? _backDispatcher;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentDispatcher = Router.maybeOf(context)?.backButtonDispatcher;
    if (!identical(parentDispatcher, _parentDispatcher)) {
      _backDispatcher?.removeCallback(_handleBackButton);
      _parentDispatcher = parentDispatcher;
      if (parentDispatcher == null) {
        _backDispatcher = null;
      } else {
        _backDispatcher = parentDispatcher.createChildBackButtonDispatcher()
          ..addCallback(_handleBackButton);
        if (widget.activePanel != null) {
          _backDispatcher!.takePriority();
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant ShellPanelDismissScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePanel == null && widget.activePanel != null) {
      _backDispatcher?.takePriority();
    }
  }

  @override
  void dispose() {
    _backDispatcher?.removeCallback(_handleBackButton);
    super.dispose();
  }

  Future<bool> _handleBackButton() {
    if (!mounted || widget.activePanel == null) {
      return SynchronousFuture<bool>(false);
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return SynchronousFuture<bool>(false);
    }
    _dismiss();
    return SynchronousFuture<bool>(true);
  }

  void _dismiss() {
    final activePanel = widget.activePanel;
    if (activePanel == null) return;
    if (activePanel == ShellPanel.queue &&
        ref.read(replicationQueueNotifierProvider).isSelectionMode) {
      ref.read(replicationQueueNotifierProvider.notifier).exitSelectionMode();
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        if (widget.activePanel != null)
          const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
      },
      child: PopScope<void>(
        canPop: widget.activePanel == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _dismiss();
        },
        child: widget.child,
      ),
    );
  }
}
