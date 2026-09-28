import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import '../settings/widgets/settings_page_layout.dart';
import 'cloud_sync_dashboard.dart';
import 'cloud_sync_setup.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncScreen extends ConsumerWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncUiStateProvider);
    return SettingsPageLayout(
      title: context.l10n.cloudSync_title,
      description: context.l10n.cloudSync_description,
      children: [
        if (state.error != null)
          CloudSyncStatusBanner(
            icon: Icons.error_outline,
            title: context.l10n.cloudSync_operationFailed,
            message: localizeCloudSyncError(context, state.error!),
            warning: true,
          ),
        if (state.connectionStatus == CloudSyncConnectionStatus.restoring)
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CloudSyncStatusBanner(
                  icon: Icons.cloud_sync_outlined,
                  title: context.l10n.cloudSync_restoringConnection,
                  message:
                      context.l10n.cloudSync_restoringConnectionDescription,
                ),
                if (state.accountLabel?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(state.accountLabel!),
                  ),
              ],
            ),
          )
        else if (state.isConnected)
          CloudSyncDashboard(state: state)
        else
          const CloudSyncSetup(),
      ],
    );
  }
}
