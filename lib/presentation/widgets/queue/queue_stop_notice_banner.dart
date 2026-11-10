import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../adaptive/interaction_policy.dart';
import '../../providers/queue_execution_provider.dart';

/// 队列执行区内说明队列为何被停下的一行错误提示。
class QueueStopNoticeBanner extends StatelessWidget {
  const QueueStopNoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final QueueStopNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = colorScheme.onErrorContainer;
    final message = switch (notice) {
      QueueStopNotice.storageWriteFailed =>
        context.l10n.queue_stoppedStorageWriteFailed,
    };
    final dismissExtent = context.interactionPolicy.minimumControlExtent;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        key: const ValueKey('queue-stop-notice'),
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('queue-stop-notice-dismiss'),
                tooltip: context.l10n.common_close,
                onPressed: onDismiss,
                constraints: BoxConstraints.tightFor(
                  width: dismissExtent,
                  height: dismissExtent,
                ),
                icon: Icon(Icons.close_rounded, size: 18, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
