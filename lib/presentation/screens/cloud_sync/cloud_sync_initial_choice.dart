import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncInitialChoice extends StatelessWidget {
  const CloudSyncInitialChoice({
    super.key,
    required this.value,
    required this.manualBackupOnly,
    required this.busy,
    required this.onChanged,
    required this.onConnect,
  });

  final CloudSyncInitialAction? value;
  final bool manualBackupOnly;
  final bool busy;
  final ValueChanged<CloudSyncInitialAction?> onChanged;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => CloudSyncSection(
    title: context.l10n.cloudSync_initialSync,
    subtitle: context.l10n.cloudSync_initialSyncDescription,
    child: Column(
      children: [
        RadioGroup<CloudSyncInitialAction>(
          groupValue: value,
          onChanged: onChanged,
          child: Column(
            children: [
              _tile(
                CloudSyncInitialAction.upload,
                context.l10n.cloudSync_initialUpload,
              ),
              if (!manualBackupOnly) ...[
                _tile(
                  CloudSyncInitialAction.download,
                  context.l10n.cloudSync_initialDownload,
                ),
                _tile(
                  CloudSyncInitialAction.mergePreview,
                  context.l10n.cloudSync_previewMergeRecommended,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: busy || value == null ? null : onConnect,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(context.l10n.cloudSync_connect),
          ),
        ),
      ],
    ),
  );

  Widget _tile(CloudSyncInitialAction value, String label) =>
      RadioListTile<CloudSyncInitialAction>(
        minTileHeight: 56,
        value: value,
        title: Text(label),
      );
}
