import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_namespace.dart';
import 'package:nai_launcher/core/cloud_sync/content_selection.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_provider_wiring.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test(
    'v3 namespace isolates the protocol while preserving configured path',
    () {
      expect(cloudSyncV3Namespace(''), 'aaalice-sync-v3');
      expect(cloudSyncV3Namespace('team/backups'), 'team/backups-v3');
      expect(cloudSyncV3Namespace('aaalice-sync'), isNot('aaalice-sync'));
    },
  );

  test('WebDAV and GitHub use the same Agent payload selection rules', () {
    const selection = CloudSyncContentSelection(
      includeAgentSystemPrompt: true,
      includeSkills: true,
      selectedSkillIds: {'workspace:test-skill'},
    );
    const scope = {CloudSyncDataKind.settings};
    const adapterIds = [
      'agent-system-prompt',
      'agent-skills',
      'local-settings',
      'prompt-assistant',
    ];

    final payloadByBackend = <CloudSyncBackendKind, List<String>>{};
    for (final backend in CloudSyncBackendKind.values) {
      payloadByBackend[backend] = adapterIds
          .where((id) => isCloudSyncAdapterInScope(id, scope, selection))
          .toList();
    }

    expect(
      payloadByBackend[CloudSyncBackendKind.webDav],
      payloadByBackend[CloudSyncBackendKind.github],
    );
    expect(
      payloadByBackend[CloudSyncBackendKind.webDav],
      containsAll(['agent-system-prompt', 'agent-skills', 'local-settings']),
    );
    expect(
      payloadByBackend[CloudSyncBackendKind.webDav],
      isNot(contains('prompt-assistant')),
    );
  });
}
