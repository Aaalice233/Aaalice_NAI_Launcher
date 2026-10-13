import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/replication_queue_provider.dart';
import 'shell_panels_overlay.dart';

/// 系统返回与 Escape 共用的面板退出顺序：先退出队列多选，再关闭面板。
class ShellPanelDismissScope extends ConsumerWidget {
  const ShellPanelDismissScope({
    super.key,
    required this.activePanel,
    required this.onClose,
    required this.child,
  });

  final ShellPanel? activePanel;
  final VoidCallback onClose;
  final Widget child;

  void _dismiss(WidgetRef ref) {
    if (activePanel == null) return;
    if (activePanel == ShellPanel.queue &&
        ref.read(replicationQueueNotifierProvider).isSelectionMode) {
      ref.read(replicationQueueNotifierProvider.notifier).exitSelectionMode();
      return;
    }
    onClose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        if (activePanel != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _dismiss(ref),
      },
      child: PopScope<void>(
        canPop: activePanel == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _dismiss(ref);
        },
        child: child,
      ),
    );
  }
}
