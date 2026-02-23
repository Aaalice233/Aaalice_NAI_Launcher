# Danbooru Tag Cache Investigation Report

## Executive Summary

**Issue**: The Danbooru tag caching mechanism is completely ineffective - the cache is never hit during app warmup, causing redundant API calls on every startup.

**Root Cause**: A race condition between metadata loading (`_loadMeta()`) and cache validation (`shouldRefresh()`). The constructor initiates metadata loading asynchronously with `unawaited()`, but `initialize()` may be called before `_loadMeta()` completes, causing `shouldRefresh()` to see `_lastUpdate` as null and incorrectly return `true` (needs refresh).

**Impact**: Every app startup triggers unnecessary Danbooru API calls, increasing startup time and network usage regardless of whether valid cached data exists.

---

## Detailed Root Cause Analysis

### 1. Race Condition in Service Initialization

**Location**: `lib/core/services/danbooru_tags_lazy_service.dart`

**Problematic Code** (lines 49-51):
```dart
DanbooruTagsLazyService(this._unifiedDb, this._dio) {
  unawaited(_loadMeta());  // Fire-and-forget async call
}
```

The constructor uses `unawaited()` to start loading metadata from disk asynchronously. This is intended to be a non-blocking optimization, but it creates a race condition.

**Race Condition Flow**:
1. Service is instantiated → constructor calls `unawaited(_loadMeta())`
2. `_loadMeta()` starts async file I/O to load `danbooru_tags_meta.json`
3. Before file I/O completes, `initialize()` is called by `WarmupNotifier`
4. `initialize()` calls `shouldRefresh()` at line 120
5. `shouldRefresh()` sees `_lastUpdate == null` because `_loadMeta()` hasn't finished
6. `shouldRefresh()` calls `_loadMeta()` again (line 417), but this is too late - the decision path is already compromised
7. Cache is incorrectly considered stale → triggers API download

### 2. Flawed shouldRefresh() Implementation

**Location**: `lib/core/services/danbooru_tags_lazy_service.dart`, lines 415-425

**Problematic Code**:
```dart
@override
Future<bool> shouldRefresh() async {
  if (_lastUpdate == null) {
    await _loadMeta();  // Attempt to load, but may still return null if file doesn't exist
  }

  final prefs = await SharedPreferences.getInstance();
  final days = prefs.getInt(StorageKeys.danbooruTagsRefreshIntervalDays);
  final interval = AutoRefreshInterval.fromDays(days ?? 30);

  return interval.shouldRefresh(_lastUpdate);  // Returns true if _lastUpdate is null
}
```

**Issues**:
1. Even when `shouldRefresh()` calls `_loadMeta()` internally, there's no guarantee the metadata file exists
2. `AutoRefreshInterval.shouldRefresh(null)` returns `true` (see line 30 in data_source_cache_meta.dart)
3. The logic assumes that if `_lastUpdate` is null after loading, the cache doesn't exist or is invalid

### 3. Warmup Flow Bypasses Cache Metadata Check

**Location**: `lib/presentation/providers/warmup_provider.dart`, lines 438-498

**Problematic Code** (lines 455-485):
```dart
// 检查数据库中是否已有数据
final tagCount = await service.getTagCount();

final isPrebuiltDatabase = tagCount >= 30000;

if (isPrebuiltDatabase) {
  // 预构建数据库：只需加载热数据
  await service.initialize();
} else {
  // 需要下载：只下载普通标签
  await service.refreshGeneralOnly();
}
```

**Issues**:
1. The warmup flow checks `tagCount >= 30000` to detect prebuilt databases, but this is a different check than cache validity
2. When `tagCount < 30000` but > 0, it calls `refreshGeneralOnly()` without checking if the cache is actually stale
3. The `initialize()` method itself has the race condition that triggers unnecessary downloads

### 4. Cache State Validation Gap

There is no validation that the database tag count matches the metadata `totalTags` field. This could lead to:
- Metadata saying cache is valid but database is empty/corrupted
- Partial downloads not being detected
- Inconsistent state between metadata and actual data

---

## Evidence from Code Review

### AutoRefreshInterval Logic

**Location**: `lib/data/models/cache/data_source_cache_meta.dart`, lines 28-34

