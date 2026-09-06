import 'dart:convert';

import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/cloud_sync/content_selection.dart';
import '../../core/shortcuts/shortcut_config.dart';
import '../../core/storage/local_storage_service.dart';
import '../models/gallery/gallery_album.dart';
import '../models/prompt/random_preset.dart';
import '../models/prompt/tag_favorite.dart';
import '../models/prompt/tag_template.dart';
import '../repositories/gallery_folder_repository.dart';
import '../services/precise_ref_library_storage_service.dart';
import '../services/tag_library_io_service.dart';
import '../services/vibe_library_storage_service.dart';
import '../repositories/online_gallery_local_favorites_repository.dart';
import '../repositories/online_gallery_blacklist_repository.dart';
import '../services/gallery/gallery_album_sidecar_service.dart';
import 'cloud_sync_data_adapter.dart';
import 'cloud_sync_data_adapter_registry.dart';
import 'agent_cloud_sync_adapters.dart';
import 'ffdkj_install_intent_adapter.dart';
import 'gallery_album_cloud_sync_adapter.dart';
import 'online_favorites_cloud_sync_adapter.dart';
import 'portable_sync_record.dart';
import 'precise_ref_cloud_sync_adapter.dart';
import 'strict_hive_cloud_sync_adapter.dart';
import 'vibe_library_cloud_sync_adapter.dart';
import 'user_tag_library_cloud_sync_adapter.dart';

