import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/fixed_tag/fixed_tag_link.dart';
import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../data/models/tag_library/tag_library_entry.dart';
import 'tag_library_page_provider.dart';

part 'fixed_tags_provider.g.dart';

/// 固定词状态
class FixedTagsState {
  final List<FixedTagEntry> entries;
  final List<FixedTagLink> links;
  final bool negativePanelExpanded;
  final int undoDepth;
  final int redoDepth;
  final bool isLoading;
  final String? error;

  const FixedTagsState({
    this.entries = const [],
    this.links = const [],
    this.negativePanelExpanded = true,
    this.undoDepth = 0,
    this.redoDepth = 0,
    this.isLoading = false,
    this.error,
  });

  FixedTagsState copyWith({
    List<FixedTagEntry>? entries,
    List<FixedTagLink>? links,
    bool? negativePanelExpanded,
    int? undoDepth,
    int? redoDepth,
    bool? isLoading,
    String? error,
  }) {
    return FixedTagsState(
      entries: entries ?? this.entries,
      links: links ?? this.links,
      negativePanelExpanded:
          negativePanelExpanded ?? this.negativePanelExpanded,
      undoDepth: undoDepth ?? this.undoDepth,
      redoDepth: redoDepth ?? this.redoDepth,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get canUndo => undoDepth > 0;

  bool get canRedo => redoDepth > 0;

  /// 获取正向固定词条目
  List<FixedTagEntry> get positiveEntries => entries
      .where((e) => e.promptType == FixedTagPromptType.positive)
      .toList();

  /// 获取启用的条目
  List<FixedTagEntry> get enabledEntries => entries
      .where((e) => e.enabled && e.promptType == FixedTagPromptType.positive)
      .toList();

  /// 获取启用的条目数量
  int get enabledCount => entries
      .where((e) => e.enabled && e.promptType == FixedTagPromptType.positive)
      .length;

  /// 获取禁用的条目数量
  int get disabledCount => entries
      .where((e) => !e.enabled && e.promptType == FixedTagPromptType.positive)
      .length;

  /// 获取启用的前缀条目
  List<FixedTagEntry> get enabledPrefixes => entries
      .where(
        (e) =>
            e.enabled &&
            e.promptType == FixedTagPromptType.positive &&
            e.position == FixedTagPosition.prefix,
      )
      .toList();

  /// 获取启用的后缀条目
  List<FixedTagEntry> get enabledSuffixes => entries
      .where(
        (e) =>
            e.enabled &&
            e.promptType == FixedTagPromptType.positive &&
            e.position == FixedTagPosition.suffix,
      )
      .toList();

  /// 获取负向固定词条目
  List<FixedTagEntry> get negativeEntries => entries
      .where((e) => e.promptType == FixedTagPromptType.negative)
      .toList();

  /// 获取启用的负向条目
  List<FixedTagEntry> get negativeEnabledEntries =>
      negativeEntries.where((e) => e.enabled).toList();

  /// 获取启用的负向条目数量
  int get negativeEnabledCount =>
      negativeEntries.where((e) => e.enabled).length;

  /// 获取禁用的负向条目数量
  int get negativeDisabledCount =>
      negativeEntries.where((e) => !e.enabled).length;

  /// 按分类分组的正向固定词条目
  Map<String?, List<FixedTagEntry>> get positiveByCategory {
    final grouped = <String?, List<FixedTagEntry>>{};
    for (final entry in positiveEntries.sortedByOrder()) {
      grouped.putIfAbsent(entry.categoryId, () => []).add(entry);
    }
    return grouped;
  }

  /// 获取启用的负向前缀条目
  List<FixedTagEntry> get negativeEnabledPrefixes => entries
      .where(
        (e) =>
            e.enabled &&
            e.promptType == FixedTagPromptType.negative &&
            e.position == FixedTagPosition.prefix,
      )
      .toList();

  /// 获取启用的负向后缀条目
  List<FixedTagEntry> get negativeEnabledSuffixes => entries
      .where(
        (e) =>
            e.enabled &&
            e.promptType == FixedTagPromptType.negative &&
            e.position == FixedTagPosition.suffix,
      )
      .toList();

  /// 应用固定词到提示词
  ///
  /// 将所有启用的固定词按位置应用到用户提示词
  String applyToPrompt(String userPrompt) => entries.applyToPrompt(userPrompt);

  /// 应用负向固定词到负向提示词。
  ///
  /// 语义与正向固定词一致：前缀 + 用户主体 + 后缀。
  String applyToNegativePrompt(String userNegativePrompt) =>
      entries.applyToNegativePrompt(userNegativePrompt);

  /// 获取某个正向固定词联动的负向固定词。
  List<FixedTagEntry> linkedNegativesOf(String positiveId) {
    final negativeIds = links
        .where((link) => link.positiveEntryId == positiveId)
        .map((link) => link.negativeEntryId)
        .toSet();
    return entries
        .where(
          (entry) =>
              entry.promptType == FixedTagPromptType.negative &&
              negativeIds.contains(entry.id),
        )
        .toList();
  }

  /// 获取某个负向固定词被哪些正向固定词联动。
  List<FixedTagEntry> linkedPositivesOf(String negativeId) {
    final positiveIds = links
        .where((link) => link.negativeEntryId == negativeId)
        .map((link) => link.positiveEntryId)
        .toSet();
    return entries
        .where(
          (entry) =>
              entry.promptType == FixedTagPromptType.positive &&
              positiveIds.contains(entry.id),
        )
        .toList();
  }

  /// 判断联动两端是否被用户手动改成不一致状态。
  bool isMismatched(FixedTagLink link) {
    final positive = entries.cast<FixedTagEntry?>().firstWhere(
      (entry) => entry?.id == link.positiveEntryId,
      orElse: () => null,
    );
    final negative = entries.cast<FixedTagEntry?>().firstWhere(
      (entry) => entry?.id == link.negativeEntryId,
      orElse: () => null,
    );
    if (positive == null || negative == null) {
      return false;
    }
    return positive.enabled != negative.enabled;
  }

  /// 从完整提示词中剥离当前启用的固定词前缀/后缀。
  ///
  /// 提示词助手只应处理用户输入框主体内容；如果上游流程已经把固定词
  /// 合并进了文本，这里按固定词配置还原出主体提示词。
  String stripFromPrompt(String prompt) {
    var result = prompt.trim();
    for (final entry in enabledPrefixes.sortedByOrder()) {
      result = _stripLeadingSegment(result, entry.weightedContent);
    }
    for (final entry in enabledSuffixes.sortedByOrder().reversed) {
      result = _stripTrailingSegment(result, entry.weightedContent);
    }
    return result.trim();
  }

  /// 从完整负向提示词中剥离当前启用的负向固定词前缀/后缀。
  String stripFromNegativePrompt(String negativePrompt) {
    var result = negativePrompt.trim();
    for (final entry in negativeEnabledPrefixes.sortedByOrder()) {
      result = _stripLeadingSegment(result, entry.weightedContent);
    }
    for (final entry in negativeEnabledSuffixes.sortedByOrder().reversed) {
      result = _stripTrailingSegment(result, entry.weightedContent);
    }
    return result.trim();
  }

  static String _stripLeadingSegment(String text, String segment) {
    final trimmedText = text.trim();
    final trimmedSegment = segment.trim();
    if (trimmedText.isEmpty || trimmedSegment.isEmpty) {
      return trimmedText;
    }
    if (trimmedText == trimmedSegment) {
      return '';
    }
    if (!trimmedText.startsWith(trimmedSegment)) {
      return trimmedText;
    }
    final rest = trimmedText.substring(trimmedSegment.length).trimLeft();
    if (!rest.startsWith(',')) {
      return trimmedText;
    }
    return rest.substring(1).trimLeft();
  }

  static String _stripTrailingSegment(String text, String segment) {
    final trimmedText = text.trim();
    final trimmedSegment = segment.trim();
    if (trimmedText.isEmpty || trimmedSegment.isEmpty) {
      return trimmedText;
    }
    if (trimmedText == trimmedSegment) {
      return '';
    }
    if (!trimmedText.endsWith(trimmedSegment)) {
      return trimmedText;
    }
    final rest = trimmedText.substring(
      0,
      trimmedText.length - trimmedSegment.length,
    );
    final trimmedRest = rest.trimRight();
    if (!trimmedRest.endsWith(',')) {
      return trimmedText;
    }
    return trimmedRest.substring(0, trimmedRest.length - 1).trimRight();
  }
}

/// 解析固定词对应的词库条目。
///
/// 新数据优先使用稳定来源 ID；旧数据没有来源 ID 时，沿用侧边栏既有的
/// 内容、名称匹配规则，以恢复词库预览兼容性。
TagLibraryEntry? resolveFixedTagLibraryEntry(
  FixedTagEntry fixedEntry,
  List<TagLibraryEntry> libraryEntries,
) {
  final sourceEntryId = fixedEntry.sourceEntryId;
  if (sourceEntryId != null && sourceEntryId.isNotEmpty) {
    for (final libraryEntry in libraryEntries) {
      if (libraryEntry.id == sourceEntryId) return libraryEntry;
    }
  }

  final content = fixedEntry.content.trim();
  if (content.isNotEmpty) {
    for (final libraryEntry in libraryEntries) {
      if (libraryEntry.content.trim() == content) return libraryEntry;
    }
  }

  final name = fixedEntry.name.trim();
  if (name.isEmpty) return null;
  for (final libraryEntry in libraryEntries) {
    if (libraryEntry.name.trim() == name) return libraryEntry;
  }
  return null;
}

/// 从词库条目推断固定词分类。
List<FixedTagEntry> inferFixedTagCategories(
  List<FixedTagEntry> fixedEntries,
  List<TagLibraryEntry> libraryEntries,
) {
  if (libraryEntries.isEmpty) return fixedEntries;
  final entryById = {for (final entry in libraryEntries) entry.id: entry};

  return [
    for (final entry in fixedEntries)
      if (entry.categoryId != null || entry.sourceEntryId == null)
        entry
      else
        entryById[entry.sourceEntryId]?.categoryId == null
            ? entry
            : entry.copyWith(
                categoryId: entryById[entry.sourceEntryId]!.categoryId,
              ),
  ];
}

/// 排除已经从词库添加到固定词列表的条目。
List<TagLibraryEntry> filterUnlinkedLibraryEntries({
  required List<TagLibraryEntry> libraryEntries,
  required List<FixedTagEntry> fixedEntries,
}) {
  final linkedEntryIds = fixedEntries
      .map((entry) => entry.sourceEntryId)
      .whereType<String>()
      .toSet();
  if (linkedEntryIds.isEmpty) return libraryEntries;

  return libraryEntries
      .where((entry) => !linkedEntryIds.contains(entry.id))
      .toList();
}

/// 在筛选后的可见条目内重排，保持隐藏条目的相对位置。
List<FixedTagEntry> reorderFixedTagsWithinVisibleIds({
  required List<FixedTagEntry> entries,
  required FixedTagPromptType promptType,
  required List<String> visibleIds,
  required int oldIndex,
  required int newIndex,
}) {
  final sameType = entries
      .where((entry) => entry.promptType == promptType)
      .toList()
      .sortedByOrder();
  final visibleSet = visibleIds.toSet();
  final visible = sameType
      .where((entry) => visibleSet.contains(entry.id))
      .toList();

  if (oldIndex < 0 || oldIndex >= visible.length) return entries;
  if (newIndex < 0 || newIndex > visible.length) return entries;
  if (oldIndex == newIndex) return entries;

  final moved = visible.removeAt(oldIndex);
  visible.insert(newIndex, moved);

  var visibleCursor = 0;
  final reorderedSameType = [
    for (final entry in sameType)
      if (visibleSet.contains(entry.id)) visible[visibleCursor++] else entry,
  ].reindex();

  final reorderedById = {
    for (final entry in reorderedSameType) entry.id: entry,
  };
  return entries
      .map((entry) => reorderedById[entry.id] ?? entry)
      .toList()
      .sortedByOrder();
}

bool _sameCategoryAssignments(
  List<FixedTagEntry> before,
  List<FixedTagEntry> after,
) {
  if (before.length != after.length) return false;
  for (var i = 0; i < before.length; i++) {
    if (before[i].id != after[i].id ||
        before[i].categoryId != after[i].categoryId) {
      return false;
    }
  }
  return true;
}

/// 固定词 Provider
///
/// 管理固定词列表，支持增删改查、排序、状态切换
/// 自动持久化到 LocalStorage
@Riverpod(keepAlive: true)
class FixedTagsNotifier extends _$FixedTagsNotifier {
  /// 存储服务
  late LocalStorageService _storage;
  final List<FixedTagsState> _undoStack = [];
  final List<FixedTagsState> _redoStack = [];

  @override
  FixedTagsState build() {
    _storage = ref.watch(localStorageServiceProvider);
    _undoStack.clear();
    _redoStack.clear();

    // 直接返回加载的固定词列表
    return _withHistoryCounts(_loadState());
  }

  /// 从存储加载固定词状态
  FixedTagsState _loadState() {
    try {
      final json = _storage.getFixedTagsJson();
      final entries = json == null || json.isEmpty
          ? <FixedTagEntry>[]
          : (jsonDecode(json) as List<dynamic>)
                .map(
                  (e) => FixedTagEntry.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();

      final linksJson = _storage.getFixedTagLinksJson();
      final links = linksJson == null || linksJson.isEmpty
          ? <FixedTagLink>[]
          : (jsonDecode(linksJson) as List<dynamic>)
                .map((e) => FixedTagLink.fromJson(Map<String, dynamic>.from(e)))
                .toList();

      // 按排序顺序排列
      final sortedEntries = entries.sortedByOrder();
      final sanitizedLinks = _sanitizeLinks(sortedEntries, links);
      final negativePanelExpanded = _storage
          .getFixedTagsNegativePanelExpanded();
      AppLogger.d(
        'Loaded ${entries.length} fixed tags and ${sanitizedLinks.length} links',
        'FixedTagsProvider',
      );
      return FixedTagsState(
        entries: sortedEntries,
        links: sanitizedLinks,
        negativePanelExpanded: negativePanelExpanded,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load fixed tags: $e',
        e,
        stack,
        'FixedTagsProvider',
      );
      return FixedTagsState(entries: [], links: [], error: e.toString());
    }
  }

  List<FixedTagLink> _sanitizeLinks(
    List<FixedTagEntry> entries,
    List<FixedTagLink> links,
  ) {
    final positiveIds = entries
        .where((entry) => entry.promptType == FixedTagPromptType.positive)
        .map((entry) => entry.id)
        .toSet();
    final negativeIds = entries
        .where((entry) => entry.promptType == FixedTagPromptType.negative)
        .map((entry) => entry.id)
        .toSet();
    final seenPairs = <String>{};
    final sanitized = <FixedTagLink>[];
    for (final link in links) {
      if (!positiveIds.contains(link.positiveEntryId) ||
          !negativeIds.contains(link.negativeEntryId)) {
        continue;
      }
      final pairKey = '${link.positiveEntryId}:${link.negativeEntryId}';
      if (!seenPairs.add(pairKey)) {
        continue;
      }
      sanitized.add(link);
    }
    return sanitized;
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

  /// 保存固定词联动关系到存储
  Future<void> _saveLinks() async {
    try {
      final json = jsonEncode(state.links.map((e) => e.toJson()).toList());
      await _storage.setFixedTagLinksJson(json);
      AppLogger.d(
        'Saved ${state.links.length} fixed tag links',
        'FixedTagsProvider',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save fixed tag links: $e',
        e,
        stack,
        'FixedTagsProvider',
      );
    }
  }

  Future<void> _saveNegativePanelExpanded() async {
    await _storage.setFixedTagsNegativePanelExpanded(
      state.negativePanelExpanded,
    );
  }

  FixedTagsState _historySnapshot(FixedTagsState value) {
    return value.copyWith(undoDepth: 0, redoDepth: 0);
  }

  FixedTagsState _withHistoryCounts(FixedTagsState value) {
    return value.copyWith(
      undoDepth: _undoStack.length,
      redoDepth: _redoStack.length,
    );
  }

  void _commitState(FixedTagsState nextState) {
    _undoStack.add(_historySnapshot(state));
    _redoStack.clear();
    state = _withHistoryCounts(nextState);
  }

  Future<void> _saveAllState() async {
    await _saveEntries();
    await _saveLinks();
    await _saveNegativePanelExpanded();
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_historySnapshot(state));
    state = _withHistoryCounts(_undoStack.removeLast());
    await _saveAllState();
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_historySnapshot(state));
    state = _withHistoryCounts(_redoStack.removeLast());
    await _saveAllState();
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
    FixedTagPromptType promptType = FixedTagPromptType.positive,
    String? sourceEntryId, // 【新增】来源词库条目ID
    String? categoryId,
  }) async {
    final duplicateIndex = sourceEntryId == null || sourceEntryId.isEmpty
        ? -1
        : state.entries.indexWhere(
            (entry) =>
                entry.sourceEntryId == sourceEntryId &&
                entry.promptType == promptType &&
                entry.position == position,
          );
    if (duplicateIndex >= 0) {
      final duplicate = state.entries[duplicateIndex];
      if (enabled && !duplicate.enabled) {
        final reenabled = duplicate.copyWith(
          enabled: true,
          updatedAt: DateTime.now(),
        );
        final entries = [...state.entries]..[duplicateIndex] = reenabled;
        _commitState(state.copyWith(entries: entries));
        await _saveEntries();
        return reenabled;
      }
      return duplicate;
    }

    final entry = FixedTagEntry.create(
      name: name,
      content: content,
      weight: weight,
      position: position,
      enabled: enabled,
      promptType: promptType,
      sourceEntryId: sourceEntryId, // 【新增】
      categoryId: categoryId,
      sortOrder: state.entries.length,
    );

    final newEntries = [...state.entries, entry];
    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();

    AppLogger.d('Added fixed tag: ${entry.displayName}', 'FixedTagsProvider');
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
    final sanitizedLinks = _sanitizeLinks(newEntries, state.links);
    final removedInvalidLinks = sanitizedLinks.length != state.links.length;
    _commitState(state.copyWith(entries: newEntries, links: sanitizedLinks));
    await _saveEntries();
    if (removedInvalidLinks) {
      await _saveLinks();
    }

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
          categoryId: tagEntry.categoryId,
          updatedAt: DateTime.now(),
        );
      }
    }

    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();

    AppLogger.d(
      'Synced ${entriesToSync.length} fixed tags from tag library: ${tagEntry.name}',
      'FixedTagsProvider',
    );
  }

  /// 从词库条目补齐已关联固定词缺失的分类。
  Future<void> inferCategoriesFromLibrary() async {
    final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);
    final inferred = inferFixedTagCategories(
      state.entries,
      tagLibraryState.entries,
    );
    if (_sameCategoryAssignments(state.entries, inferred)) return;

    state = state.copyWith(entries: inferred);
    await _saveEntries();
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
      final tagLibraryNotifier = ref.read(
        tagLibraryPageNotifierProvider.notifier,
      );
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
      AppLogger.e(
        'Failed to sync to tag library: $e',
        e,
        stack,
        'FixedTagsProvider',
      );
    }
  }

  /// 删除固定词
  Future<void> deleteEntry(String entryId) async {
    final newEntries = state.entries
        .where((e) => e.id != entryId)
        .toList()
        .reindex();
    final newLinks = state.links
        .where(
          (link) =>
              link.positiveEntryId != entryId &&
              link.negativeEntryId != entryId,
        )
        .toList();
    _commitState(state.copyWith(entries: newEntries, links: newLinks));
    await _saveEntries();
    await _saveLinks();

    AppLogger.d('Deleted fixed tag: $entryId', 'FixedTagsProvider');
  }

  /// 切换启用状态
  Future<void> toggleEnabled(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    final entry = newEntries[index];
    final nextEnabled = !entry.enabled;
    newEntries[index] = entry.copyWith(
      enabled: nextEnabled,
      updatedAt: DateTime.now(),
    );

    if (entry.promptType == FixedTagPromptType.positive) {
      final linkedNegativeIds = state.links
          .where((link) => link.positiveEntryId == entry.id)
          .map((link) => link.negativeEntryId)
          .toSet();
      for (var i = 0; i < newEntries.length; i++) {
        final candidate = newEntries[i];
        if (linkedNegativeIds.contains(candidate.id) &&
            candidate.enabled != nextEnabled) {
          newEntries[i] = candidate.copyWith(
            enabled: nextEnabled,
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();
  }

  /// 切换位置
  Future<void> togglePosition(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].togglePosition();
    _commitState(state.copyWith(entries: newEntries));
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
    _commitState(state.copyWith(entries: reindexed));
    await _saveEntries();

    AppLogger.d(
      'Reordered fixed tags: $oldIndex -> $newIndex',
      'FixedTagsProvider',
    );
  }

  /// 在同一提示词类型内重排，避免双栏或过滤列表误改另一侧顺序。
  Future<void> reorderWithinPromptType(
    FixedTagPromptType promptType,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;

    final sameType = state.entries
        .where((entry) => entry.promptType == promptType)
        .toList()
        .sortedByOrder();
    if (oldIndex < 0 || oldIndex >= sameType.length) return;
    if (newIndex < 0 || newIndex > sameType.length) return;

    final moved = sameType.removeAt(oldIndex);
    sameType.insert(newIndex, moved);
    final sameTypeById = {
      for (var i = 0; i < sameType.length; i++)
        sameType[i].id: sameType[i].copyWith(sortOrder: i),
    };
    final newEntries = state.entries
        .map((entry) => sameTypeById[entry.id] ?? entry)
        .toList()
        .sortedByOrder();

    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();
  }

  /// 在可见固定词 ID 范围内重排，适用于分类或搜索筛选后的列表。
  Future<void> reorderWithinVisibleIds({
    required FixedTagPromptType promptType,
    required List<String> visibleIds,
    required int oldIndex,
    required int newIndex,
  }) async {
    final reordered = reorderFixedTagsWithinVisibleIds(
      entries: state.entries,
      promptType: promptType,
      visibleIds: visibleIds,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (identical(reordered, state.entries) || reordered == state.entries) {
      return;
    }
    _commitState(state.copyWith(entries: reordered));
    await _saveEntries();
  }

  /// 创建正向到负向的联动关系。
  Future<FixedTagLink?> createLink({
    required String positiveEntryId,
    required String negativeEntryId,
  }) async {
    final positive = getEntry(positiveEntryId);
    final negative = getEntry(negativeEntryId);
    if (positive?.promptType != FixedTagPromptType.positive ||
        negative?.promptType != FixedTagPromptType.negative) {
      AppLogger.w(
        'Invalid fixed tag link endpoints: $positiveEntryId -> $negativeEntryId',
        'FixedTagsProvider',
      );
      return null;
    }

    final exists = state.links.any(
      (link) =>
          link.positiveEntryId == positiveEntryId &&
          link.negativeEntryId == negativeEntryId,
    );
    if (exists) {
      return null;
    }

    final link = FixedTagLink.create(
      positiveEntryId: positiveEntryId,
      negativeEntryId: negativeEntryId,
    );
    _commitState(state.copyWith(links: [...state.links, link]));
    await _saveLinks();
    return link;
  }

  /// 删除指定联动关系。
  Future<void> removeLink(String linkId) async {
    final newLinks = state.links.where((link) => link.id != linkId).toList();
    if (newLinks.length == state.links.length) return;
    _commitState(state.copyWith(links: newLinks));
    await _saveLinks();
  }

  /// 按端点删除联动关系。
  Future<void> removeLinkByPair({
    required String positiveEntryId,
    required String negativeEntryId,
  }) async {
    final newLinks = state.links
        .where(
          (link) =>
              link.positiveEntryId != positiveEntryId ||
              link.negativeEntryId != negativeEntryId,
        )
        .toList();
    if (newLinks.length == state.links.length) return;
    _commitState(state.copyWith(links: newLinks));
    await _saveLinks();
  }

  /// 应用固定词到提示词
  ///
  /// 将所有启用的固定词按位置应用到用户提示词
  String applyToPrompt(String userPrompt) {
    return state.applyToPrompt(userPrompt);
  }

  /// 应用负向固定词到负向提示词
  String applyToNegativePrompt(String userNegativePrompt) {
    return state.applyToNegativePrompt(userNegativePrompt);
  }

  /// 从负向提示词中剥离负向固定词
  String stripFromNegativePrompt(String negativePrompt) {
    return state.stripFromNegativePrompt(negativePrompt);
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
    _commitState(state.copyWith(entries: [], links: []));
    await _saveEntries();
    await _saveLinks();
    AppLogger.d('Cleared all fixed tags', 'FixedTagsProvider');
  }

  /// 重新加载
  void refresh() {
    _undoStack.clear();
    _redoStack.clear();
    state = _withHistoryCounts(_loadState());
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
    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();
  }

  /// 批量设置正向固定词，并让联动负向跟随。
  Future<void> setAllPositiveEnabled(bool enabled) async {
    final linkedNegativeIds = state.links.map((link) => link.negativeEntryId);
    final affectedIds = {
      ...state.positiveEntries.map((entry) => entry.id),
      ...linkedNegativeIds,
    };
    final newEntries = state.entries
        .map(
          (entry) => affectedIds.contains(entry.id) && entry.enabled != enabled
              ? entry.copyWith(enabled: enabled, updatedAt: DateTime.now())
              : entry,
        )
        .toList();
    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();
  }

  /// 批量设置负向固定词，不反向影响正向。
  Future<void> setAllNegativeEnabled(bool enabled) async {
    final newEntries = state.entries
        .map(
          (entry) =>
              entry.promptType == FixedTagPromptType.negative &&
                  entry.enabled != enabled
              ? entry.copyWith(enabled: enabled, updatedAt: DateTime.now())
              : entry,
        )
        .toList();
    _commitState(state.copyWith(entries: newEntries));
    await _saveEntries();
  }

  Future<void> setNegativePanelExpanded(bool expanded) async {
    state = _withHistoryCounts(state.copyWith(negativePanelExpanded: expanded));
    await _saveNegativePanelExpanded();
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
