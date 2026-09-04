import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_error_reporter.dart';
import '../settings/widgets/settings_card.dart';

String localizeCloudSyncError(BuildContext context, String code) =>
    switch (code) {
      'backend.authentication' => context.l10n.cloudSync_errorAuthentication,
      'backend.authorization' => context.l10n.cloudSync_errorAuthorization,
      'backend.notFound' => context.l10n.cloudSync_errorNotFound,
      'backend.conflict' => context.l10n.cloudSync_errorConflict,
      'backend.quota' => context.l10n.cloudSync_errorQuota,
      'backend.rateLimited' => context.l10n.cloudSync_errorRateLimited,
      'backend.redirectRejected' => context.l10n.cloudSync_errorRedirect,
      'backend.invalidResponse' => context.l10n.cloudSync_errorInvalidResponse,
      'backend.network' => context.l10n.cloudSync_errorNetwork,
      'previewStale' => context.l10n.cloudSync_errorPreviewStale,
      'format' => context.l10n.cloudSync_errorFormat,
      'configuration' => context.l10n.cloudSync_errorConfiguration,
      'state' => context.l10n.cloudSync_errorState,
      _ => context.l10n.cloudSync_errorUnknown,
    };

void showCloudSyncActionError(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.cloudSync_actionFailed(
            localizeCloudSyncError(context, cloudSyncErrorMessage(error)),
          ),
        ),
      ),
    );
}

class CloudSyncSection extends StatelessWidget {
  const CloudSyncSection({
    super.key,
    this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SettingsCard(
      title: title,
      description: subtitle,
      trailing: trailing,
      child: child,
    ),
  );
}

class CloudSyncSurface extends StatelessWidget {
  const CloudSyncSurface({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class CloudSyncField extends StatelessWidget {
  const CloudSyncField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextField(
          key: ValueKey('cloud-sync-field-$label'),
          controller: controller,
          obscureText: obscureText,
          enableSuggestions: !obscureText,
          autocorrect: !obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          decoration: const InputDecoration(filled: true),
        ),
      ),
    ],
  );
}

class CloudSyncMetadata extends StatelessWidget {
  const CloudSyncMetadata({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Padding(
        padding: const EdgeInsets.only(right: 20, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class CloudSyncStatusBanner extends StatelessWidget {
  const CloudSyncStatusBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = warning ? colors.onErrorContainer : colors.onSurface;
    return CloudSyncSurface(
      color: warning ? colors.errorContainer : colors.surfaceContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: foreground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatCloudBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '$bytes B';
}
