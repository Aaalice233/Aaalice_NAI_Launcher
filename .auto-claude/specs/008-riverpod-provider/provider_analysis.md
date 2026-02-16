# Presentation Layer KeepAlive Provider Analysis

## Overview

This document provides a comprehensive analysis of all `keepAlive: true` providers in the presentation layer (`lib/presentation/providers/`). These providers use the `@Riverpod(keepAlive: true)` annotation to maintain their state across widget tree rebuilds.

**Total Count: 42 keepAlive Providers**

---

## Provider Categories

### 1. Authentication & Account Management (2)

Providers managing user authentication state and account information.

| Provider | File | Purpose |
|----------|------|---------|
| `AuthNotifier` | `auth_provider.dart` | Global authentication state, token management, login/logout |
| `AccountManagerNotifier` | `account_manager_provider.dart` | Multi-account management, account switching |

**Key Characteristics:**
- Both use secure storage for sensitive data
- `AuthNotifier` handles auto-login on app startup
- `AccountManagerNotifier` manages multiple account credentials

---

### 2. Image Generation Core (3)

Core providers for the image generation functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `ImageGenerationNotifier` | `image_generation_provider.dart` | Main image generation state, API calls, progress tracking |
| `GenerationParamsNotifier` | `generation/generation_params_notifier.dart` | Generation parameters (prompt, model, settings) |
| `ReferencePanelNotifier` | `generation/reference_panel_notifier.dart` | Vibe Transfer reference panel UI state |

**Key Characteristics:**
- `ImageGenerationNotifier` is the core orchestrator for generation
- `GenerationParamsNotifier` manages all generation parameters
- `ReferencePanelNotifier` handles Vibe Transfer UI interactions

---

### 3. Generation Settings (9)

Individual setting notifiers for generation behavior customization.

| Provider | File | Purpose |
|----------|------|---------|
| `AddQualityTagsNotifier` | `generation/generation_settings_notifiers.dart` | Toggle quality tags auto-add |
| `AutocompleteNotifier` | `generation/generation_settings_notifiers.dart` | Toggle tag autocomplete |
| `AutoFormatPromptNotifier` | `generation/generation_settings_notifiers.dart` | Toggle prompt auto-formatting |
| `HighlightEmphasisNotifier` | `generation/generation_settings_notifiers.dart` | Toggle emphasis highlighting |
| `SdSyntaxAutoConvertNotifier` | `generation/generation_settings_notifiers.dart` | Toggle SD syntax auto-conversion |
| `EnableCooccurrenceRecommendationNotifier` | `generation/generation_settings_notifiers.dart` | Toggle co-occurrence recommendations |
| `UcPresetTypeNotifier` | `generation/generation_settings_notifiers.dart` | Negative prompt preset selection |
| `RandomPromptModeNotifier` | `generation/generation_settings_notifiers.dart` | Random prompt generation mode |
| `BatchImageCountNotifier` | `generation/generation_settings_notifiers.dart` | Batch generation image count (1-4) |

**Key Characteristics:**
- All persist settings to LocalStorage
- Simple boolean/value notifiers with single responsibility
- Follow consistent naming pattern

---

### 4. Queue & Replication System (3)

Providers for batch/replication queue management.

| Provider | File | Purpose |
|----------|------|---------|
| `ReplicationQueueNotifier` | `replication_queue_provider.dart` | Task queue management (add, remove, reorder) |
| `QueueExecutionNotifier` | `queue_execution_provider.dart` | Queue auto-execution engine |
| `BackgroundTaskNotifier` | `background_task_provider.dart` | Background task management |

**Key Characteristics:**
- `ReplicationQueueNotifier` manages the task list
- `QueueExecutionNotifier` orchestrates automatic execution
- `BackgroundTaskNotifier` handles async background operations

---

### 5. Gallery Management (2)

Providers for local and online gallery functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `LocalGalleryNotifier` | `local_gallery_provider.dart` | Local image gallery with SQLite backend |
| `OnlineGalleryProvider` | `online_gallery_provider.dart` | Danbooru/Gelbooru integration |

**Key Characteristics:**
- `LocalGalleryNotifier` uses file watcher for auto-refresh
- `OnlineGalleryProvider` is a FutureProvider for remote data