GalleryAlbum galleryAlbumFromRecord(GalleryAlbumRecord record) {
  return GalleryAlbum(
    id: record.id,
    name: record.name,
    description: record.description,
    parentId: record.parentId,
    sortOrder: record.sortOrder,
    coverPath: record.coverPath,
    pendingPaths: record.pendingPaths,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

CloudSyncDataAdapterRegistry createAppCloudSyncAdapterRegistry({
  required LocalStorageService localStorage,
  required VibeLibraryStorageService vibeLibrary,
  required PreciseRefLibraryStorageService preciseRefLibrary,
  required OnlineGalleryLocalFavoritesRepository onlineFavorites,
  required TagLibraryIOService tagLibraryIO,
  required bool Function() isFfdkjInstalled,
  required Future<void> Function() recordPendingFfdkjInstallIntent,
  required CloudSyncContentSelection contentSelection,
  AgentSkillsCloudSyncAdapter? agentSkills,
}) {
  final galleryDataSource = GalleryDataSource();
  Future<List<GalleryAlbumRecord>> galleryAlbumRecords() =>
      galleryDataSource.albums.getAlbums();

  return CloudSyncDataAdapterRegistry([
    SettingsCloudSyncAdapter(
      localStorage,
      includeAppSettings: contentSelection.includeSettings,
      includePromptsAndTags: contentSelection.includePromptsAndTags,
      includeOnlineGallerySettings:
          contentSelection.includeOnlineGallerySettings,
    ),
    AgentSystemPromptCloudSyncAdapter(localStorage),
    if (agentSkills != null) agentSkills,
    GalleryBlacklistCloudSyncAdapter(
      OnlineGalleryBlacklistRepository(localStorage),
    ),
    UserTagLibraryCloudSyncAdapter(
      localStorage,
      tagLibraryIO,
      includeThumbnails: contentSelection.includeTagThumbnails,
    ),
    StrictHiveCloudSyncAdapter(
      id: 'tag-favorites',
      boxName: StorageKeys.tagFavoritesBox,
      allowedKeyPredicate: _isPortableModelId,
      valueNormalizer: _normalizeTagFavorite,
      modelIdOf: _modelIdOf,
    ),
    StrictHiveCloudSyncAdapter(
      id: 'tag-templates',
      boxName: StorageKeys.tagTemplatesBox,
      allowedKeyPredicate: _isPortableModelId,
      valueNormalizer: _normalizeTagTemplate,
      modelIdOf: _modelIdOf,
    ),
    StrictHiveCloudSyncAdapter(
      id: 'random-presets',
      boxName: 'random_presets',
      allowedKeyPredicate: _isRandomPresetKey,
      valueNormalizer: _normalizeRandomPreset,
      modelIdOf: (key, _) => key,
      typedStringBox: true,
      plainStringKeys: const {'selected_preset_id'},
    ),
    StrictHiveCloudSyncAdapter(
      id: 'shortcuts',
      boxName: 'shortcuts',
      allowedKeys: const {'shortcut_config'},
      valueNormalizer: _normalizeShortcutConfig,
      modelIdOf: (key, _) => key,
    ),
    PromptAssistantProfileCloudSyncAdapter(localStorage),
    OnlineFavoritesCloudSyncAdapter(onlineFavorites),
    GalleryAlbumCloudSyncAdapter(
      readAlbums: () async => [
        for (final record in await galleryAlbumRecords())
          galleryAlbumFromRecord(record),
      ],
      readMemberPaths: galleryDataSource.albums.getAllAlbumMemberPaths,
      applyAlbums: (imports, deletedAlbumIds) async {
        final rootPath = await GalleryFolderRepository.instance.getRootPath();
        final absolutePathByRelative = <String, String>{};
        if (rootPath != null && rootPath.isNotEmpty) {
          for (final import in imports) {
            for (final path in import.imagePaths) {
              absolutePathByRelative[path] =
                  GalleryAlbumSidecarService.toAbsolutePath(rootPath, path);
            }
          }
        }
        final idMap = absolutePathByRelative.isEmpty
            ? const <String, int?>{}
            : await galleryDataSource.getImageIdsByPaths(
                absolutePathByRelative.values.toList(growable: false),
              );

        final albums = <GalleryAlbumRecord>[];
        final imageIdsByAlbumId = <String, List<int>>{};
        final pendingPathsByAlbumId = <String, List<String>>{};
        for (final import in imports) {
          final imageIds = <int>[];
          final pendingPaths = <String>[];
          for (final path in import.imagePaths) {
            final absolutePath = absolutePathByRelative[path];
            final imageId = absolutePath == null ? null : idMap[absolutePath];
            if (imageId != null) {
              imageIds.add(imageId);
            } else {
              pendingPaths.add(path);
            }
          }
          final album = import.album;
          albums.add(
            GalleryAlbumRecord(
              id: album.id,
              name: album.name,
              description: album.description,
              parentId: album.parentId,
              sortOrder: album.sortOrder,
              coverPath:
                  album.coverPath == null ||
                      rootPath == null ||
                      rootPath.isEmpty
                  ? album.coverPath
                  : GalleryAlbumSidecarService.toAbsolutePath(
                      rootPath,
                      album.coverPath!,
                    ),
              pendingPaths: pendingPaths,
              createdAt: album.createdAt,
              updatedAt: album.updatedAt,
            ),
          );
          imageIdsByAlbumId[album.id] = imageIds;
          pendingPathsByAlbumId[album.id] = pendingPaths;
        }

        await galleryDataSource.albums.applyCloudSyncAlbums(
          albums,
          imageIdsByAlbumId,
          pendingPathsByAlbumId: pendingPathsByAlbumId,
          deletedAlbumIds: deletedAlbumIds,
        );
      },
      getRootPath: GalleryFolderRepository.instance.getRootPath,
    ),
    VibeLibraryCloudSyncAdapter(vibeLibrary),
    PreciseRefCloudSyncAdapter(preciseRefLibrary),
    FfdkjInstallIntentAdapter(
      isInstalled: isFfdkjInstalled,
      recordPendingIntent: recordPendingFfdkjInstallIntent,
    ),
  ]);
}

/// Explicit portable settings. Absence from this set means local-only.
const portableSettingKeys = <String>{
  'dlss_options',
  StorageKeys.themeType,
  StorageKeys.fontFamily,
  StorageKeys.fontScale,
  StorageKeys.locale,
  StorageKeys.watermarkConfigV1,
  StorageKeys.historyClickBehavior,
  StorageKeys.previewTransparencyBackground,
  StorageKeys.compositionGuideMode,
  StorageKeys.compositionGuideColumns,
  StorageKeys.compositionGuideRows,
  StorageKeys.defaultModel,
  StorageKeys.defaultSampler,
  StorageKeys.defaultSteps,
  StorageKeys.defaultScale,
  StorageKeys.defaultWidth,
  StorageKeys.defaultHeight,
  StorageKeys.selectedResolutionPresetId,
  StorageKeys.autoSaveImages,
  StorageKeys.imageStraightAlpha,
  StorageKeys.shareStripMetadata,
  StorageKeys.addQualityTags,
  StorageKeys.ucPresetType,
  StorageKeys.qualityPresetMode,
  StorageKeys.qualityPresetNaiTier,
  StorageKeys.qualityPresetCustomId,
  StorageKeys.qualityPresetCustomIds,
  StorageKeys.ucPresetCustomId,
  StorageKeys.ucPresetCustomIds,
  StorageKeys.randomPromptMode,
  StorageKeys.showRandomPromptTools,
  StorageKeys.generationStreamPreviewEnabled,
  StorageKeys.imagesPerRequest,
  StorageKeys.enableAutocomplete,
  StorageKeys.autocompleteResultLimit,
  StorageKeys.autocompleteShowAliases,
  StorageKeys.autocompleteShowTranslations,
  StorageKeys.autocompleteAutoComma,
  StorageKeys.autocompleteReplaceUnderscores,
  StorageKeys.autocompleteOpenOnTagClick,
  StorageKeys.autocompleteDanbooruEnabled,
  StorageKeys.autocompleteLlmTranslationEnabled,
  StorageKeys.autoFormatPrompt,
  StorageKeys.highlightEmphasis,
  StorageKeys.sdSyntaxAutoConvert,
  StorageKeys.resolveAliasOnCopy,
  StorageKeys.enablePromptWeightScroll,
  StorageKeys.promptRegexRules,
  StorageKeys.discordShareIncludeMetadata,
  StorageKeys.discordSharePromptCategories,
  StorageKeys.discordShareLongPromptAsFile,
  StorageKeys.queueRetryCount,
  StorageKeys.queueRetryInterval,
  StorageKeys.queueAutoExecute,
  StorageKeys.queueTaskInterval,
  StorageKeys.queueFailureStrategy,
  StorageKeys.tagLibraryViewMode,
  StorageKeys.notificationSoundEnabled,
  StorageKeys.includePrereleaseUpdates,
  StorageKeys.hfTranslationRefreshInterval,
  StorageKeys.danbooruTagsHotThreshold,
  StorageKeys.danbooruTagsHotPreset,
  StorageKeys.danbooruTagsRefreshInterval,
  StorageKeys.danbooruTagsRefreshIntervalDays,
  StorageKeys.enableSmartTagRecommendation,
  StorageKeys.enableCooccurrenceRecommendation,
  StorageKeys.autoDownloadCooccurrenceData,
  StorageKeys.danbooruCategoryThresholds,
  StorageKeys.danbooruGeneralThreshold,
  StorageKeys.danbooruArtistThreshold,
  StorageKeys.danbooruCharacterThreshold,
  StorageKeys.danbooruCopyrightThreshold,
  StorageKeys.danbooruMetaThreshold,
  StorageKeys.cooccurrenceRefreshInterval,
  StorageKeys.workflowEnhanceLevel,
  StorageKeys.workflowEnhanceMaxScale,
  StorageKeys.workflowEnhanceShowIndividualSettings,
  StorageKeys.workflowEnhanceUpscaleFactor,
  StorageKeys.workflowEnhanceStrength,
  StorageKeys.workflowEnhanceNoise,
  StorageKeys.protectionMode,
  StorageKeys.protectionConfirmDangerousActions,
  StorageKeys.protectionWarnExternalImageSend,
  StorageKeys.protectionPreventOverwrite,
  StorageKeys.protectionWarnHighAnlasCost,
  StorageKeys.protectionHighAnlasCostThreshold,
  StorageKeys.protectionLimitGenerationInterval,
  StorageKeys.protectionGenerationIntervalSeconds,
};

const portablePromptSettingKeys = <String>{
  StorageKeys.fixedTagsData,
  StorageKeys.fixedTagLinksData,
  StorageKeys.fixedTagCategoriesData,
};

const portableOnlineGallerySettingKeys = <String>{
  StorageKeys.onlineGalleryOutputFilterTags,
  StorageKeys.onlineGalleryPromptTagCategories,
  StorageKeys.quickTagCloudContentAccessV1,
  StorageKeys.quickTagCloudBrowsingFiltersV1,
};

class GalleryBlacklistCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  GalleryBlacklistCloudSyncAdapter(this._repository);
  final OnlineGalleryBlacklistRepository _repository;

  @override
  String get id => 'gallery-blacklist';
  @override
  Set<String> get allowedKinds => const {'rules'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    final store = _repository.load();
    yield PortableSyncRecord(
      adapterId: id,
      id: 'unified',
      kind: 'rules',
      data: {
        'revision': store.revision,
        'desiredTags': store.desiredTags.toList()..sort(),
        'tombstones': store.tombstones.toList()..sort(),
      },
    );
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) {
      if (record.id != 'unified' ||
          record.resource != null ||
          record.data.isNotEmpty) {
        throw const CloudSyncPreflightException(
          'Invalid unified blacklist tombstone',
        );
      }
      return;
    }
    bool strings(Object? value) =>
        value is List && value.every((item) => item is String);
    if (record.id != 'unified' ||
        record.data['revision'] is! int ||
        !strings(record.data['desiredTags']) ||
        !strings(record.data['tombstones'])) {
      throw const CloudSyncPreflightException('Invalid unified blacklist');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      final current = _repository.load();
      await _repository.save(
        current.copyWith(
          revision: record.deleted ? 0 : record.data['revision']! as int,
          desiredTags: record.deleted
              ? const <String>{}
              : Set.unmodifiable(
                  (record.data['desiredTags']! as List).cast<String>(),
                ),
          tombstones: record.deleted
              ? const <String>{}
              : Set.unmodifiable(
                  (record.data['tombstones']! as List).cast<String>(),
                ),
        ),
      );
    }
  }
}

class SettingsCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  SettingsCloudSyncAdapter(
    this._storage, {
    this.includeAppSettings = true,
    this.includePromptsAndTags = true,
    this.includeOnlineGallerySettings = true,
  });
  final LocalStorageService _storage;
  final bool includeAppSettings;
  final bool includePromptsAndTags;
  final bool includeOnlineGallerySettings;

  @override
  String get id => 'portable-settings';
  @override
  Set<String> get allowedKinds => const {'setting'};

  Set<String> get keys => {
    ...portableSettingKeys,
    ...portablePromptSettingKeys,
    ...portableOnlineGallerySettingKeys,
  };

  Set<String> get exportedKeys => {
    if (includeAppSettings) ...portableSettingKeys,
    if (includePromptsAndTags) ...portablePromptSettingKeys,
    if (includeOnlineGallerySettings) ...portableOnlineGallerySettingKeys,
  };

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    for (final key in exportedKeys) {
      final value = _storage.getSetting<Object?>(key);
      if (value == null) continue;
      final portable = jsonDecode(jsonEncode(value)) as Object?;
      yield PortableSyncRecord(
        adapterId: id,
        id: key,
        kind: 'setting',
        data: {'key': key, 'value': portable},
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) return;
    final key = record.data['key'];
    if (key is! String || key != record.id || !keys.contains(key)) {
      throw const CloudSyncPreflightException('Setting is not portable');
    }
    jsonEncode(record.data['value']);
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      // One adapter owns three independently selectable groups. Records from
      // an older remote snapshot must not bypass the current user's choice.
      if (!exportedKeys.contains(record.id)) continue;
      if (record.deleted) {
        if (!keys.contains(record.id)) {
          throw const CloudSyncPreflightException('Setting is not portable');
        }
        await _storage.deleteSetting(record.id);
      } else {
        await _storage.setSetting<Object?>(record.id, record.data['value']);
      }
    }
  }
}

