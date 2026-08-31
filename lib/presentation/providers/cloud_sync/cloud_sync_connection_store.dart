import 'dart:convert';
import 'dart:io';

import '../../../core/constants/storage_keys.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'cloud_sync_ui_provider.dart';

class PersistedCloudSyncConnection {
  const PersistedCloudSyncConnection({
    required this.draft,
    required this.dataKinds,
    required this.contentSelection,
    this.remoteRevision,
    this.lastSync,
  });

  final CloudSyncConnectionDraft draft;
  final Set<CloudSyncDataKind> dataKinds;
  final CloudSyncContentSelection contentSelection;
  final String? remoteRevision;
  final DateTime? lastSync;
}

class CloudSyncConnectionStore {
  CloudSyncConnectionStore({
    required LocalStorageService localStorage,
    required SecureStorageService secureStorage,
    String Function()? deviceIdFactory,
  }) : _localStorage = localStorage,
       _secureStorage = secureStorage,
       _deviceIdFactory =
           deviceIdFactory ??
           (() =>
               '${Platform.localHostname}-${DateTime.now().microsecondsSinceEpoch}');

  final LocalStorageService _localStorage;
  final SecureStorageService _secureStorage;
  final String Function() _deviceIdFactory;
  static const _configurationVersion = 3;

  Future<CloudSyncUiState> initializeState(CloudSyncUiState state) async {
    final deviceId = await ensureDeviceId();
    return state.copyWith(
      deviceName: deviceId,
      pendingFfdkjInstall:
          _localStorage.getSetting<bool>(
            StorageKeys.cloudSyncPendingFfdkjInstall,
            defaultValue: false,
          ) ??
          false,
    );
  }

  Future<String> ensureDeviceId() async {
    var value = _localStorage.getSetting<String>(StorageKeys.cloudSyncDeviceId);
    if (value != null) return value;
    value = _deviceIdFactory();
    await _localStorage.setSetting(StorageKeys.cloudSyncDeviceId, value);
    return value;
  }

  Future<void> save(
    CloudSyncConnectionDraft draft,
    Set<CloudSyncDataKind> dataKinds, {
    CloudSyncContentSelection contentSelection =
        const CloudSyncContentSelection(),
    String? remoteRevision,
    DateTime? lastSync,
  }) async {
    await _secureStorage.saveCloudSyncCredentials(
      jsonEncode({'username': draft.username, 'secret': draft.secret}),
    );
    final configurationKey = draft.backend.usesOAuth
        ? StorageKeys.cloudDriveConfiguration
        : StorageKeys.cloudSyncConfiguration;
    await _localStorage.setSetting(
      configurationKey,
      jsonEncode({
        'version': _configurationVersion,
        'backend': draft.backend.name,
        'serverUrl': draft.serverUrl,
        'owner': draft.owner,
        'repository': draft.repository,
        'branch': draft.branch,
        'path': draft.path,
        'allowInsecureHttp': draft.allowInsecureHttp,
        'accountId': draft.accountId,
        'accountLabel': draft.accountLabel,
        'dataKinds': dataKinds.map((value) => value.name).toList(),
        'contentSelection': contentSelection.toJson(),
        'remoteRevision': remoteRevision,
        'lastSync': lastSync?.toUtc().toIso8601String(),
      }),
    );
    await _localStorage.deleteSetting(
      draft.backend.usesOAuth
          ? StorageKeys.cloudSyncConfiguration
          : StorageKeys.cloudDriveConfiguration,
    );
  }

  Future<void> saveSyncState({
    required String remoteRevision,
    required DateTime lastSync,
  }) async {
    final cloudDriveText = _localStorage.getSetting<String>(
      StorageKeys.cloudDriveConfiguration,
    );
    final configurationKey = cloudDriveText == null
        ? StorageKeys.cloudSyncConfiguration
        : StorageKeys.cloudDriveConfiguration;
    final publicText =
        cloudDriveText ??
        _localStorage.getSetting<String>(StorageKeys.cloudSyncConfiguration);
    if (publicText == null) return;
    final public = Map<String, Object?>.from(jsonDecode(publicText) as Map);
    public['remoteRevision'] = remoteRevision;
    public['lastSync'] = lastSync.toUtc().toIso8601String();
    await _localStorage.setSetting(configurationKey, jsonEncode(public));
  }

  Future<PersistedCloudSyncConnection?> load() async {
    final cloudDriveText = _localStorage.getSetting<String>(
      StorageKeys.cloudDriveConfiguration,
    );
    final configurationKey = cloudDriveText == null
        ? StorageKeys.cloudSyncConfiguration
        : StorageKeys.cloudDriveConfiguration;
    final publicText =
        cloudDriveText ??
        _localStorage.getSetting<String>(StorageKeys.cloudSyncConfiguration);
    final secretText = await _secureStorage.getCloudSyncCredentials();
    if (publicText == null || secretText == null) return null;
    final public = Map<String, Object?>.from(jsonDecode(publicText) as Map);
    final secret = jsonDecode(secretText) as Map;
    final version = public['version'] as int? ?? 1;
    if (version < 1 || version > _configurationVersion) {
      throw const FormatException('Unsupported cloud sync configuration.');
    }
    if (version < _configurationVersion) {
      public['version'] = _configurationVersion;
      await _localStorage.setSetting(configurationKey, jsonEncode(public));
    }
    final scope = (public['dataKinds'] as List? ?? const [])
        .whereType<String>()
        .map(CloudSyncDataKind.values.byName)
        .toSet();
    return PersistedCloudSyncConnection(
      draft: CloudSyncConnectionDraft(
        backend: CloudSyncBackendKind.values.byName(
          public['backend'] as String,
        ),
        serverUrl: public['serverUrl'] as String? ?? '',
        username: secret['username'] as String? ?? '',
        secret: secret['secret'] as String? ?? '',
        owner: public['owner'] as String? ?? '',
        repository: public['repository'] as String? ?? '',
        branch: public['branch'] as String? ?? 'main',
        path: public['path'] as String? ?? '',
        allowInsecureHttp: public['allowInsecureHttp'] as bool? ?? false,
        accountId: public['accountId'] as String? ?? '',
        accountLabel: public['accountLabel'] as String? ?? '',
      ),
      dataKinds: scope.isEmpty ? CloudSyncDataKind.values.toSet() : scope,
      contentSelection: public['contentSelection'] == null
          ? const CloudSyncContentSelection()
          : CloudSyncContentSelection.decode(
              jsonEncode(public['contentSelection']),
            ),
      remoteRevision: public['remoteRevision'] as String?,
      lastSync: DateTime.tryParse(public['lastSync'] as String? ?? ''),
    );
  }

  Future<void> clear() async {
    await _secureStorage.clearCloudSyncSecrets();
    await Future.wait([
      _localStorage.deleteSetting(StorageKeys.cloudSyncConfiguration),
      _localStorage.deleteSetting(StorageKeys.cloudDriveConfiguration),
    ]);
  }
}