---

### 6. Tag & Prompt Management (7)

Providers for tag libraries, prompt configs, and related functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `TagLibraryNotifier` | `tag_library_provider.dart` | Built-in tag library sync and management |
| `TagLibraryPageNotifier` | `tag_library_page_provider.dart` | User custom tag library (categories, entries) |
| `TagGroupSyncNotifier` | `tag_group_sync_provider.dart` | Tag Group synchronization from Danbooru |
| `FixedTagsNotifier` | `fixed_tags_provider.dart` | Fixed tags (auto-appended to prompts) |
| `CharacterPromptNotifier` | `character_prompt_provider.dart` | Multi-character prompt configurations |
| `RandomPromptConfigNotifier` | `prompt_config_provider.dart` | Random prompt template configuration |
| `PendingPromptNotifier` | `pending_prompt_provider.dart` | Pending prompt for cross-page communication |

**Key Characteristics:**
- `TagLibraryNotifier` and `TagLibraryPageNotifier` serve different purposes
- `FixedTagsNotifier` manages tags auto-added to all prompts
- `CharacterPromptNotifier` supports multiple character configurations

---

### 7. Preset Management (3)

Providers for quality and negative prompt presets.

| Provider | File | Purpose |
|----------|------|---------|
| `QualityPresetNotifier` | `quality_preset_provider.dart` | Quality tag presets management |
| `UcPresetNotifier` | `uc_preset_provider.dart` | Negative prompt (UC) presets |
| `RandomPresetNotifier` | `random_preset_provider.dart` | Random generation presets |

**Key Characteristics:**
- All support custom user-defined entries
- Persist to local storage
- Used during prompt assembly

---

### 8. Vibe Transfer System (1)

Provider for Vibe Transfer (style reference) functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `VibeLibraryNotifier` | `vibe_library_provider.dart` | Vibe image library management |

**Key Characteristics:**
- Manages reference image library
- Handles image caching and metadata

---

### 9. Data Source & Cache (1)

Provider for external data source caching.

| Provider | File | Purpose |
|----------|------|---------|
| `DanbooruTagCacheNotifier` | `data_source_cache_provider.dart` | Danbooru tag cache management |

**Key Characteristics:**
- Caches Danbooru tags for offline use
- Manages cache expiration

---

### 10. Collection System (2)

Providers for image collections.

| Provider | File | Purpose |
|----------|------|---------|
| `CollectionRepository` | `collection_provider.dart` | Collection data repository |
| `CollectionNotifier` | `collection_provider.dart` | Collection state management |

**Key Characteristics:**
- Repository pattern for data access
- Notifier for UI state

---

### 11. UI State & Settings (7)

Providers for UI state, settings, and user preferences.

| Provider | File | Purpose |
|----------|------|---------|
| `FloatingButtonPositionNotifier` | `floating_button_position_provider.dart` | Floating action button position |
| `NotificationSettingsNotifier` | `notification_settings_provider.dart` | Sound/notification settings |
| `ImageSaveSettingsNotifier` | `image_save_settings_provider.dart` | Image save path/settings |
| `ShortcutStorage` | `shortcuts_provider.dart` | Keyboard shortcuts storage |
| `ShortcutConfigNotifier` | `shortcuts_provider.dart` | Keyboard shortcuts configuration |
| `RandomModeNotifier` | `random_mode_provider.dart` | Random generation mode selection |
| `BulkOperationNotifier` | `bulk_operation_provider.dart` | Bulk operations with undo/redo |

**Key Characteristics:**
- UI-specific state that needs to persist
- User preference storage
- Some support undo/redo operations

---

## Summary by Category

