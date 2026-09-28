import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/online_gallery_favorite_record.dart';
import '../../data/repositories/online_gallery_local_favorites_repository.dart';

class OnlineGalleryLocalFavoritesState {
  const OnlineGalleryLocalFavoritesState({
    this.isInitialized = false,
    this.isLoading = false,
    this.count = 0,
    this.revision = 0,
    this.lastError,
  });

  final bool isInitialized;
  final bool isLoading;
  final int count;
  final int revision;
  final Object? lastError;

  OnlineGalleryLocalFavoritesState copyWith({
    bool? isInitialized,
    bool? isLoading,
    int? count,
    int? revision,
    Object? lastError,
    bool clearError = false,
  }) => OnlineGalleryLocalFavoritesState(
    isInitialized: isInitialized ?? this.isInitialized,
    isLoading: isLoading ?? this.isLoading,
    count: count ?? this.count,
    revision: revision ?? this.revision,
    lastError: clearError ? null : lastError ?? this.lastError,
  );
}

final onlineGalleryLocalFavoritesRepositoryProvider =
    Provider<OnlineGalleryLocalFavoritesRepository>((ref) {
      return OnlineGalleryLocalFavoritesRepository(
        box: Hive.box<dynamic>(StorageKeys.localFavoritesBox),
        legacyStorage: ref.watch(localStorageServiceProvider),
      );
    });

final onlineGalleryLocalFavoritesProvider =
    StateNotifierProvider<
      OnlineGalleryLocalFavoritesNotifier,
      OnlineGalleryLocalFavoritesState
    >((ref) {
      return OnlineGalleryLocalFavoritesNotifier(
        ref.watch(onlineGalleryLocalFavoritesRepositoryProvider),
      );
    });

class OnlineGalleryLocalFavoritesNotifier
    extends StateNotifier<OnlineGalleryLocalFavoritesState> {
  OnlineGalleryLocalFavoritesNotifier(this._repository)
    : super(const OnlineGalleryLocalFavoritesState(isLoading: true)) {
    unawaited(initialize().catchError((Object _) {}));
  }

  final OnlineGalleryLocalFavoritesRepository _repository;

  Future<void> initialize() async {
    if (state.isInitialized) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.ensureInitialized();
      if (!mounted) return;
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        count: _repository.count,
        clearError: true,
      );
    } catch (error) {
      if (!mounted) rethrow;
      state = state.copyWith(isLoading: false, lastError: error);
      rethrow;
    }
  }

  bool isFavorite(String stableKey) => _repository.contains(stableKey);

  OnlineGalleryFavoriteRecord? getByStableKey(String stableKey) =>
      _repository.getByStableKey(stableKey);

  OnlineGalleryFavoritePage query(OnlineGalleryFavoriteQuery query) =>
      _repository.query(query);

  Future<bool> toggle(GalleryDetail detail, {DateTime? savedAt}) =>
      _write(() => _repository.toggle(detail, savedAt: savedAt));

  Future<void> upsert(GalleryDetail detail, {DateTime? savedAt}) =>
      _write(() => _repository.upsert(detail, savedAt: savedAt));

  Future<int> upsertAll(Iterable<GalleryDetail> details, {DateTime? savedAt}) =>
      _write(() => _repository.upsertAll(details, savedAt: savedAt));

  Future<bool> remove(String stableKey) =>
      _write(() => _repository.remove(stableKey));

  Future<T> _write<T>(Future<T> Function() operation) async {
    try {
      final result = await operation();
      if (mounted) {
        state = state.copyWith(
          count: _repository.count,
          revision: state.revision + 1,
          clearError: true,
        );
      }
      return result;
    } catch (error) {
      if (mounted) state = state.copyWith(lastError: error);
      rethrow;
    }
  }
}
