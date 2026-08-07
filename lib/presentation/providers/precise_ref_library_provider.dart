import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/enums/precise_ref_type.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../data/services/precise_ref_library_storage_service.dart';

part 'precise_ref_library_provider.freezed.dart';
part 'precise_ref_library_provider.g.dart';

/// 精准参考库排序方式
enum PreciseRefLibrarySortOrder { createdAt, lastUsed, usedCount, name }

typedef PreciseRefLibraryBytesLoader = Future<Uint8List?> Function();

class PreciseRefLibraryImportSource {
  const PreciseRefLibraryImportSource({
    required this.loadBytes,
    required this.name,
    this.type = PreciseRefType.characterAndStyle,
    this.strength = 1.0,
    this.fidelity = 1.0,
  });

  final PreciseRefLibraryBytesLoader loadBytes;
  final String name;
  final PreciseRefType type;
  final double strength;
  final double fidelity;
}

class PreciseRefLibraryBatchImportResult {
  const PreciseRefLibraryBatchImportResult({
    required this.entries,
    required this.failedCount,
  });

  final List<PreciseRefLibraryEntry> entries;
  final int failedCount;

  int get importedCount => entries.length;
}

/// 精准参考库状态
@freezed
class PreciseRefLibraryState with _$PreciseRefLibraryState {
  const factory PreciseRefLibraryState({
    /// 所有条目
    @Default([]) List<PreciseRefLibraryEntry> entries,

    /// 过滤排序后的条目
    @Default([]) List<PreciseRefLibraryEntry> filteredEntries,
    @Default(false) bool isLoading,

    /// 搜索关键词
    @Default('') String searchQuery,

    /// 是否只显示收藏
    @Default(false) bool favoritesOnly,

    /// 类型过滤（null = 全部类型）
    PreciseRefType? typeFilter,

    /// 排序方式
    @Default(PreciseRefLibrarySortOrder.createdAt)
    PreciseRefLibrarySortOrder sortOrder,

    /// 是否降序排列
    @Default(true) bool sortDescending,

    /// 错误信息
    String? error,
  }) = _PreciseRefLibraryState;

  const PreciseRefLibraryState._();

  int get totalCount => entries.length;
  bool get hasFilters =>
      searchQuery.isNotEmpty || favoritesOnly || typeFilter != null;
}

/// 精准参考库 Notifier
///
/// 管理精准参考库的加载、搜索、收藏过滤、排序与 CRUD。
@Riverpod(keepAlive: true)
class PreciseRefLibraryNotifier extends _$PreciseRefLibraryNotifier {
  late final PreciseRefLibraryStorageService _storage;
  Future<void>? _activeLoadFuture;
  bool _initialized = false;

  @override
  PreciseRefLibraryState build() {
    _storage = ref.watch(preciseRefLibraryStorageServiceProvider);
    return const PreciseRefLibraryState();
  }

  /// 初始化（成功加载过即返回；空库同样视为已初始化）。
  Future<void> initialize() async {
    if (_initialized) return;
    await reload(showLoading: true);
  }

  /// 重新加载数据
  Future<void> reload({bool showLoading = false}) {
    return _activeLoadFuture ??= _loadData(
      showLoading: showLoading,
    ).whenComplete(() => _activeLoadFuture = null);
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final entries = await _storage.getAllEntries();
      state = state.copyWith(entries: entries, isLoading: false, error: null);
      _initialized = true;
      _applyFilters();
    } catch (e, s) {
      AppLogger.e('加载精准参考库失败', e, s, 'PreciseRefLibrary');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// 切换只看收藏
  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
    _applyFilters();
  }

  /// 设置类型过滤（null = 全部类型）
  void setTypeFilter(PreciseRefType? type) {
    if (state.typeFilter == type) return;
    state = state.copyWith(typeFilter: type);
    _applyFilters();
  }