| Category | Count | Providers |
|----------|-------|-----------|
| Authentication & Account | 2 | AuthNotifier, AccountManagerNotifier |
| Image Generation Core | 3 | ImageGenerationNotifier, GenerationParamsNotifier, ReferencePanelNotifier |
| Generation Settings | 9 | AddQualityTagsNotifier, AutocompleteNotifier, AutoFormatPromptNotifier, HighlightEmphasisNotifier, SdSyntaxAutoConvertNotifier, EnableCooccurrenceRecommendationNotifier, UcPresetTypeNotifier, RandomPromptModeNotifier, BatchImageCountNotifier |
| Queue & Replication | 3 | ReplicationQueueNotifier, QueueExecutionNotifier, BackgroundTaskNotifier |
| Gallery Management | 2 | LocalGalleryNotifier, OnlineGalleryProvider |
| Tag & Prompt Management | 7 | TagLibraryNotifier, TagLibraryPageNotifier, TagGroupSyncNotifier, FixedTagsNotifier, CharacterPromptNotifier, RandomPromptConfigNotifier, PendingPromptNotifier |
| Preset Management | 3 | QualityPresetNotifier, UcPresetNotifier, RandomPresetNotifier |
| Vibe Transfer | 1 | VibeLibraryNotifier |
| Data Source & Cache | 1 | DanbooruTagCacheNotifier |
| Collection System | 2 | CollectionRepository, CollectionNotifier |
| UI State & Settings | 7 | FloatingButtonPositionNotifier, NotificationSettingsNotifier, ImageSaveSettingsNotifier, ShortcutStorage, ShortcutConfigNotifier, RandomModeNotifier, BulkOperationNotifier |
| **Total** | **42** | |

---

## Pattern Analysis

### Common Patterns

1. **State Classes**: Most providers define a custom state class (e.g., `AuthState`, `TagLibraryState`)
2. **Persistence**: Majority auto-persist to LocalStorage or SecureStorage
3. **Error Handling**: Standard pattern of `error` field in state with `clearError` support
4. **Loading States**: Common `isLoading` boolean for async operations
5. **copyWith Pattern**: All state classes use immutable pattern with `copyWith`

### File Organization

- **Single Provider Files**: Most files contain one main notifier
- **Grouped Providers**: `generation_settings_notifiers.dart` groups related simple notifiers
- **Repository + Notifier**: `collection_provider.dart` pairs repository with notifier

### Dependencies

- Services are typically read via `ref.read()` in methods
- Other providers are watched via `ref.watch()` in `build()` method
- Common dependency: `localStorageServiceProvider`

---

## Migration Considerations

When migrating to the new architecture:

1. **Authentication providers** should maintain their keepAlive status - critical for app state
2. **Generation core** providers are essential keepAlive candidates
3. **Setting notifiers** could potentially use regular providers if persistence is handled elsewhere
4. **Gallery providers** benefit from keepAlive for performance
5. **UI-only state** should be evaluated case-by-case

---

# Data & Core Layer KeepAlive Provider Analysis

## Overview

This section documents all `keepAlive: true` providers in the data layer (`lib/data/`) and core layer (`lib/core/`). These providers form the infrastructure and service foundation of the application.

**Total Count: 34 keepAlive Providers**
- Data Layer: 24 providers
- Core Layer: 10 providers

---

## Data Layer Providers

### 1. Authentication & Token Management (3)

Providers managing authentication API services and token refresh functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `DanbooruAuth` | `services/danbooru_auth_service.dart` | Danbooru authentication state and credentials management |
| `TokenRefreshService` | `services/token_refresh_service.dart` | Automatic JWT token refresh when expired |
| `naiAuthApiService` | `datasources/remote/nai_auth_api_service.dart` | NAI authentication API service |

**Key Characteristics:**
- `DanbooruAuth` manages login/logout with 24-hour verification cache
- `TokenRefreshService` prevents concurrent refresh with `_isRefreshing` flag
- API service providers use `ref.watch(dioClientProvider)` for proper proxy configuration

---

### 2. NAI API Services (2)

Providers for NovelAI API service instances.

| Provider | File | Purpose |
|----------|------|---------|
| `naiUserInfoApiService` | `datasources/remote/nai_user_info_api_service.dart` | NAI user info and subscription API |
| `naiTagSuggestionApiService` | `datasources/remote/nai_tag_suggestion_api_service.dart` | NAI tag suggestion API |

**Key Characteristics:**
- All services use `dioClientProvider` for HTTP client with auth interceptors
- Tag suggestion uses separate Dio instance with shorter timeouts (5s)

---

### 3. Danbooru API & Cache Services (5)

