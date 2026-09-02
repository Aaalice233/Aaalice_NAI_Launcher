import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/autocomplete/autocomplete_providers.dart';
import '../../../core/cloud_sync/backend/cloud_namespace.dart';
import '../../../core/cloud_sync/backend/github_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/google_drive_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/onedrive_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/webdav_cloud_sync_backend.dart';
import '../../../core/cloud_sync/backend/webdav_backend_config.dart';
import '../../../core/cloud_sync/cloud_drive_provider.dart';
import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/cloud_sync/journal.dart';
import '../../../core/cloud_sync/oauth/cloud_drive_oauth_factory.dart';
import '../../../core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
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
import 'cloud_sync_runtime_refresh.dart';
import 'cloud_sync_ui_provider.dart';

final cloudSyncApplicationStateProvider = StateProvider<CloudSyncUiState>(
  (ref) => const CloudSyncUiState(),
);

final cloudDriveOAuthRuntimeProvider = Provider<CloudDriveOAuthRuntime>((ref) {
  return createCloudDriveOAuthRuntime(ref.watch(secureStorageServiceProvider));
});

final cloudDriveProviderRegistryProvider = Provider<CloudDriveProviderRegistry>(
  (ref) {
    final runtime = ref.watch(cloudDriveOAuthRuntimeProvider);
    return CloudDriveProviderRegistry([
      OAuthCloudDriveProvider(
        id: CloudDriveOAuthProvider.googleDrive,
        config: runtime.config,
        tokens: runtime.tokens,
        backendBuilder: ({required accessTokenProvider, required namespace}) =>
            GoogleDriveCloudSyncBackend(
              accessTokenProvider: accessTokenProvider,
              namespace: namespace,
            ),
      ),
      OAuthCloudDriveProvider(
        id: CloudDriveOAuthProvider.oneDrive,
        config: runtime.config,
        tokens: runtime.tokens,
        backendBuilder: ({required accessTokenProvider, required namespace}) =>
            OneDriveCloudSyncBackend(
              accessTokenProvider: accessTokenProvider,
              namespace: namespace,
            ),
      ),
    ]);
  },
);

final cloudSyncApplicationServiceProvider =
    Provider<CloudSyncApplicationService>((ref) {
      final local = ref.watch(localStorageServiceProvider);
      final driveProviders = ref.watch(cloudDriveProviderRegistryProvider);
      final service = CloudSyncApplicationService(
        secureStorage: ref.watch(secureStorageServiceProvider),
        cloudDriveProviders: driveProviders,
        localStorage: local,
        installFfdkjDictionary: () =>
            ref.read(zhDictionaryServiceProvider).installOrUpdate(),
        onState: (state) =>
            ref.read(cloudSyncApplicationStateProvider.notifier).state = state,
        backendFactory: (draft) {
          final namespace = cloudSyncV3Namespace(draft.path);
          return switch (draft.backend) {
            CloudSyncBackendKind.webDav => _createWebDavBackend(
              draft,
              namespace,
            ),
            CloudSyncBackendKind.github => GitHubCloudSyncBackend(
              owner: draft.owner,
              repository: draft.repository,
              branch: draft.branch,
              token: draft.secret,
              namespace: namespace,
            ),
            CloudSyncBackendKind.googleDrive || CloudSyncBackendKind.oneDrive =>
              driveProviders
                  .require(draft.backend.oauthProvider)
                  .createBackend(
                    accountId: draft.accountId,
                    namespace: namespace,
                  ),
          };
        },
        coordinatorFactory:
            (backend, scope, contentSelection, connection) async {
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
                afterApply: (adapterIds) =>
                    refreshCloudSyncRuntime(ref, adapterIds),
              );
              final support = await getApplicationSupportDirectory();
              final root = _cloudSyncLocalRoot(support, connection);
              return SyncCoordinator(
                backend: backend,
                dataSource: AppCloudSyncDataSource(
                  registry: registry,
                  root: root,
                ),
                journalStore: JournalStore(File('${root.path}/journal.json')),
              );
            },
      );
      ref.onDispose(service.dispose);
      return service;
    });

Directory _cloudSyncLocalRoot(
  Directory support,
  CloudSyncConnectionDraft connection,
) {
  if (connection.backend.usesOAuth && connection.accountId.isEmpty) {
    throw StateError('Cloud-drive account identity is missing.');
  }
  final namespace = cloudSyncV3Namespace(connection.path);
  final identity = switch (connection.backend) {
    CloudSyncBackendKind.webDav =>
      '${connection.serverUrl}\n${connection.username}\n$namespace',
    CloudSyncBackendKind.github =>
      '${connection.owner}\n${connection.repository}\n'
          '${connection.branch}\n$namespace',
    CloudSyncBackendKind.googleDrive ||
    CloudSyncBackendKind.oneDrive => '${connection.accountId}\n$namespace',
  };
  final connectionHash = sha256.convert(utf8.encode(identity));
  return Directory(
    '${support.path}/cloud-sync-v3/providers/'
    '${connection.backend.name}/$connectionHash',
  );
}

WebDavCloudSyncBackend _createWebDavBackend(
  CloudSyncConnectionDraft draft,
  String namespace,
) {
  final config = WebDavBackendConfig(
    baseUri: Uri.parse(draft.serverUrl),
    namespace: namespace,
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
