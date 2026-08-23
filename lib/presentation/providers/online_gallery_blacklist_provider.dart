import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/services/danbooru_auth_service.dart';

enum OnlineGalleryBlacklistSource { local, cloud }

class OnlineGalleryBlacklistState {
  final Set<String> localTags;
  final Set<String> remoteTags;
  final OnlineGalleryBlacklistSource selectedSource;
  final bool isCloudAvailable;
  final bool autoSyncOnStartup;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final bool isInitialized;

  const OnlineGalleryBlacklistState({
    this.localTags = const {},
    this.remoteTags = const {},
    this.selectedSource = OnlineGalleryBlacklistSource.local,
    this.isCloudAvailable = false,
    this.autoSyncOnStartup = true,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastSyncError,
    this.isInitialized = false,
  });

  OnlineGalleryBlacklistSource get effectiveSource =>
      selectedSource == OnlineGalleryBlacklistSource.cloud && isCloudAvailable
      ? OnlineGalleryBlacklistSource.cloud
      : OnlineGalleryBlacklistSource.local;

  Set<String> get effectiveTags =>
      effectiveSource == OnlineGalleryBlacklistSource.cloud
      ? remoteTags
      : localTags;

  OnlineGalleryBlacklistState copyWith({
    Set<String>? localTags,
    Set<String>? remoteTags,
    OnlineGalleryBlacklistSource? selectedSource,
    bool? isCloudAvailable,
    bool? autoSyncOnStartup,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastSyncError,
    bool clearLastSyncError = false,
    bool? isInitialized,
  }) {
    return OnlineGalleryBlacklistState(
      localTags: localTags ?? this.localTags,
      remoteTags: remoteTags ?? this.remoteTags,
      selectedSource: selectedSource ?? this.selectedSource,
      isCloudAvailable: isCloudAvailable ?? this.isCloudAvailable,
      autoSyncOnStartup: autoSyncOnStartup ?? this.autoSyncOnStartup,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class OnlineGalleryBlacklistNotifier
    extends StateNotifier<OnlineGalleryBlacklistState> {
  static const Duration _startupSyncMinInterval = Duration(minutes: 30);
  static const Duration _authWaitStep = Duration(milliseconds: 500);
  static const int _authWaitMaxRounds = 24;

  final Ref _ref;
  final LocalStorageService _storage;
  late final Future<void> _initFuture;

  OnlineGalleryBlacklistNotifier(this._ref, this._storage)
    : super(const OnlineGalleryBlacklistState()) {
    _ref.listen<DanbooruAuthState>(danbooruAuthProvider, (previous, next) {
      if (!mounted || state.isCloudAvailable == next.isLoggedIn) return;
      state = state.copyWith(isCloudAvailable: next.isLoggedIn);
    });
    _initFuture = _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final localRaw = _storage.getSetting<List<dynamic>>(
      StorageKeys.onlineGalleryBlacklistTags,
      defaultValue: const <dynamic>[],
    );
    final remoteRaw = _storage.getSetting<List<dynamic>>(
      StorageKeys.onlineGalleryRemoteBlacklistTags,
      defaultValue: const <dynamic>[],
    );
    final autoSync =
        _storage.getSetting<bool>(
          StorageKeys.onlineGalleryBlacklistAutoSync,
          defaultValue: true,
        ) ??
        true;
    final sourceRaw = _storage.getSetting<String>(
      StorageKeys.onlineGalleryBlacklistSource,
      defaultValue: OnlineGalleryBlacklistSource.local.name,
    );
    final lastSyncAtMs = _storage.getSetting<int>(
      StorageKeys.onlineGalleryBlacklistLastSyncAt,
    );
    final lastSyncError = _storage.getSetting<String>(
      StorageKeys.onlineGalleryBlacklistLastSyncError,
    );

    state = state.copyWith(
      localTags: _normalizeTags((localRaw ?? const []).whereType<String>()),
      remoteTags: _normalizeTags((remoteRaw ?? const []).whereType<String>()),
      selectedSource: OnlineGalleryBlacklistSource.values.firstWhere(
        (value) => value.name == sourceRaw,
        orElse: () => OnlineGalleryBlacklistSource.local,
      ),
      isCloudAvailable: _ref.read(danbooruAuthProvider).isLoggedIn,
      autoSyncOnStartup: autoSync,
      lastSyncAt: lastSyncAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncAtMs)
          : null,
      lastSyncError: lastSyncError,
      isInitialized: true,
    );
  }

  Future<void> ensureInitialized() => _initFuture;

  Future<void> setSelectedSource(OnlineGalleryBlacklistSource source) async {
    await ensureInitialized();
    if (source == OnlineGalleryBlacklistSource.cloud &&
        !state.isCloudAvailable) {
      return;
    }
    await _storage.setSetting(
      StorageKeys.onlineGalleryBlacklistSource,
      source.name,
    );
    state = state.copyWith(selectedSource: source);
  }

  Future<bool> addTag(String input) async {
    await ensureInitialized();
    final normalized = _normalizeTag(input);
    if (normalized == null) return false;

    if (state.effectiveSource == OnlineGalleryBlacklistSource.cloud) {
      if (state.remoteTags.contains(normalized)) return false;
      return _replaceCloudTags({...state.remoteTags, normalized});
    }

    if (state.localTags.contains(normalized)) return false;
    final next = {...state.localTags, normalized};
    await _saveLocalTags(next);
    state = state.copyWith(localTags: next);
    return true;
  }

  Future<bool> removeTag(String tag) async {
    await ensureInitialized();
    final normalized = _normalizeTag(tag);
    if (normalized == null) return false;

    if (state.effectiveSource == OnlineGalleryBlacklistSource.cloud) {
      if (!state.remoteTags.contains(normalized)) return false;
      return _replaceCloudTags({...state.remoteTags}..remove(normalized));
    }

    if (!state.localTags.contains(normalized)) return false;
    final next = {...state.localTags}..remove(normalized);
    await _saveLocalTags(next);
    state = state.copyWith(localTags: next);
    return true;
  }

  Future<void> addLocalTag(String input) async {
    await ensureInitialized();
    final normalized = _normalizeTag(input);
    if (normalized == null || state.localTags.contains(normalized)) return;
    final next = {...state.localTags, normalized};
    await _saveLocalTags(next);
    state = state.copyWith(localTags: next);
  }

  Future<void> removeLocalTag(String tag) async {
    await ensureInitialized();
    final normalized = _normalizeTag(tag);
    if (normalized == null || !state.localTags.contains(normalized)) return;
    final next = {...state.localTags}..remove(normalized);
    await _saveLocalTags(next);
    state = state.copyWith(localTags: next);
  }

  Future<void> clearLocalTags() async {
    await ensureInitialized();
    await _saveLocalTags(const <String>{});
    state = state.copyWith(localTags: const <String>{});
  }

  Future<void> setAutoSyncOnStartup(bool value) async {
    await ensureInitialized();
    await _storage.setSetting(
      StorageKeys.onlineGalleryBlacklistAutoSync,
      value,
    );
    state = state.copyWith(autoSyncOnStartup: value);
  }

  Future<void> syncOnStartup() async {
    await ensureInitialized();
    if (!state.autoSyncOnStartup) return;

    final authState = await _waitAuthReadyForStartup();
    if (!authState.isLoggedIn) return;

    final now = DateTime.now();
    final lastSyncAt = state.lastSyncAt;
    if (lastSyncAt != null &&
        now.difference(lastSyncAt) < _startupSyncMinInterval) {
      return;
    }

    await pullFromCloud();
  }

  Future<DanbooruAuthState> _waitAuthReadyForStartup() async {
    var authState = _ref.read(danbooruAuthProvider);
    for (var i = 0; i < _authWaitMaxRounds; i++) {
      if (!authState.isLoading) return authState;
      await Future<void>.delayed(_authWaitStep);
      authState = _ref.read(danbooruAuthProvider);
    }
    return authState;
  }

  /// Refreshes the cached cloud list without changing the independent local list.
  Future<bool> pullFromCloud() async {
    await ensureInitialized();
    if (state.isSyncing) return false;
    if (!_ref.read(danbooruAuthProvider).isLoggedIn) {
      await _setSyncError('Danbooru login required');
      return false;
    }

    state = state.copyWith(isSyncing: true, clearLastSyncError: true);
    try {
      final api = _ref.read(danbooruApiServiceProvider);
      final remoteTags = _normalizeTags(await api.fetchBlacklistedTags());
      final syncTime = DateTime.now();
      await _saveRemoteTags(remoteTags);
      await _saveLastSyncAt(syncTime);
      await _clearLastSyncError();
      state = state.copyWith(
        remoteTags: remoteTags,
        isSyncing: false,
        lastSyncAt: syncTime,
        clearLastSyncError: true,
      );
      return true;
    } catch (error, stack) {
      await _handleSyncFailure('Pull failed', error, stack);
      return false;
    }
  }

  /// Replaces the Danbooru blacklist with the current local list.
  Future<bool> pushLocalToCloud() async {
    await ensureInitialized();
    return _replaceCloudTags(state.localTags);
  }

  Future<bool> _replaceCloudTags(Set<String> next) async {
    if (state.isSyncing) return false;
    if (!_ref.read(danbooruAuthProvider).isLoggedIn) {
      await _setSyncError('Danbooru login required');
      return false;
    }

    state = state.copyWith(isSyncing: true, clearLastSyncError: true);
    try {
      final normalized = _normalizeTags(next);
      final api = _ref.read(danbooruApiServiceProvider);
      final pushOk = await api.updateBlacklistedTags(
        normalized.toList()..sort(),
      );
      if (!pushOk) throw StateError('Danbooru rejected the blacklist update');

      final syncTime = DateTime.now();
      await _saveRemoteTags(normalized);
      await _saveLastSyncAt(syncTime);
      await _clearLastSyncError();
      state = state.copyWith(
        remoteTags: normalized,
        isSyncing: false,
        lastSyncAt: syncTime,
        clearLastSyncError: true,
      );
      return true;
    } catch (error, stack) {
      await _handleSyncFailure('Push failed', error, stack);
      return false;
    }
  }

  Future<void> _handleSyncFailure(
    String operation,
    Object error,
    StackTrace stack,
  ) async {
    final message = '$operation: $error';
    AppLogger.w(message, 'OnlineGalleryBlacklist');
    AppLogger.d('$stack', 'OnlineGalleryBlacklist');
    await _setSyncError(message);
  }

  Future<void> _setSyncError(String message) async {
    await _saveLastSyncError(message);
    state = state.copyWith(isSyncing: false, lastSyncError: message);
  }

  Set<String> _normalizeTags(Iterable<String> values) =>
      values.map(_normalizeTag).whereType<String>().toSet();

  String? _normalizeTag(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    var normalized = trimmed.toLowerCase().replaceAll(' ', '_');

    while (normalized.startsWith('-')) {
      normalized = normalized.substring(1);
    }

    if (normalized.contains(':') || normalized.startsWith('~')) return null;
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _saveLocalTags(Set<String> tags) async {
    await _storage.setSetting(
      StorageKeys.onlineGalleryBlacklistTags,
      tags.toList()..sort(),
    );
  }

  Future<void> _saveRemoteTags(Set<String> tags) async {
    await _storage.setSetting(
      StorageKeys.onlineGalleryRemoteBlacklistTags,
      tags.toList()..sort(),
    );
  }

  Future<void> _saveLastSyncAt(DateTime time) async {
    await _storage.setSetting(
      StorageKeys.onlineGalleryBlacklistLastSyncAt,
      time.millisecondsSinceEpoch,
    );
  }

  Future<void> _saveLastSyncError(String message) async {
    await _storage.setSetting(
      StorageKeys.onlineGalleryBlacklistLastSyncError,
      message,
    );
  }

  Future<void> _clearLastSyncError() async {
    await _storage.deleteSetting(
      StorageKeys.onlineGalleryBlacklistLastSyncError,
    );
  }
}

final onlineGalleryBlacklistNotifierProvider =
    StateNotifierProvider<
      OnlineGalleryBlacklistNotifier,
      OnlineGalleryBlacklistState
    >((ref) {
      final storage = ref.read(localStorageServiceProvider);
      return OnlineGalleryBlacklistNotifier(ref, storage);
    });