Providers for Danbooru integration including API services and caching.

| Provider | File | Purpose |
|----------|------|---------|
| `danbooruApiService` | `datasources/remote/danbooru_api_service.dart` | Danbooru REST API client |
| `DanbooruTagGroupService` | `datasources/remote/danbooru_tag_group_service.dart` | Tag group synchronization from Danbooru |
| `DanbooruPoolService` | `datasources/remote/danbooru_pool_service.dart` | Pool/favorites synchronization |
| `TagGroupCacheService` | `datasources/local/tag_group_cache_service.dart` | Local cache for tag groups |
| `PoolCacheService` | `datasources/local/pool_cache_service.dart` | Local cache for pools |

**Key Characteristics:**
- API services depend on `danbooruApiServiceProvider`
- Cache services provide memory + persistent storage caching
- All cache services use `Map<int, dynamic>` for memory cache with size limits

---

### 4. Tag Data Sources (2)

Providers for NAI tag data loading and management.

| Provider | File | Purpose |
|----------|------|---------|
| `naiTagsDataSource` | `datasources/local/nai_tags_data_source.dart` | NAI built-in tags data source |
| `naiTagsData` | `datasources/local/nai_tags_data_source.dart` | Async provider for loaded tag data |

**Key Characteristics:**
- `naiTagsDataSource` is a simple service provider
- `naiTagsData` is a FutureProvider that loads JSON data
- Data is cached in memory after first load

---

### 5. Tag Library Services (4)

Providers for tag library management and related functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `tagLibraryService` | `services/tag_library_service.dart` | Tag library CRUD and sync operations |
| `TagsStorageService` | `services/tags_storage_service.dart` | User-defined tags storage |
| `tagTranslationService` | `services/tag_translation_service.dart` | Tag translation wrapper |
| `AliasResolverService` | `services/alias_resolver_service.dart` | Alias reference resolution |

**Key Characteristics:**
- `TagLibraryService` uses Hive for persistence with `_ensureInit()` pattern
- `tagTranslationService` wraps `UnifiedTranslationService` for backward compatibility
- `AliasResolverService` depends on `tagLibraryPageNotifierProvider`

---

### 6. Statistics & Analytics (3)

Providers for usage statistics and analytics.

| Provider | File | Purpose |
|----------|------|---------|
| `AnlasStatisticsService` | `services/anlas_statistics_service.dart` | Daily Anlas consumption tracking |
| `StatisticsService` | `services/statistics_service.dart` | Generation statistics aggregation |
| `StatisticsCacheService` | `services/statistics_cache_service.dart` | Statistics data caching |

**Key Characteristics:**
- `AnlasStatisticsService` keeps 90 days of history in SharedPreferences
- All statistics services use JSON serialization for persistence
- Cached statistics improve dashboard loading performance

---

### 7. Storage Services (3)

Providers for specialized storage functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `FavoritesStorageService` | `services/favorites_storage_service.dart` | User favorites persistence |
| `VibeLibraryStorageService` | `services/vibe_library_storage_service.dart` | Vibe Transfer image library |
| `SequentialStateService` | `services/sequential_state_service.dart` | Sequential generation state |

**Key Characteristics:**
- `VibeLibraryStorageService` uses `VibeFileStorageService` for file operations
- `SequentialStateService` maintains counter state across app restarts

---

### 8. Prompt Generation (2)

Providers for random prompt generation functionality.

| Provider | File | Purpose |
|----------|------|---------|
| `RandomPromptGenerator` | `services/random_prompt_generator.dart` | Random prompt generation engine |
| `WordlistService` | `services/wordlist_service.dart` | Word list storage for generation |

**Key Characteristics:**
- `RandomPromptGenerator` depends on multiple services (library, pool, wordlist)
- Complex dependency injection pattern with 5+ dependencies

---

## Core Layer Providers

### 1. Network Layer (1)

| Provider | File | Purpose |
|----------|------|---------|
| `dioClient` | `network/dio_client.dart` | Global Dio HTTP client with proxy support |

**Key Characteristics:**
- Watches `currentProxyAddressProvider` for proxy configuration changes
- Configures HTTP/2 or HTTP/1.1 based on proxy settings
- Adds `AuthInterceptor` for automatic token injection

