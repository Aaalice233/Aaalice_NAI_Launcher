import 'dart:io';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart';

part 'local_gallery_provider.freezed.dart';
part 'local_gallery_provider.g.dart';

/// 本地画廊状态
@freezed
class LocalGalleryState with _$LocalGalleryState {
  const factory LocalGalleryState({
    @Default([]) List<File> allFiles,
    @Default([]) List<LocalImageRecord> currentImages,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default(false) bool isIndexing,
    @Default(false) bool isPageLoading,
    String? error,
  }) = _LocalGalleryState;
  
  const LocalGalleryState._();
  int get totalPages => (allFiles.length / pageSize).ceil();
}

/// 本地画廊 Notifier
@Riverpod(keepAlive: true)
class LocalGalleryNotifier extends _$LocalGalleryNotifier {
  final _repository = LocalGalleryRepository.instance;

  @override
  LocalGalleryState build() {
    return const LocalGalleryState();
  }

  /// 初始化：快速索引文件 + 加载首页
  Future<void> initialize() async {
    if (state.allFiles.isNotEmpty) return;
    state = state.copyWith(isIndexing: true, error: null);
    try {
      final files = await _repository.getAllImageFiles();
      state = state.copyWith(allFiles: files, isIndexing: false);
      await loadPage(0);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isIndexing: false);
    }
  }

  /// 加载指定页面
  Future<void> loadPage(int page) async {
    // Handle empty list case (totalPages is 0)
    if (state.allFiles.isEmpty) {
       state = state.copyWith(currentImages: [], isPageLoading: false);
       return;
    }
    
    if (page < 0 || page >= state.totalPages) return;
    
    state = state.copyWith(isPageLoading: true, currentPage: page);
    try {
      final start = page * state.pageSize;
      final end = min(start + state.pageSize, state.allFiles.length);
      final batch = state.allFiles.sublist(start, end);
      
      final records = await _repository.loadRecords(batch);
      state = state.copyWith(currentImages: records, isPageLoading: false);
    } catch (e) {
       state = state.copyWith(isPageLoading: false, error: e.toString());
    }
  }

  /// 刷新画廊
  Future<void> refresh() async {
    state = const LocalGalleryState(); // Reset
    await initialize();
  }
}
