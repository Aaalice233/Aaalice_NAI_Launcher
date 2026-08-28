import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_dashboard.dart';
import 'cloud_sync_setup.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncScreen extends ConsumerWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncUiStateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.cloudSync_title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.cloudSync_description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (state.error != null) ...[
          CloudSyncStatusBanner(
            icon: Icons.error_outline,
            title: context.l10n.cloudSync_testFailed,
            message: state.error!,
            warning: true,
          ),
          const SizedBox(height: 16),
        ],
        if (state.isConnected)
          CloudSyncDashboard(state: state)
        else
          const CloudSyncSetup(),
      ],
    );
  }
}
