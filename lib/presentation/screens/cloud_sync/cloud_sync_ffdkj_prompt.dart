import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncFfdkjPrompt extends ConsumerWidget {
  const CloudSyncFfdkjPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CloudSyncSection(
    title: context.l10n.cloudSync_ffdkjIntentTitle,
    subtitle: context.l10n.cloudSync_ffdkjIntentDescription,
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () => ref
              .read(cloudSyncUiPortProvider)
              .respondToFfdkjInstallIntent(install: false),
          child: Text(context.l10n.cloudSync_clearInstallIntent),
        ),
        FilledButton.tonal(
          onPressed: () => _confirmInstall(context, ref),
          child: Text(context.l10n.autocomplete_install),
        ),
      ],
    ),
  );

  Future<void> _confirmInstall(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.autocomplete_zhDictionary),
        content: Text(context.l10n.cloudSync_ffdkjInstallWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cloudSync_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.autocomplete_install),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(cloudSyncUiPortProvider)
          .respondToFfdkjInstallIntent(install: true);
    } catch (error) {
      if (!context.mounted) return;
      showCloudSyncActionError(context, error);
    }
  }
}
