import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_error_service.dart';
import '../../core/utils/localization_extension.dart';
import '../adaptive/interaction_policy.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/update_notice_banner.dart';
import 'app_routes.dart';

class GlobalStatusBanners extends StatelessWidget {
  const GlobalStatusBanners({super.key});

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
    final dismissButtonExtent = context.interactionPolicy.minimumControlExtent;
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              key: const ValueKey('auth-recovery-banner'),
              color: colorScheme.surfaceContainerHigh,
              elevation: 4,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final compact = constraints.maxWidth < 600 || textScale > 1.3;
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
                          maxLines: compact ? null : 2,
                          overflow: compact
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
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
                          constraints: BoxConstraints.tightFor(
                            width: dismissButtonExtent,
                            height: dismissButtonExtent,
                          ),
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
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: actions,
                            ),
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
                          constraints: BoxConstraints.tightFor(
                            width: dismissButtonExtent,
                            height: dismissButtonExtent,
                          ),
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