---

### 2. Database & Storage (3)

| Provider | File | Purpose |
|----------|------|---------|
| `unifiedTagDatabase` | `services/unified_tag_database.dart` | SQLite database for tags and translations |
| `secureStorageService` | `storage/secure_storage_service.dart` | Encrypted secure storage |
| `danbooruTagsLazyService` | `services/danbooru_tags_lazy_service.dart` | Lazy-loading Danbooru tag service |

**Key Characteristics:**
- `UnifiedTagDatabase` provides SQLite backend for tag operations
- `SecureStorageService` handles sensitive data (tokens, credentials)
- `DanbooruTagsLazyService` implements `LazyDataSourceService` interface

---

### 3. Tag Intelligence Services (3)

| Provider | File | Purpose |
|----------|------|---------|
| `cooccurrenceService` | `services/cooccurrence_service.dart` | Tag co-occurrence analysis |
| `smartTagRecommendationService` | `services/smart_tag_recommendation_service.dart` | Smart tag recommendations |
| `tagCountingService` | `services/tag_counting_service.dart` | Tag frequency counting |

**Key Characteristics:**
- `CooccurrenceService` analyzes tag relationships from Danbooru data
- `SmartTagRecommendationService` combines co-occurrence with lazy tag data
- All use `ref.read()` for service dependencies

---

### 4. Translation Services (2)

| Provider | File | Purpose |
|----------|------|---------|
| `unifiedTranslationService` | `services/translation/translation_providers.dart` | Unified translation service |
| `translationInitProgress` | `services/translation/translation_providers.dart` | Translation loading progress stream |

**Key Characteristics:**
- `unifiedTranslationService` is a FutureProvider that initializes on startup
- Merges multiple data sources: NAI, e621, custom translations

---

### 5. App Lifecycle (1)

| Provider | File | Purpose |
|----------|------|---------|
| `firstLaunchDetector` | `utils/first_launch_detector.dart` | Detects app first launch for onboarding |

**Key Characteristics:**
- Depends on `danbooruTagsLazyServiceProvider` for initial data sync
- Determines if user needs to go through first-time setup

---

## Summary by Category

### Data Layer (24 providers)

| Category | Count | Providers |
|----------|-------|-----------|
| Authentication & Token | 3 | DanbooruAuth, TokenRefreshService, naiAuthApiService |
| NAI API Services | 2 | naiUserInfoApiService, naiTagSuggestionApiService |
| Danbooru API & Cache | 5 | danbooruApiService, DanbooruTagGroupService, DanbooruPoolService, TagGroupCacheService, PoolCacheService |
| Tag Data Sources | 2 | naiTagsDataSource, naiTagsData |
| Tag Library Services | 4 | tagLibraryService, TagsStorageService, tagTranslationService, AliasResolverService |
| Statistics & Analytics | 3 | AnlasStatisticsService, StatisticsService, StatisticsCacheService |
| Storage Services | 3 | FavoritesStorageService, VibeLibraryStorageService, SequentialStateService |
| Prompt Generation | 2 | RandomPromptGenerator, WordlistService |

### Core Layer (10 providers)

| Category | Count | Providers |
|----------|-------|-----------|
| Network Layer | 1 | dioClient |
| Database & Storage | 3 | unifiedTagDatabase, secureStorageService, danbooruTagsLazyService |
| Tag Intelligence | 3 | cooccurrenceService, smartTagRecommendationService, tagCountingService |
| Translation Services | 2 | unifiedTranslationService, translationInitProgress |
| App Lifecycle | 1 | firstLaunchDetector |

---

## Combined Summary

| Layer | Provider Count |
|-------|----------------|
| Presentation | 42 |
| Data | 24 |
| Core | 10 |
| **Total** | **76** |

---

## Notes

- All providers use `@Riverpod(keepAlive: true)` (capital R) annotation
- Generated files follow the `.g.dart` pattern
- Each provider has a corresponding `xxxProvider` global variable generated by Riverpod
- Controllers use the naming convention `XxxNotifier extends _$XxxNotifier`
- Service providers (function-style) follow naming convention `xxxService` or `xxxApiService`
