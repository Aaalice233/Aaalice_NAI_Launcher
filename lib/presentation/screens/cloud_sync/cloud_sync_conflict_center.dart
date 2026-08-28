import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncConflictCenter extends ConsumerWidget {
  const CloudSyncConflictCenter({super.key, required this.conflicts});

  final List<CloudSyncConflictView> conflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncUiStateProvider);
    final groups = <CloudSyncDataKind, List<CloudSyncConflictView>>{};
    for (final conflict in conflicts) {
      groups.putIfAbsent(conflict.kind, () => []).add(conflict);
    }
    return CloudSyncSection(
      title: context.l10n.cloudSync_conflictCenter,
      subtitle: context.l10n.cloudSync_conflictDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CloudSyncStatusBanner(
            icon: Icons.warning_amber_rounded,
            title: context.l10n.cloudSync_needsConflictResolution,
            message: context.l10n.cloudSync_deferredConflictWarning,
            warning: true,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(context.l10n.cloudSync_applyAll),
              _bulkButton(context, ref, state, CloudSyncConflictChoice.local),
              _bulkButton(context, ref, state, CloudSyncConflictChoice.remote),
              _bulkButton(
                context,
                ref,
                state,
                CloudSyncConflictChoice.keepBoth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in groups.entries) ...[
            Text(
              _kindLabel(context, entry.key),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final conflict in entry.value) ...[
              _ConflictItem(conflict: conflict),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _bulkButton(
    BuildContext context,
    WidgetRef ref,
    CloudSyncUiState state,
    CloudSyncConflictChoice choice,
  ) => FilledButton.tonal(
    key: ValueKey('cloud-sync-bulk-${choice.name}'),
    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed:
        state.isBusy ||
            state.capabilityMode == CloudSyncCapabilityMode.manualBackupOnly
        ? null
        : () => _runCloudSyncAction(
            context,
            () => ref.read(cloudSyncUiPortProvider).resolveAllConflicts(choice),
          ),
    child: Text(_choiceLabel(context, choice)),
  );
}

class _ConflictItem extends ConsumerWidget {
  const _ConflictItem({required this.conflict});

  final CloudSyncConflictView conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncUiStateProvider);
    return CloudSyncSurface(
      key: ValueKey('cloud-sync-conflict-${conflict.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(conflict.title, style: Theme.of(context).textTheme.titleSmall),
          if (conflict.kind == CloudSyncDataKind.largeBinary) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.cloudSync_largeBinaryKeepBothDefault,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 16) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summary(
                    context,
                    width,
                    context.l10n.cloudSync_base,
                    conflict.baseSummary,
                  ),
                  _summary(
                    context,
                    width,
                    context.l10n.cloudSync_local,
                    conflict.localSummary,
                  ),
                  _summary(
                    context,
                    width,
                    context.l10n.cloudSync_remote,
                    conflict.remoteSummary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in CloudSyncConflictChoice.values)
                FilledButton.tonal(
                  key: ValueKey(
                    'cloud-sync-conflict-${conflict.id}-${choice.name}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: conflict.effectiveChoice == choice
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed:
                      state.isBusy ||
                          state.capabilityMode ==
                              CloudSyncCapabilityMode.manualBackupOnly
                      ? null
                      : () => _runCloudSyncAction(
                          context,
                          () => ref
                              .read(cloudSyncUiPortProvider)
                              .resolveConflict(conflict.id, choice),
                        ),
                  child: Text(_choiceLabel(context, choice)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    double width,
    String label,
    String value,
  ) => SizedBox(
    width: width,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value),
          ],
        ),
      ),
    ),
  );
}

String _choiceLabel(BuildContext context, CloudSyncConflictChoice choice) =>
    switch (choice) {
      CloudSyncConflictChoice.local => context.l10n.cloudSync_chooseLocal,
      CloudSyncConflictChoice.remote => context.l10n.cloudSync_chooseRemote,
      CloudSyncConflictChoice.keepBoth => context.l10n.cloudSync_keepBoth,
    };

String _kindLabel(BuildContext context, CloudSyncDataKind kind) =>
    switch (kind) {
      CloudSyncDataKind.settings => context.l10n.cloudSync_kindSettings,
      CloudSyncDataKind.prompts => context.l10n.cloudSync_kindPrompts,
      CloudSyncDataKind.galleries => context.l10n.cloudSync_kindGalleries,
      CloudSyncDataKind.largeBinary => context.l10n.cloudSync_kindLargeFiles,
    };

Future<void> _runCloudSyncAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cloudSync_actionFailed('$error'))),
    );
  }
}
