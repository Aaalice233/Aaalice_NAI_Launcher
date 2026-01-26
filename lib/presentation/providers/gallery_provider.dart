import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/generation_record.dart';
import '../../data/models/gallery/gallery_statistics.dart';
import '../../data/repositories/gallery_repository.dart';

part 'gallery_provider.g.dart';

/// 画廊状态
class GalleryState {
  final List<GenerationRecord> records;
  final GalleryFilter filter;
  final bool isLoading;
  final String? error;
  final Set<String> selectedIds;
  final bool isSelectionMode;

  const GalleryState({
    this.records = const [],
    this.filter = const GalleryFilter(),
    this.isLoading = false,
    this.error,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  GalleryState copyWith({
    List<GenerationRecord>? records,
    GalleryFilter? filter,
    bool? isLoading,
    String? error,
    Set<String>? selectedIds,
    bool? isSelectionMode,
  }) {
    return GalleryState(
      records: records ?? this.records,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedIds: selectedIds ?? this.selectedIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }

  /// 选中的记录数量
  int get selectedCount => selectedIds.length;

  /// 是否有选中的记录
  bool get hasSelection => selectedIds.isNotEmpty;

  /// 获取选中的记录
  List<GenerationRecord> get selectedRecords {
    return records.where((r) => selectedIds.contains(r.id)).toList();
  }
}

/// 画廊状态管理 Provider
@riverpod
class GalleryNotifier extends _$GalleryNotifier {
  late GalleryRepository _repository;
  bool _initialized = false;

  @override
  GalleryState build() {
    _repository = ref.watch(galleryRepositoryProvider);
    _initAsync();
    return const GalleryState(isLoading: true);
  }

  /// 异步初始化
  Future<void> _initAsync() async {
    if (_initialized) return;

    try {
      await _repository.init();
      _initialized = true;
      await refresh();
    } catch (e, stack) {
      AppLogger.e('Failed to init gallery: $e', e, stack, 'Gallery');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新记录列表
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final records = _repository.filterRecords(state.filter);
      state = state.copyWith(
        records: records,
        isLoading: false,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to refresh gallery: $e', e, stack, 'Gallery');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 添加新记录
  Future<GenerationRecord?> addRecord({
    required Uint8List imageData,
    required GenerationParamsSnapshot params,
    bool saveToFile = true,
  }) async {
    try {
      final record = await _repository.addRecord(
        imageData: imageData,
        params: params,
        saveToFile: saveToFile,
      );

      // 刷新列表
      await refresh();

      return record;
    } catch (e, stack) {
      AppLogger.e('Failed to add record: $e', e, stack, 'Gallery');
      return null;
    }
  }

  /// 删除单条记录
  Future<void> deleteRecord(String id) async {
    try {
      await _repository.deleteRecord(id);
      await refresh();
    } catch (e, stack) {
      AppLogger.e('Failed to delete record: $e', e, stack, 'Gallery');
    }
  }

  /// 删除选中的记录
  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) return;

    try {
      await _repository.deleteRecords(state.selectedIds.toList());
      state = state.copyWith(
        selectedIds: {},
        isSelectionMode: false,
      );
      await refresh();
    } catch (e, stack) {
      AppLogger.e('Failed to delete selected: $e', e, stack, 'Gallery');
    }
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String id) async {
    try {
      await _repository.toggleFavorite(id);
      await refresh();
    } catch (e, stack) {
      AppLogger.e('Failed to toggle favorite: $e', e, stack, 'Gallery');
    }
  }

  /// 更新筛选条件
  void updateFilter(GalleryFilter filter) {
    state = state.copyWith(filter: filter);
    refresh();
  }

  /// 设置搜索关键词
  void setSearchQuery(String? query) {
    updateFilter(state.filter.copyWith(searchQuery: query));
  }

  /// 切换只显示收藏
  void toggleFavoritesOnly() {
    updateFilter(
      state.filter.copyWith(favoritesOnly: !state.filter.favoritesOnly),
    );
  }

  /// 设置排序方式
  void setSortOrder(GallerySortOrder order) {
    updateFilter(state.filter.copyWith(sortOrder: order));
  }

  /// 进入选择模式
  void enterSelectionMode() {
    state = state.copyWith(isSelectionMode: true);
  }

  /// 退出选择模式
  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedIds: {},
    );
  }

  /// 切换选中状态
  void toggleSelection(String id) {
    final newSelectedIds = Set<String>.from(state.selectedIds);
    if (newSelectedIds.contains(id)) {
      newSelectedIds.remove(id);
    } else {
      newSelectedIds.add(id);
    }

    state = state.copyWith(selectedIds: newSelectedIds);

    // 如果没有选中项，退出选择模式
    if (newSelectedIds.isEmpty) {
      exitSelectionMode();
    }
  }

  /// 全选
  void selectAll() {
    final allIds = state.records.map((r) => r.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  /// 取消全选
  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }

  /// 获取图像数据
  Future<Uint8List?> getImageData(GenerationRecord record) async {
    return await _repository.getImageData(record);
  }

  /// 导出图像
  Future<String?> exportImage(GenerationRecord record, String targetDir) async {
    return await _repository.exportImage(record, targetDir);
  }

  /// 获取统计信息
  GalleryStatistics getStats() {
    return _repository.getStats();
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    try {
      await _repository.clearAll();
      state = state.copyWith(
        records: [],
        selectedIds: {},
        isSelectionMode: false,
      );
    } catch (e, stack) {
      AppLogger.e('Failed to clear all: $e', e, stack, 'Gallery');
    }
  }
}

/// 便捷 Provider：获取画廊记录列表
@riverpod
List<GenerationRecord> galleryRecords(Ref ref) {
  final state = ref.watch(galleryNotifierProvider);
  return state.records;
}

/// 便捷 Provider：获取是否正在加载
@riverpod
bool isGalleryLoading(Ref ref) {
  final state = ref.watch(galleryNotifierProvider);
  return state.isLoading;
}

/// 便捷 Provider：获取选中数量
@riverpod
int gallerySelectedCount(Ref ref) {
  final state = ref.watch(galleryNotifierProvider);
  return state.selectedCount;
}

/// 便捷 Provider：获取是否在选择模式
@riverpod
bool isGallerySelectionMode(Ref ref) {
  final state = ref.watch(galleryNotifierProvider);
  return state.isSelectionMode;
}

/// 便捷 Provider：获取统计信息
@riverpod
GalleryStatistics galleryStatistics(Ref ref) {
  final notifier = ref.read(galleryNotifierProvider.notifier);
  return notifier.getStats();
}