  /// 一键清除全部过滤条件（搜索、收藏、类型）
  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      favoritesOnly: false,
      typeFilter: null,
    );
    _applyFilters();
  }

  /// 设置排序方式
  void setSortOrder(PreciseRefLibrarySortOrder order, {bool? descending}) {
    final sameOrder = state.sortOrder == order;
    state = state.copyWith(
      sortOrder: order,
      // 再次点击同一排序时翻转方向
      sortDescending: descending ?? (sameOrder ? !state.sortDescending : true),
    );
    _applyFilters();
  }

  void _applyFilters() {
    var result = state.entries.search(state.searchQuery);
    if (state.favoritesOnly) {
      result = result.favorites;
    }
    final typeFilter = state.typeFilter;
    if (typeFilter != null) {
      result = result.where((e) => e.type == typeFilter).toList();
    }
    result = switch (state.sortOrder) {
      PreciseRefLibrarySortOrder.createdAt => result.sortedByCreatedAt(
        descending: state.sortDescending,
      ),
      PreciseRefLibrarySortOrder.lastUsed => result.sortedByLastUsed(
        descending: state.sortDescending,
      ),
      PreciseRefLibrarySortOrder.usedCount => result.sortedByUsedCount(
        descending: state.sortDescending,
      ),
      PreciseRefLibrarySortOrder.name => result.sortedByName(
        descending: state.sortDescending,
      ),
    };
    state = state.copyWith(filteredEntries: result);
  }

  /// 从图片字节导入条目（成功后就地插入 state）
  Future<PreciseRefLibraryEntry> importFromBytes(
    Uint8List bytes, {
    required String name,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
  }) async {
    await _ensureInitialized();
    try {
      final entry = await _storage.importFromBytes(
        bytes,
        name: name,
        type: type,
        strength: strength,
        fidelity: fidelity,
      );
      state = state.copyWith(entries: [...state.entries, entry], error: null);
      _applyFilters();
      return entry;
    } catch (e, s) {
      AppLogger.e('导入精准参考失败', e, s, 'PreciseRefLibrary');
      rethrow;
    }
  }

  /// 有限并发导入，并在整批完成后只更新一次 entries 与过滤结果。
  Future<PreciseRefLibraryBatchImportResult> importMany(
    List<PreciseRefLibraryImportSource> sources, {
    int maxConcurrent = 3,
  }) async {
    if (maxConcurrent <= 0) {
      throw ArgumentError.value(maxConcurrent, 'maxConcurrent');
    }
    if (sources.isEmpty) {
      return const PreciseRefLibraryBatchImportResult(
        entries: [],
        failedCount: 0,
      );
    }

    await _ensureInitialized();
    final importedByIndex = List<PreciseRefLibraryEntry?>.filled(
      sources.length,
      null,
    );
    var failedCount = 0;
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < sources.length) {
        final index = nextIndex++;
        final source = sources[index];
        try {
          final bytes = await source.loadBytes();
          if (bytes == null || bytes.isEmpty) {
            throw const InvalidPreciseRefImageException();
          }
          importedByIndex[index] = await _storage.importFromBytes(
            bytes,
            name: source.name,
            type: source.type,
            strength: source.strength,
            fidelity: source.fidelity,
          );
        } catch (e, s) {
          failedCount++;
          AppLogger.e('批量导入精准参考失败', e, s, 'PreciseRefLibrary');
        }
      }
    }

    final workerCount = sources.length < maxConcurrent
        ? sources.length
        : maxConcurrent;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    final imported = importedByIndex
        .whereType<PreciseRefLibraryEntry>()
        .toList();
    if (imported.isNotEmpty) {
      state = state.copyWith(
        entries: [...state.entries, ...imported],
        error: null,
      );
      _applyFilters();
    }
    return PreciseRefLibraryBatchImportResult(
      entries: imported,
      failedCount: failedCount,
    );
  }

  /// 更新条目元数据
  Future<PreciseRefLibraryEntry?> updateEntry(
    String id, {
    String? name,
    PreciseRefType? type,
    double? strength,
    double? fidelity,
  }) async {
    await _ensureInitialized();
    final updated = await _storage.updateEntry(
      id,
      name: name,
      type: type,
      strength: strength,
      fidelity: fidelity,
    );
    if (updated != null) {
      _replaceEntryInState(updated);
    }
    return updated;
  }

  /// 删除条目
  Future<bool> deleteEntry(String id) async {
    await _ensureInitialized();
    final removed = await _storage.deleteEntry(id);
    if (removed) {
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != id).toList(),
      );
      _applyFilters();
    }
    return removed;
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String id) async {
    await _ensureInitialized();
    final updated = await _storage.toggleFavorite(id);
    if (updated != null) {
      _replaceEntryInState(updated);
    }
  }

  /// 记录一次使用
  Future<void> recordUsage(String id) async {
    await _ensureInitialized();
    final updated = await _storage.recordUsage(id);
    if (updated != null) {
      _replaceEntryInState(updated);
    }
  }

  void _replaceEntryInState(PreciseRefLibraryEntry updated) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == updated.id) updated else e,
      ],
    );
    _applyFilters();
  }

  Future<void> _ensureInitialized() async {
    await initialize();
    if (!_initialized) {
      throw StateError(state.error ?? 'Precise reference library unavailable');
    }
  }
}