```dart
bool shouldRefresh(DateTime? lastUpdate) {
  if (this == AutoRefreshInterval.never) return false;
  if (lastUpdate == null) return true;  // ← NULL = REFRESH

  final daysSinceUpdate = DateTime.now().difference(lastUpdate).inDays;
  return daysSinceUpdate >= days;
}
```

**Finding**: When `lastUpdate` is null, `shouldRefresh()` returns `true`, triggering a download.

### Metadata Loading Implementation

**Location**: `lib/core/services/danbooru_tags_lazy_service.dart`, lines 734-754

```dart
Future<void> _loadMeta() async {
  try {
    final cacheDir = await _getCacheDirectory();
    final metaFile = File('${cacheDir.path}/$_metaFileName');

    if (await metaFile.exists()) {
      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _lastUpdate = DateTime.parse(json['lastUpdate'] as String);
      _currentThreshold = json['hotThreshold'] as int? ?? 1000;
    }
    // ...
  } catch (e) {
    AppLogger.w('Failed to load Danbooru tags meta: $e', 'DanbooruTagsLazy');
  }
}
```

**Finding**: If the metadata file doesn't exist, `_lastUpdate` remains null without any error being thrown.

---

## Reproduction Scenario

### First Startup (Expected: Download)
1. App starts, no metadata file exists
2. `DanbooruTagsLazyService` instantiated → `unawaited(_loadMeta())` called
3. `initialize()` called immediately
4. `_loadMeta()` still in progress or completed with no file → `_lastUpdate = null`
5. `shouldRefresh()` returns `true`
6. Tags are downloaded from API
7. `_saveMeta()` writes metadata file with `lastUpdate` timestamp

### Second Startup (Bug: Should use cache, but downloads again)
1. App starts, metadata file exists with valid timestamp
2. `DanbooruTagsLazyService` instantiated → `unawaited(_loadMeta())` called
3. `initialize()` called **before** `_loadMeta()` completes (race condition)
4. `_lastUpdate` is still null
5. `shouldRefresh()` returns `true`
6. Tags are **unnecessarily** downloaded from API
7. `_saveMeta()` overwrites metadata file

---

## Fix Strategy

### Phase 1: Fix Race Condition
Ensure `_loadMeta()` completes before any cache validation logic runs.

**Options**:
1. **Synchronous loading**: Make metadata loading synchronous (may block startup)
2. **Lazy loading with await**: Ensure `initialize()` awaits metadata loading if not already loaded
3. **Completer pattern**: Use a `Completer` to coordinate between constructor and `initialize()`

**Recommended Approach**: Option 2 - Add explicit await in `initialize()`:
```dart
Future<void> initialize() async {
  // Ensure metadata is loaded before making cache decisions
  if (_lastUpdate == null) {
    await _loadMeta();  // Wait for metadata to load
  }
  // ... rest of initialization
}
```

### Phase 2: Verify Metadata Persistence
Add diagnostic logging to confirm `_saveMeta()` writes correct data:
- Log metadata file path
- Log values being written
- Verify file is readable after write

### Phase 3: Add Cache State Validation
Add validation to ensure database state matches metadata:
```dart
Future<bool> _isCacheValid() async {
  final tagCount = await getTagCount();
  // Metadata should exist and count should be > 0
  return _lastUpdate != null && tagCount > 0;
}
```

---

## Files Requiring Modification

| File | Changes Required |
|------|------------------|
| `lib/core/services/danbooru_tags_lazy_service.dart` | Fix race condition in `initialize()`, add `_loadMeta()` await; verify `_saveMeta()` persistence |
| `lib/presentation/providers/warmup_provider.dart` | Add cache state validation before deciding download vs cache |

---

## Verification Criteria

After fix implementation, verify:

1. **First startup**: Tags are downloaded, metadata file is created
2. **Second startup (within refresh interval)**: No API calls for general tags, cache is used
3. **After refresh interval expires**: Tags are refreshed from API
4. **Empty database with valid metadata**: Triggers re-download (corruption recovery)
5. **Prebuilt database (tagCount >= 30000)**: Skips download, loads hot data only

---

## Related Code References

- `lib/data/models/cache/data_source_cache_meta.dart` - AutoRefreshInterval logic
- `lib/core/services/unified_tag_database.dart` - Database operations
- `lib/core/constants/storage_keys.dart` - Storage key definitions

---

*Investigation completed: 2026-02-16*
