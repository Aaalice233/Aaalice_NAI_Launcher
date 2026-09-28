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
      'portable-settings',
      'prompt-assistant-profile',
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
      containsAll(['agent-system-prompt', 'agent-skills', 'portable-settings']),
    );
    expect(
      payloadByBackend[CloudSyncBackendKind.webDav],
      isNot(contains('prompt-assistant-profile')),
    );
  });

  test(
    'large-file libraries are excluded by default and opt in explicitly',
    () {
      const scope = {CloudSyncDataKind.largeBinary};
      const selection = CloudSyncContentSelection();

      expect(
        isCloudSyncAdapterInScope('precise-ref-library', scope, selection),
        isFalse,
      );
      expect(
        isCloudSyncAdapterInScope('vibe-library', scope, selection),
        isFalse,
      );
      const optedIn = CloudSyncContentSelection(
        includeVibes: true,
        includePreciseReferences: true,
      );
      expect(
        isCloudSyncAdapterInScope('precise-ref-library', scope, optedIn),
        isTrue,
      );
      expect(isCloudSyncAdapterInScope('vibe-library', scope, optedIn), isTrue);
    },
  );

  test('gallery albums are lightweight while image bytes have no adapter', () {
    const scope = {CloudSyncDataKind.galleries};
    const selection = CloudSyncContentSelection();

    expect(
      isCloudSyncAdapterInScope('gallery-albums', scope, selection),
      isTrue,
    );
    expect(
      isCloudSyncAdapterInScope('local-gallery-images', scope, selection),
      isFalse,
    );
  });
}
