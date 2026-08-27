import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/update_provider.dart';
import 'update_check_dialog.dart';

/// 新版本的持久、非阻塞提示。
///
/// 它位于主界面 Navigator 内，不依赖启动包装器的无效 context；关闭后
/// 会进入明确的稍后提醒周期，设置页和导航红点仍保留更新入口。
class UpdateNoticeBanner extends ConsumerWidget {
  const UpdateNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateStateProvider);
    final hasNotice = state.hasNewVersion || state.status == UpdateStatus.error;
    if (!state.notificationVisible || !hasNotice) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isReady = state.hasDownloadedUpdate;
    final isError = state.status == UpdateStatus.error;
    final version = state.versionInfo?.displayVersion ?? '';
    final title = isError
        ? context.l10n.updateNoticeFailed
        : isReady
        ? context.l10n.updateNoticeReady(version)
        : context.l10n.updateNoticeAvailable(version);
    final subtitle = isError
        ? (state.errorMessage ?? context.l10n.updateError)
        : isReady
        ? context.l10n.updateNoticeReadySubtitle
        : state.versionInfo?.supportsInAppInstall == true
        ? context.l10n.updateNoticeAvailableSubtitle
        : context.l10n.updateNoticeManualSubtitle;
    final accent = isError
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Material(
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.24),
              color: theme.colorScheme.surfaceContainerHigh,
              surfaceTintColor: accent,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final icon = _NoticeIcon(
                      accent: accent,
                      isError: isError,
                      isReady: isReady,
                    );
                    final action = FilledButton.tonal(
                      onPressed: () => UpdateCheckDialog.show(context),
                      child: Text(
                        isReady
                            ? context.l10n.updateInstallNow
                            : context.l10n.updateViewDetails,
                      ),
                    );
                    final dismiss = IconButton(
                      tooltip: context.l10n.remindMeLater,
                      onPressed: () =>
                          ref.read(updateStateProvider.notifier).remindLater(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    );
                    final titleText = Text(
                      title,
                      maxLines: constraints.maxWidth < 520 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final subtitleText = Text(
                      subtitle,
                      maxLines: constraints.maxWidth < 520 ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );

                    if (constraints.maxWidth < 520) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                icon,
                                const SizedBox(width: 12),
                                Expanded(child: titleText),
                                dismiss,
                              ],
                            ),
                            const SizedBox(height: 8),
                            subtitleText,
                            const SizedBox(height: 10),
                            action,
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                      child: Row(
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleText,
                                const SizedBox(height: 2),
                                subtitleText,
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          action,
                          dismiss,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({
    required this.accent,
    required this.isError,
    required this.isReady,
  });

  final Color accent;
  final bool isError;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isError
            ? Icons.error_outline_rounded
            : isReady
            ? Icons.restart_alt_rounded
            : Icons.system_update_alt_rounded,
        color: accent,
        size: 22,
      ),
    );
  }
}
