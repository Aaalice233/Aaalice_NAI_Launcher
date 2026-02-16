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

## Notes

- All providers use `@Riverpod(keepAlive: true)` (capital R) annotation
- Generated files follow the `.g.dart` pattern
- Each provider has a corresponding `xxxProvider` global variable generated by Riverpod
- Controllers use the naming convention `XxxNotifier extends _$XxxNotifier`
