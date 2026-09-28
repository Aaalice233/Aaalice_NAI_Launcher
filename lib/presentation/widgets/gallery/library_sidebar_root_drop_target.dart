import 'package:flutter/material.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../common/app_toast.dart';

class LibrarySidebarRootDropTarget<T extends Object> extends StatelessWidget {
  const LibrarySidebarRootDropTarget({
    super.key,
    required this.child,
    required this.canDrop,
    required this.onDrop,
  });

  final Widget child;
  final bool Function(T) canDrop;
  final Future<void> Function(T) onDrop;

  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onWillAcceptWithDetails: (details) => canDrop(details.data),
    onAcceptWithDetails: (details) async {
      try {
        await onDrop(details.data);
      } catch (error, stack) {
        AppLogger.e(
          'Sidebar move to root failed',
          error,
          stack,
          'GallerySidebar',
        );
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.categoryError_moveFailed(error.toString()),
          );
        }
      }
    },
    builder: (context, candidates, rejected) => ColoredBox(
      color: candidates.isEmpty
          ? Colors.transparent
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: child,
    ),
  );
}
