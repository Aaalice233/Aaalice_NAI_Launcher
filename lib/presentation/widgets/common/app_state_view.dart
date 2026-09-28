import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../adaptive/interaction_policy.dart';

enum AppStateKind { empty, loading, error }

/// Shared empty/loading/error presentation for full-page and panel states.
class AppStateView extends StatelessWidget {
  const AppStateView.empty({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionLoading = false,
  }) : kind = AppStateKind.empty;

  const AppStateView.loading({super.key, required this.title, this.message})
    : kind = AppStateKind.loading,
      icon = null,
      actionLabel = null,
      actionIcon = null,
      onAction = null,
      actionLoading = false;

  const AppStateView.error({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.error_outline_rounded,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
    this.actionLoading = false,
  }) : kind = AppStateKind.error;

  final AppStateKind kind;
  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stateColor = switch (kind) {
      AppStateKind.error => colors.error,
      AppStateKind.empty => colors.onSurfaceVariant,
      AppStateKind.loading => colors.primary,
    };
    final semanticsLabel = message == null ? title : '$title. $message';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                container: true,
                liveRegion: kind != AppStateKind.empty,
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (kind == AppStateKind.loading)
                        SizedBox.square(
                          dimension: 36,
                          child: CircularProgressIndicator(
                            color: stateColor,
                            strokeWidth: 3,
                            value: MediaQuery.disableAnimationsOf(context)
                                ? 0.72
                                : null,
                          ),
                        )
                      else if (icon != null)
                        Icon(icon, size: 48, color: stateColor),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (message != null && message!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  enabled: !actionLoading,
                  liveRegion: actionLoading,
                  label: actionLoading
                      ? '$actionLabel, '
                            '${AppLocalizations.of(context)?.common_loading ?? 'Loading…'}'
                      : actionLabel,
                  child: ExcludeSemantics(
                    child: FilledButton.tonalIcon(
                      onPressed: actionLoading ? null : onAction,
                      style: FilledButton.styleFrom(
                        minimumSize: Size(
                          0,
                          context.interactionPolicy.minimumControlExtent,
                        ),
                      ),
                      icon: actionLoading
                          ? SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.72
                                    : null,
                              ),
                            )
                          : Icon(actionIcon ?? Icons.arrow_forward_rounded),
                      label: Text(actionLabel!),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
