import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/krita/krita_bridge_notifier.dart';
import '../widgets/settings_card.dart';

class KritaBridgeSettingsSection extends ConsumerWidget {
  const KritaBridgeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(kritaBridgeNotifierProvider);
    final notifier = ref.read(kritaBridgeNotifierProvider.notifier);
    final l10n = context.l10n;

    return SettingsCard(
      title: l10n.settings_integrationConnectionSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            secondary: Icon(_statusIcon(state.status)),
            title: Text(l10n.settings_kritaBridgeEnable),
            subtitle: Text(_statusText(context, state)),
            value: state.enabled,
            onChanged: state.status == KritaBridgeStatus.starting
                ? null
                : (value) async {
                    await notifier.setEnabled(value);
                  },
          ),
          if (state.enabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.circle,
                size: 12,
                color: _statusColor(theme, state.status),
              ),
              title: Text(_statusLabel(context, state.status)),
              subtitle: Text(_connectionDetails(context, state)),
              trailing: TextButton.icon(
                onPressed: state.status == KritaBridgeStatus.starting
                    ? null
                    : () async {
                        await notifier.regenerateSession();
                      },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.settings_kritaBridgeRegenerateSession),
              ),
            ),
            if (state.discoveryFilePath != null)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.settings_kritaBridgeDiscoveryFile),
                subtitle: SelectableText(state.discoveryFilePath!),
              ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _statusText(BuildContext context, KritaBridgeState state) {
    final l10n = context.l10n;
    return switch (state.status) {
      KritaBridgeStatus.disabled => l10n.settings_kritaBridgeDisabledText,
      KritaBridgeStatus.starting => l10n.settings_kritaBridgeStartingText,
      KritaBridgeStatus.listening => l10n.settings_kritaBridgeListeningText,
      KritaBridgeStatus.connected => l10n.settings_kritaBridgeConnectedText,
      KritaBridgeStatus.error => l10n.settings_kritaBridgeErrorText,
    };
  }

  String _statusLabel(BuildContext context, KritaBridgeStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      KritaBridgeStatus.disabled => l10n.settings_kritaBridgeDisabled,
      KritaBridgeStatus.starting => l10n.settings_kritaBridgeStarting,
      KritaBridgeStatus.listening => l10n.settings_kritaBridgeListening,
      KritaBridgeStatus.connected => l10n.settings_kritaBridgeConnected,
      KritaBridgeStatus.error => l10n.settings_kritaBridgeError,
    };
  }

  String _connectionDetails(BuildContext context, KritaBridgeState state) {
    final l10n = context.l10n;
    final endpoint = state.port == null
        ? l10n.settings_kritaBridgeWaitingEndpoint
        : 'ws://127.0.0.1:${state.port}/krita';
    final client = state.connectedClientLabel;
    if (client == null || client.isEmpty) {
      return endpoint;
    }
    return '$endpoint\n${l10n.settings_kritaBridgeClient(client)}';
  }

  IconData _statusIcon(KritaBridgeStatus status) {
    return switch (status) {
      KritaBridgeStatus.connected => Icons.link,
      KritaBridgeStatus.listening => Icons.sensors,
      KritaBridgeStatus.starting => Icons.hourglass_top,
      KritaBridgeStatus.error => Icons.error_outline,
      KritaBridgeStatus.disabled => Icons.link_off,
    };
  }

  Color _statusColor(ThemeData theme, KritaBridgeStatus status) {
    return switch (status) {
      KritaBridgeStatus.connected => Colors.green,
      KritaBridgeStatus.listening => Colors.amber,
      KritaBridgeStatus.starting => theme.colorScheme.primary,
      KritaBridgeStatus.error => theme.colorScheme.error,
      KritaBridgeStatus.disabled => theme.colorScheme.outline,
    };
  }
}
