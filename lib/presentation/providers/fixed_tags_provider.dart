import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/tag_library/tag_library_entry.dart';
import 'tag_library_page_provider.dart';

part 'fixed_tags_provider.g.dart';

/// 固定词状态
class FixedTagsState {
  final List<FixedTagEntry> entries;
  final bool isLoading;
  final String? error;

  const FixedTagsState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  FixedTagsState copyWith({
    List<FixedTagEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return FixedTagsState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取启用的条目
  List<FixedTagEntry> get enabledEntries =>
      entries.where((e) => e.enabled).toList();

  /// 获取启用的条目数量
  int get enabledCount => entries.where((e) => e.enabled).length;

  /// 获取禁用的条目数量
  int get disabledCount => entries.where((e) => !e.enabled).length;

  /// 获取启用的前缀条目
  List<FixedTagEntry> get enabledPrefixes => entries
      .where((e) => e.enabled && e.position == FixedTagPosition.prefix)
      .toList();

  /// 获取启用的后缀条目
  List<FixedTagEntry> get enabledSuffixes => entries
      .where((e) => e.enabled && e.position == FixedTagPosition.suffix)
      .toList();

  /// 应用固定词到提示词
  ///
  /// 将所有启用的固定词按位置应用到用户提示词
  String applyToPrompt(String userPrompt) {
    final enabledPrefixContents = enabledPrefixes
        .sortedByOrder()
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final enabledSuffixContents = enabledSuffixes
        .sortedByOrder()
        .map((e) => e.weightedContent)
        .where((c) => c.isNotEmpty)
        .toList();

    final parts = <String>[
      ...enabledPrefixContents,
      userPrompt,
      ...enabledSuffixContents,
    ].where((s) => s.isNotEmpty).toList();

    return parts.join(', ');
  }
}

/// 固定词 Provider
///
/// 管理固定词列表，支持增删改查、排序、状态切换
/// 自动持久化到 LocalStorage
@Riverpod(keepAlive: true)
class FixedTagsNotifier extends _$FixedTagsNotifier {
  /// 存储服务
  late LocalStorageService _storage;

  @override
  FixedTagsState build() {
    _storage = ref.watch(localStorageServiceProvider);

    // 直接返回加载的固定词列表
    return _loadEntries();
  }

  /// 从存储加载固定词列表
  FixedTagsState _loadEntries() {
    try {
      final json = _storage.getFixedTagsJson();
      if (json == null || json.isEmpty) {
        return const FixedTagsState(entries: []);
      }

      final List<dynamic> decoded = jsonDecode(json);
      final entries = decoded
          .map((e) => FixedTagEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // 按排序顺序排列
      final sortedEntries = entries.sortedByOrder();
      AppLogger.d('Loaded ${entries.length} fixed tags', 'FixedTagsProvider');
      return FixedTagsState(entries: sortedEntries);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load fixed tags: $e',
        e,
        stack,
        'FixedTagsProvider',
      );
      return FixedTagsState(
        entries: [],
        error: e.toString(),
      );
    }
  }

  /// 保存固定词列表到存储
  Future<void> _saveEntries() async {
    try {
      final json = jsonEncode(state.entries.map((e) => e.toJson()).toList());
      await _storage.setFixedTagsJson(json);
      AppLogger.d(
        'Saved ${state.entries.length} fixed tags',
        'FixedTagsProvider',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save fixed tags: $e',
        e,
        stack,
        'FixedTagsProvider',
      );
    }
  }

  /// 添加固定词
  /// 
  /// 【新增】sourceEntryId 参数：如果此固定词是从词库关联过来的，
  /// 传入词库条目的 ID，用于双向同步
  Future<FixedTagEntry> addEntry({
    required String name,
    required String content,
    double weight = 1.0,
    FixedTagPosition position = FixedTagPosition.prefix,
    bool enabled = true,
    String? sourceEntryId, // 【新增】来源词库条目ID
  }) async {
    final entry = FixedTagEntry.create(
      name: name,
      content: content,
      weight: weight,
      position: position,
      enabled: enabled,
      sourceEntryId: sourceEntryId, // 【新增】
      sortOrder: state.entries.length,
    );

    final newEntries = [...state.entries, entry];
    state = state.copyWith(entries: newEntries);
    await _saveEntries();

    AppLogger.d(
      'Added fixed tag: ${entry.displayName}',
      'FixedTagsProvider',
    );
    return entry;
  }

  /// 更新固定词
  ///
  /// 【新增】如果此固定词有关联的词库条目（sourceEntryId != null），
  /// 则反向同步更新词库条目（双向同步）
  Future<void> updateEntry(FixedTagEntry updatedEntry) async {
    AppLogger.d(
      'updateEntry called: id=${updatedEntry.id}, name=${updatedEntry.name}, sourceEntryId=${updatedEntry.sourceEntryId}',
      'FixedTagsProvider',
    );

    final index = state.entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index == -1) {
      AppLogger.w(
        'Fixed tag not found: ${updatedEntry.id}',
        'FixedTagsProvider',
      );
      return;
    }

    final newEntries = [...state.entries];
    newEntries[index] = updatedEntry;
    state = state.copyWith(entries: newEntries);
    await _saveEntries();

    AppLogger.d(
      'Updated fixed tag: ${updatedEntry.displayName}, checking for sync...',
      'FixedTagsProvider',
    );

    // 【新增】如果有关联的词库条目，反向同步更新
    if (updatedEntry.sourceEntryId != null) {
      AppLogger.d(
        'sourceEntryId is ${updatedEntry.sourceEntryId}, calling _syncToTagLibrary',
        'FixedTagsProvider',
      );
      await _syncToTagLibrary(updatedEntry);
    } else {
      AppLogger.d(
        'sourceEntryId is null, skipping sync to tag library',
        'FixedTagsProvider',
      );
    }
  }
  
  /// 【新增】从词库同步更新固定词
  /// 
  /// 当词库条目更新时，更新所有 sourceEntryId 匹配的固定词
  Future<void> syncFromTagLibrary(TagLibraryEntry tagEntry) async {
    final entriesToSync = state.entries
        .where((e) => e.sourceEntryId == tagEntry.id)
        .toList();
    
    if (entriesToSync.isEmpty) return;
    
    final newEntries = [...state.entries];
    for (final fixedTag in entriesToSync) {
      final index = newEntries.indexWhere((e) => e.id == fixedTag.id);
      if (index != -1) {
        // 只同步名称和内容，保留固定词特有的设置（权重、位置、启用状态）
        newEntries[index] = fixedTag.copyWith(
          name: tagEntry.name,
          content: tagEntry.content,
          updatedAt: DateTime.now(),
        );
      }
    }
    
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
    
    AppLogger.d(
      'Synced ${entriesToSync.length} fixed tags from tag library: ${tagEntry.name}',
      'FixedTagsProvider',
    );
  }
  
  /// 【新增】同步到词库（反向同步）
  /// 
  /// 当固定词更新时，同步更新关联的词库条目
  Future<void> _syncToTagLibrary(FixedTagEntry fixedTag) async {
    AppLogger.d(
      '_syncToTagLibrary called: fixedTag=${fixedTag.name}, sourceEntryId=${fixedTag.sourceEntryId}',
      'FixedTagsProvider',
    );

    if (fixedTag.sourceEntryId == null) {
      AppLogger.d(
        'Skipping sync: no sourceEntryId for fixed tag ${fixedTag.name}',
        'FixedTagsProvider',
      );
      return;
    }
    
    try {
      final tagLibraryNotifier = ref.read(tagLibraryPageNotifierProvider.notifier);
      final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);
      
      AppLogger.d(
        'Tag library state: ${tagLibraryState.entries.length} entries loaded',
        'FixedTagsProvider',
      );
      
      AppLogger.d(
        'Looking for tag library entry with id: ${fixedTag.sourceEntryId}',
        'FixedTagsProvider',
      );
      
      // 如果词库未加载（条目为空），尝试刷新
      if (tagLibraryState.entries.isEmpty) {
        AppLogger.w(
          'Tag library appears to be empty, attempting to refresh...',
          'FixedTagsProvider',
        );
        tagLibraryNotifier.refresh();
      }
      
      // 查找关联的词库条目
      final tagEntry = tagLibraryState.entries
          .cast<TagLibraryEntry?>()
          .firstWhere(
            (e) => e?.id == fixedTag.sourceEntryId,
            orElse: () => null,
          );
      
      if (tagEntry == null) {
        AppLogger.w(
          'Source tag library entry not found: ${fixedTag.sourceEntryId}',
          'FixedTagsProvider',
        );
        return;
      }
      
      AppLogger.d(
        'Found tag library entry: ${tagEntry.name}, updating...',
        'FixedTagsProvider',
      );
      
      // 更新词库条目（只更新名称和内容）
      final updatedTagEntry = tagEntry.copyWith(
        name: fixedTag.name,
        content: fixedTag.content,
        updatedAt: DateTime.now(),
      );
      
      // 使用 updateEntry 更新，但不触发再次同步（避免循环）
      await tagLibraryNotifier.updateEntryWithoutSync(updatedTagEntry);
      
      AppLogger.d(
        'Synced fixed tag to tag library: ${fixedTag.name}',
        'FixedTagsProvider',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to sync to tag library: $e', e, stack, 'FixedTagsProvider');
    }
  }

  /// 删除固定词
  Future<void> deleteEntry(String entryId) async {
    final newEntries =
        state.entries.where((e) => e.id != entryId).toList().reindex();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();

    AppLogger.d('Deleted fixed tag: $entryId', 'FixedTagsProvider');
  }

  /// 切换启用状态
  Future<void> toggleEnabled(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].toggleEnabled();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 切换位置
  Future<void> togglePosition(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].togglePosition();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 重新排序
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final entries = [...state.entries];
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);

