import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';

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
  Future<FixedTagEntry> addEntry({
    required String name,
    required String content,
    double weight = 1.0,
    FixedTagPosition position = FixedTagPosition.prefix,
    bool enabled = true,
  }) async {
    final entry = FixedTagEntry.create(
      name: name,
      content: content,
      weight: weight,
      position: position,
      enabled: enabled,
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
  Future<void> updateEntry(FixedTagEntry updatedEntry) async {
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
      'Updated fixed tag: ${updatedEntry.displayName}',
      'FixedTagsProvider',
    );
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
    return state.entries.applyToPrompt(userPrompt);
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