final RegExp _portableUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

bool _isPortableModelId(String key) => _portableUuid.hasMatch(key);

bool _isRandomPresetKey(String key) =>
    key == 'selected_preset_id' || key == 'default' || _isPortableModelId(key);

Map<String, dynamic> _portableMap(Object? value) {
  if (value is! Map) {
    throw const CloudSyncPreflightException('Expected a JSON object');
  }
  return value.map((key, item) {
    if (key is! String) {
      throw const CloudSyncPreflightException(
        'Portable object keys must be strings',
      );
    }
    return MapEntry(key, item);
  });
}

String? _modelIdOf(String _, Object? value) =>
    _portableMap(value)['id'] as String?;

Object? _normalizeTagFavorite(String _, Object? value) =>
    TagFavorite.fromJson(_portableMap(value)).toJson();

Object? _normalizeTagTemplate(String _, Object? value) =>
    TagTemplate.fromJson(_portableMap(value)).toJson();

Object? _normalizeRandomPreset(String key, Object? value) {
  if (key == 'selected_preset_id') {
    if (value is! String || !_isRandomPresetKey(value)) {
      throw const CloudSyncPreflightException(
        'Selected random preset ID is invalid',
      );
    }
    return value;
  }
  final preset = RandomPreset.fromJson(_portableMap(value));
  if (preset.id != key) {
    throw const CloudSyncPreflightException(
      'Random preset identity differs from its key',
    );
  }
  return preset.toJson();
}