    // 重新分配 sortOrder
    final reindexed = entries.reindex();
    state = state.copyWith(entries: reindexed);
    await _saveEntries();

    AppLogger.d(
      'Reordered fixed tags: $oldIndex -> $newIndex',
      'FixedTagsProvider',
    );
  }

  /// 应用固定词到提示词
  ///
  /// 将所有启用的固定词按位置应用到用户提示词
  String applyToPrompt(String userPrompt) {
    return state.applyToPrompt(userPrompt);
  }

  /// 根据ID获取条目
  FixedTagEntry? getEntry(String entryId) {
    return state.entries.cast<FixedTagEntry?>().firstWhere(
          (e) => e?.id == entryId,
          orElse: () => null,
        );
  }

  /// 清空所有固定词
  Future<void> clearAll() async {
    state = state.copyWith(entries: []);
    await _saveEntries();
    AppLogger.d('Cleared all fixed tags', 'FixedTagsProvider');
  }

  /// 重新加载
  void refresh() {
    state = _loadEntries();
  }

  /// 清除错误状态
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  /// 批量设置启用状态
  Future<void> setAllEnabled(bool enabled) async {
    final newEntries = state.entries
        .map(
          (e) => e.enabled == enabled
              ? e
              : e.copyWith(enabled: enabled, updatedAt: DateTime.now()),
        )
        .toList();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }
}

/// 便捷方法：获取当前固定词列表
@riverpod
List<FixedTagEntry> currentFixedTags(Ref ref) {
  final state = ref.watch(fixedTagsNotifierProvider);
  return state.entries;
}

/// 便捷方法：获取启用的固定词数量
@riverpod
int enabledFixedTagsCount(Ref ref) {
  final state = ref.watch(fixedTagsNotifierProvider);
  return state.enabledCount;
}

/// 便捷方法：获取固定词总数
@riverpod
int fixedTagsCount(Ref ref) {
  final state = ref.watch(fixedTagsNotifierProvider);
  return state.entries.length;
}

/// 便捷方法：检查是否正在加载
@riverpod
bool isFixedTagsLoading(Ref ref) {
  final state = ref.watch(fixedTagsNotifierProvider);
  return state.isLoading;
}
