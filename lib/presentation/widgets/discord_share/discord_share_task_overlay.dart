import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/discord_share_task_provider.dart';
import '../../themes/core/layered_surface_style.dart';
import 'discord_share_error.dart';

class DiscordShareTaskOverlay extends ConsumerWidget {
  const DiscordShareTaskOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(discordShareTaskProvider);
    return Stack(
      children: [
        child,
        if (task != null)
          PositionedDirectional(
            end: 12,
            start: 12,
            bottom: 12,
            child: SafeArea(
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Material(
                    color: overlaySurfaceColor(Theme.of(context).colorScheme),
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(_message(context, task)),
                          ),
                          if (!task.running)
                            Wrap(
                              alignment: WrapAlignment.end,
                              children: [
                                if (task.canRetry)
                                  TextButton(
                                    onPressed: task.retrySeconds > 0
                                        ? null
                                        : ref
                                              .read(
                                                discordShareTaskProvider
                                                    .notifier,
                                              )
                                              .retry,
                                    child: Text(context.l10n.common_retry),
                                  ),
                                TextButton(
                                  onPressed: ref
                                      .read(discordShareTaskProvider.notifier)
                                      .dismiss,
                                  child: Text(context.l10n.common_close),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _message(BuildContext context, DiscordShareTaskState task) {
    if (task.running) return context.l10n.discordShare_sending;
    if (task.error != null) {
      return discordShareErrorText(
        context,
        task.error!,
        retrySeconds: task.retrySeconds,
      );
    }
    return task.result?.isPartial == true
        ? context.l10n.discordShare_partialSuccess
        : context.l10n.discordShare_success;
  }
}
