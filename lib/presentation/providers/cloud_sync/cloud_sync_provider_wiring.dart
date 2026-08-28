import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/cloud_sync/backend/github_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/webdav_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/webdav_backend_config.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/crypto.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/cloud_sync/journal.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../data/cloud_sync/app_cloud_sync_adapters.dart';
import '../../../data/cloud_sync/app_cloud_sync_data_source.dart';
import '../../../data/cloud_sync/agent_cloud_sync_adapters.dart';
import '../../../data/cloud_sync/cloud_sync_data_adapter_registry.dart';
import '../../../data/services/precise_ref_library_storage_service.dart';
import '../../../data/services/tag_library_io_service.dart';
import '../../../data/services/vibe_library_storage_service.dart';
import '../online_gallery_local_favorites_provider.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import 'cloud_sync_application_service.dart';
import 'cloud_sync_ui_provider.dart';

final cloudSyncApplicationStateProvider = StateProvider<CloudSyncUiState>(
  (ref) => const CloudSyncUiState(),
);

final cloudSyncApplicationServiceProvider =
    Provider<CloudSyncApplicationService>((ref) {
      final local = ref.watch(localStorageServiceProvider);
      final service = CloudSyncApplicationService(
        secureStorage: ref.watch(secureStorageServiceProvider),
        localStorage: local,
        installFfdkjDictionary: () =>
            ref.read(zhDictionaryServiceProvider).installOrUpdate(),
        onState: (state) =>
            ref.read(cloudSyncApplicationStateProvider.notifier).state = state,
        backendFactory: (draft) => switch (draft.backend) {
          CloudSyncBackendKind.webDav => _createWebDavBackend(draft),
          CloudSyncBackendKind.github => GitHubCloudSyncBackend(
            owner: draft.owner,
            repository: draft.repository,
            branch: draft.branch,
            token: draft.secret,
            namespace: draft.path.isEmpty ? 'aaalice-sync' : draft.path,
          ),
        },
        coordinatorFactory: (backend, keys, scope, contentSelection) async {
          AgentSkillsCloudSyncAdapter? agentSkills;
          if (contentSelection.includeSkills) {
            final context = await ref
                .read(agentSettingsProvider.notifier)
                .skillBackupContext();
            agentSkills = AgentSkillsCloudSyncAdapter(
              roots: context.roots,
              localEntries: context.entries,
              selectedSkillIds: contentSelection.selectedSkillIds,
            );
          }
          final all = createAppCloudSyncAdapterRegistry(
            localStorage: local,
            vibeLibrary: ref.read(vibeLibraryStorageServiceProvider),
            preciseRefLibrary: ref.read(
              preciseRefLibraryStorageServiceProvider,
            ),
            onlineFavorites: ref.read(
              onlineGalleryLocalFavoritesRepositoryProvider,
            ),
            tagLibraryIO: TagLibraryIOService(),
            isFfdkjInstalled: () =>
                ref.read(zhDictionaryServiceProvider).state.isInstalled,
            recordPendingFfdkjInstallIntent: () => local.setSetting(
              StorageKeys.cloudSyncPendingFfdkjInstall,
              true,
            ),
            agentSkills: agentSkills,
          );
          final registry = CloudSyncDataAdapterRegistry(
            all.adapters.where(
              (adapter) => isCloudSyncAdapterInScope(
                adapter.id,
                scope,
                contentSelection,
              ),
            ),
          );
          final support = await getApplicationSupportDirectory();
          final root = Directory('${support.path}/cloud-sync');
          return SyncCoordinator(
            backend: backend,
            dataSource: AppCloudSyncDataSource(registry: registry, root: root),
            crypto: CloudCrypto(),
            masterKey: keys.masterKey,
            journalStore: JournalStore(File('${root.path}/journal.json')),
          );
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });

WebDavCloudSyncBackend _createWebDavBackend(CloudSyncConnectionDraft draft) {
  final config = WebDavBackendConfig(
    baseUri: Uri.parse(draft.serverUrl),
    namespace: draft.path.isEmpty ? 'aaalice-sync' : draft.path,
    allowInsecureHttp: draft.allowInsecureHttp,
  );
  return WebDavCloudSyncBackend.fromConfig(
    config: config,
    username: draft.username,
    password: draft.secret,
  );
}

bool isCloudSyncAdapterInScope(
  String id,
  Set<CloudSyncDataKind> scope,
  CloudSyncContentSelection contentSelection,
) {
  if (id == 'agent-system-prompt') {
    return contentSelection.includeAgentSystemPrompt;
  }
  if (id == 'agent-skills') return contentSelection.includeSkills;
  if (id == 'vibe-library' || id == 'precise-ref-library') {
    return scope.contains(CloudSyncDataKind.largeBinary);
  }
  if (id.contains('gallery') || id == 'online-favorites') {
    return scope.contains(CloudSyncDataKind.galleries);
  }
  if (id.contains('prompt') ||
      id.contains('tag') ||
      id == 'random-presets' ||
      id == 'ffdkj-install-intent') {
    return scope.contains(CloudSyncDataKind.prompts);
  }
  return scope.contains(CloudSyncDataKind.settings);
}