Object? _normalizeShortcutConfig(String _, Object? value) {
  final config = ShortcutConfig.fromJson(_portableMap(value));
  for (final entry in config.bindings.entries) {
    if (entry.key != entry.value.id) {
      throw const CloudSyncPreflightException(
        'Shortcut binding identity differs from its key',
      );
    }
  }
  return config.toJson();
}

class PromptAssistantProfileCloudSyncAdapter
    extends ValidatingCloudSyncDataAdapter {
  PromptAssistantProfileCloudSyncAdapter(this._storage);
  final LocalStorageService _storage;

  @override
  String get id => 'prompt-assistant-profile';
  @override
  Set<String> get allowedKinds => const {'profile'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    final raw = _storage.getSetting<String>(
      StorageKeys.promptAssistantConfigJson,
    );
    if (raw == null || raw.isEmpty) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    yield PortableSyncRecord(
      adapterId: id,
      id: 'user-rules',
      kind: 'profile',
      data: {'rules': json['rules'] is List ? json['rules'] : const []},
    );
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) {
      if (record.id != 'user-rules' ||
          record.resource != null ||
          record.data.isNotEmpty) {
        throw const CloudSyncPreflightException(
          'Invalid Prompt Assistant profile tombstone',
        );
      }
      return;
    }
    if (record.id != 'user-rules' || record.data['rules'] is! List) {
      throw const CloudSyncPreflightException(
        'Invalid Prompt Assistant profile',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    final currentRaw = _storage.getSetting<String>(
      StorageKeys.promptAssistantConfigJson,
    );
    final current = currentRaw == null || currentRaw.isEmpty
        ? <String, dynamic>{'schemaVersion': 2}
        : jsonDecode(currentRaw) as Map<String, dynamic>;
    for (final record in records) {
      current['rules'] = record.deleted ? const [] : record.data['rules'];
    }
    // providers/baseUrl/models/routing and secure keys remain target-local.
    await _storage.setSetting(
      StorageKeys.promptAssistantConfigJson,
      jsonEncode(current),
    );
  }
}
