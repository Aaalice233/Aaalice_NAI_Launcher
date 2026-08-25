import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/models/online_gallery/gallery_blacklist.dart';
import '../../data/repositories/online_gallery_blacklist_repository.dart';
import '../../data/services/danbooru_auth_service.dart';

class OnlineGalleryBlacklistState {
  const OnlineGalleryBlacklistState({
    this.tags = const {},
    this.tombstones = const {},
    this.remoteTags = const {},
    this.opaqueRemoteRules = const [],
    this.currentAccountKey,
    this.isCloudAvailable = false,
    this.hasCloudCredentials = false,
    this.autoSyncOnStartup = true,
    this.syncPhase = GalleryBlacklistSyncPhase.idle,
    this.lastSyncAt,
    this.lastSyncError,
    this.revision = 0,
    this.isInitialized = false,
    this.canUndo = false,
  });

  final Set<String> tags;
  final Set<String> tombstones;
  final Set<String> remoteTags;
  final List<String> opaqueRemoteRules;
  final String? currentAccountKey;
  final bool isCloudAvailable;
  final bool hasCloudCredentials;
  final bool autoSyncOnStartup;
  final GalleryBlacklistSyncPhase syncPhase;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final int revision;
  final bool isInitialized;
  final bool canUndo;

  bool get isSyncing => syncPhase != GalleryBlacklistSyncPhase.idle;
  bool get isCloudCacheStale =>
      lastSyncAt == null ||
      DateTime.now().difference(lastSyncAt!) > const Duration(hours: 24);

  OnlineGalleryBlacklistState copyWith({
    Set<String>? tags,
    Set<String>? tombstones,
    Set<String>? remoteTags,
    List<String>? opaqueRemoteRules,
    String? currentAccountKey,
    bool clearCurrentAccountKey = false,
    bool? isCloudAvailable,
    bool? hasCloudCredentials,
    bool? autoSyncOnStartup,
    GalleryBlacklistSyncPhase? syncPhase,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    String? lastSyncError,
    bool clearLastSyncError = false,
    int? revision,
    bool? isInitialized,
    bool? canUndo,
  }) {
    return OnlineGalleryBlacklistState(
      tags: tags ?? this.tags,
      tombstones: tombstones ?? this.tombstones,
      remoteTags: remoteTags ?? this.remoteTags,
      opaqueRemoteRules: opaqueRemoteRules ?? this.opaqueRemoteRules,
      currentAccountKey: clearCurrentAccountKey
          ? null
          : (currentAccountKey ?? this.currentAccountKey),
      isCloudAvailable: isCloudAvailable ?? this.isCloudAvailable,
      hasCloudCredentials: hasCloudCredentials ?? this.hasCloudCredentials,
      autoSyncOnStartup: autoSyncOnStartup ?? this.autoSyncOnStartup,
      syncPhase: syncPhase ?? this.syncPhase,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
      revision: revision ?? this.revision,
      isInitialized: isInitialized ?? this.isInitialized,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

class OnlineGalleryBlacklistNotifier
    extends StateNotifier<OnlineGalleryBlacklistState> {
  OnlineGalleryBlacklistNotifier(this._ref, this._storage, this._repository)
    : super(const OnlineGalleryBlacklistState()) {
    _ref.listen<DanbooruAuthState>(danbooruAuthProvider, _handleAuthChanged);
    _ref.onDispose(_dispose);
    _initFuture = _loadFromStorage();
  }

  static const Duration _startupSyncMinInterval = Duration(minutes: 30);
  static const Duration _authWaitStep = Duration(milliseconds: 500);
  static const int _authWaitMaxRounds = 24;

  final Ref _ref;
  final LocalStorageService _storage;
  final OnlineGalleryBlacklistRepository _repository;
  late GalleryBlacklistStore _store;
  late final Future<void> _initFuture;
  Future<void> _mutationQueue = Future<void>.value();
  GalleryBlacklistUndo? _undo;
  Timer? _incrementalSyncDebounce;
  bool _incrementalSyncRequested = false;
  CancelToken? _remoteCancelToken;
  int _remoteGeneration = 0;

  Future<void> _loadFromStorage() async {
    _store = _repository.load();
    final autoSync =
        _storage.getSetting<bool>(
          StorageKeys.onlineGalleryBlacklistAutoSync,
          defaultValue: true,
        ) ??
        true;
    final auth = _ref.read(danbooruAuthProvider);
    final accountKey = _accountKey(auth);
    final snapshot = accountKey == null
        ? null
        : _store.remoteSnapshots[accountKey];
    state = OnlineGalleryBlacklistState(
      tags: immutableTagSet(_store.desiredTags),
      tombstones: immutableTagSet(_store.tombstones),
      remoteTags: immutableTagSet(snapshot?.simpleTags ?? const {}),
      opaqueRemoteRules: List.unmodifiable(snapshot?.opaqueRules ?? const []),
      currentAccountKey: accountKey,
      isCloudAvailable: auth.isLoggedIn,
      hasCloudCredentials: auth.credentials != null,
      autoSyncOnStartup: autoSync,
      lastSyncAt: snapshot?.lastSyncAt,
      lastSyncError: snapshot?.lastError,
      revision: _store.revision,
      isInitialized: true,
    );
    if (_store.desiredTags.isNotEmpty ||
        _store.tombstones.isNotEmpty ||
        _store.pendingRemoteDeletions.isNotEmpty ||
        _store.remoteSnapshots.isNotEmpty ||
        _store.legacyUnscopedRules.isNotEmpty ||
        _store.legacyUnscopedLastSyncAt != null) {
      await _repository.save(_store);
    }
  }

  Future<void> ensureInitialized() => _initFuture;

  Future<bool> addTag(String input) async {
    final normalized = GalleryBlacklistTagNormalizer.normalize(input);
    if (normalized == null) return false;
    return _enqueueMutation(() async {
      if (_store.desiredTags.contains(normalized)) return false;
      _captureUndo();
      await _replaceDesired(
        {..._store.desiredTags, normalized},
        {..._store.tombstones}..remove(normalized),
        pendingRemoteDeletions: {..._store.pendingRemoteDeletions}
          ..remove(normalized),
      );
      _scheduleIncrementalSync();
      return true;
    });
  }

  @Deprecated('Use addTag; the unified blacklist has no separate local list.')
  Future<bool> addLocalTag(String input) => addTag(input);

  Future<bool> removeTag(String input) async {
    final normalized = GalleryBlacklistTagNormalizer.normalize(input);
    if (normalized == null) return false;
    return _enqueueMutation(() async {
      if (!_store.desiredTags.contains(normalized)) return false;
      _captureUndo();
      await _replaceDesired(
        {..._store.desiredTags}..remove(normalized),
        {..._store.tombstones, normalized},
        pendingRemoteDeletions: {..._store.pendingRemoteDeletions, normalized},
      );
      _scheduleIncrementalSync();
      return true;
    });
  }

  @Deprecated(
    'Use removeTag; the unified blacklist has no separate local list.',
  )
  Future<bool> removeLocalTag(String input) => removeTag(input);

  Future<int> importTags(Iterable<String> inputs) async {
    final normalized = GalleryBlacklistTagNormalizer.normalizeAll(inputs);
    return _enqueueMutation(() async {
      final additions = normalized.difference(_store.desiredTags);
      if (additions.isEmpty) return 0;
      _captureUndo();
      await _replaceDesired(
        {..._store.desiredTags, ...additions},
        {..._store.tombstones}..removeAll(additions),
        pendingRemoteDeletions: {..._store.pendingRemoteDeletions}
          ..removeAll(additions),
      );
      _scheduleIncrementalSync();
      return additions.length;
    });
  }

  Future<bool> clearTags() async {
    return _enqueueMutation(() async {
      if (_store.desiredTags.isEmpty) return false;
      _captureUndo();
      await _replaceDesired(const {}, {
        ..._store.tombstones,
        ..._store.desiredTags,
      }, pendingRemoteDeletions: _store.pendingRemoteDeletions);
      _incrementalSyncDebounce?.cancel();
      _incrementalSyncRequested = false;
      return true;
    });
  }

  @Deprecated(
    'Use clearTags; the unified blacklist has no separate local list.',
  )
  Future<bool> clearLocalTags() => clearTags();

  Future<bool> undoLastMutation() async {
    return _enqueueMutation(() async {
      final undo = _undo;
      if (undo == null) return false;
      _undo = null;
      final removedByUndo = _store.desiredTags.difference(undo.desiredTags);
      final restoredByUndo = undo.desiredTags.difference(_store.desiredTags);
      final remotelyVisibleRemoved = undo.syncCompensation
          ? removedByUndo.where(
              (tag) => _store.remoteSnapshots.values.any(
                (snapshot) => snapshot.simpleTags.contains(tag),
              ),
            )
          : const <String>[];
      await _replaceDesired(
        undo.desiredTags,
        {...undo.tombstones, ...remotelyVisibleRemoved}
          ..removeAll(restoredByUndo),
        pendingRemoteDeletions: {
          ...undo.pendingRemoteDeletions,
          ...remotelyVisibleRemoved,
        }..removeAll(restoredByUndo),
        canUndo: false,
      );
      if (undo.syncCompensation) _scheduleIncrementalSync();
      return true;
    });
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
    final auth = await _waitAuthReadyForStartup();
    if (!auth.isLoggedIn) return;
    final hasRelevantPendingDeletion =
        _store.pendingRemoteDeletions.any(state.remoteTags.contains) ||
        (state.lastSyncAt == null && _store.pendingRemoteDeletions.isNotEmpty);
    final shouldReconcile =
        state.lastSyncError != null || hasRelevantPendingDeletion;
    if (!shouldReconcile) {
      if (state.lastSyncAt case final lastSyncAt?) {
        if (DateTime.now().difference(lastSyncAt) < _startupSyncMinInterval) {
          return;
        }
      }
    }
    final result = await pullFromCloud(background: true);
    if (result != null && shouldReconcile) _scheduleIncrementalSync();
  }

  Future<GalleryBlacklistPullResult?> pullFromCloud({
    bool background = false,
  }) async {
    await ensureInitialized();
    final operation = _beginRemoteOperation(GalleryBlacklistSyncPhase.pulling);
    if (operation == null) return null;
    final (generation, accountKey, cancelToken) = operation;
    try {
      final rules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules(cancelToken: cancelToken);
      if (!_isCurrentRemoteOperation(generation, accountKey)) return null;

      final snapshot = GalleryBlacklistRemoteSnapshot(
        accountKey: accountKey,
        rules: List.unmodifiable(rules),
        lastSyncAt: DateTime.now(),
      );
      return _enqueueMutation(() async {
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        final remoteSimple = snapshot.simpleTags;
        final additions = remoteSimple
            .difference(_store.desiredTags)
            .difference(_store.tombstones);
        final existing = remoteSimple.intersection(_store.desiredTags);
        final skipped = remoteSimple.intersection(_store.tombstones);
        if (additions.isNotEmpty) {
          _undo = GalleryBlacklistUndo(
            desiredTags: immutableTagSet(_store.desiredTags),
            tombstones: immutableTagSet({..._store.tombstones, ...additions}),
            pendingRemoteDeletions: immutableTagSet(
              _store.pendingRemoteDeletions,
            ),
            syncCompensation: false,
          );
        }

        final snapshots = {..._store.remoteSnapshots, accountKey: snapshot};
        final next = _store.copyWith(
          revision: _store.revision + (additions.isEmpty ? 0 : 1),
          desiredTags: immutableTagSet({..._store.desiredTags, ...additions}),
          pendingRemoteDeletions: immutableTagSet({
            ..._store.pendingRemoteDeletions,
            ...skipped,
          }),
          remoteSnapshots: Map.unmodifiable(snapshots),
        );
        await _persistStore(next);
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        _applyStore(
          syncPhase: GalleryBlacklistSyncPhase.idle,
          canUndo: additions.isNotEmpty || state.canUndo,
        );
        return GalleryBlacklistPullResult(
          addedCount: additions.length,
          existingCount: existing.length,
          skippedDeletedCount: skipped.length,
          opaqueRuleCount: snapshot.opaqueRules.length,
        );
      });
    } on DioException catch (error, stack) {
      if (CancelToken.isCancel(error)) return null;
      if (_isCurrentRemoteOperation(generation, accountKey)) {
        await _recordSyncFailure(error, stack, background: background);
      }
      return null;
    } catch (error, stack) {
      if (_isCurrentRemoteOperation(generation, accountKey)) {
        await _recordSyncFailure(error, stack, background: background);
      }
      return null;
    } finally {
      _completeRemoteOperation(generation, accountKey);
    }
  }

  Future<GalleryBlacklistPushPreview?> preparePushToCloud() async {
    await ensureInitialized();
    final operation = _beginRemoteOperation(
      GalleryBlacklistSyncPhase.preparingPush,
    );
    if (operation == null) return null;
    final (generation, accountKey, cancelToken) = operation;
    try {
      final rules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules(cancelToken: cancelToken);
      if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
      final snapshot = GalleryBlacklistRemoteSnapshot(
        accountKey: accountKey,
        rules: List.unmodifiable(rules),
        lastSyncAt: DateTime.now(),
      );
      return _enqueueMutation(() async {
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        await _persistRemoteSnapshot(snapshot);
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        _applyStore(syncPhase: GalleryBlacklistSyncPhase.idle);
        return GalleryBlacklistPushPreview(
          accountKey: accountKey,
          localRevision: _store.revision,
          remoteRules: rules,
          targetSimpleTagCount: _store.desiredTags.length,
          addedTags: immutableTagSet(
            _store.desiredTags.difference(snapshot.simpleTags),
          ),
          removedTags: immutableTagSet(
            snapshot.simpleTags.difference(_store.desiredTags),
          ),
          opaqueRulesToRemove: List.unmodifiable(snapshot.opaqueRules),
          containsLegacyUnscopedData: _store.legacyUnscopedRules.isNotEmpty,
        );
      });
    } catch (error, stack) {
      if (_isCurrentRemoteOperation(generation, accountKey)) {
        await _recordSyncFailure(error, stack);
      }
      return null;
    } finally {
      _completeRemoteOperation(generation, accountKey);
    }
  }

  Future<bool> pushToCloud(
    GalleryBlacklistPushPreview preview, {
    required bool confirmEmptyReplacement,
    required bool confirmLegacyMigration,
  }) async {
    await ensureInitialized();
    if ((preview.requiresEmptyConfirmation && !confirmEmptyReplacement) ||
        (preview.containsLegacyUnscopedData && !confirmLegacyMigration)) {
      await _setSyncError('Required cloud replacement confirmation is missing');
      return false;
    }
    if (preview.accountKey != state.currentAccountKey ||
        preview.localRevision != _store.revision) {
      await _setSyncError('Blacklist changed; review the cloud diff again');
      return false;
    }
    final operation = _beginRemoteOperation(GalleryBlacklistSyncPhase.pushing);
    if (operation == null) return false;
    final (generation, accountKey, cancelToken) = operation;
    final targetTags = immutableTagSet(_store.desiredTags);
    final targetRevision = _store.revision;
    final desired = targetTags.toList()..sort();
    var cloudWriteVerified = false;
    try {
      final latestRules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules(cancelToken: cancelToken);
      if (!_isCurrentRemoteOperation(generation, accountKey)) return false;
      if (!_listEquals(latestRules, preview.remoteRules)) {
        throw StateError('Cloud blacklist changed; review the diff again');
      }

      // Once the write starts, cancellation cannot honestly guarantee rollback.
      await _ref
          .read(danbooruApiServiceProvider)
          .updateBlacklistRules(
            desired,
            expectedUserId: _danbooruUserId(accountKey),
          );
      if (!_isCurrentRemoteOperation(generation, accountKey)) return false;
      state = state.copyWith(syncPhase: GalleryBlacklistSyncPhase.verifying);
      final verifiedRules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules();
      if (!_isCurrentRemoteOperation(generation, accountKey)) return false;
      final verified = GalleryBlacklistRemoteSnapshot(
        accountKey: accountKey,
        rules: List.unmodifiable(verifiedRules),
        lastSyncAt: DateTime.now(),
      );
      if (verified.opaqueRules.isNotEmpty ||
          !_setEquals(verified.simpleTags, targetTags)) {
        throw StateError('Danbooru blacklist verification mismatch');
      }
      cloudWriteVerified = true;
      await _enqueueMutation(() async {
        if (!_isCurrentRemoteOperation(generation, accountKey)) return;
        await _persistVerifiedSnapshot(verified);
        if (!_isCurrentRemoteOperation(generation, accountKey)) return;
        _applyStore(syncPhase: GalleryBlacklistSyncPhase.idle);
      });
      if (!_isCurrentRemoteOperation(generation, accountKey)) return false;
      if (_store.revision != targetRevision) _scheduleIncrementalSync();
      return true;
    } catch (error, stack) {
      if (_isCurrentRemoteOperation(generation, accountKey)) {
        if (cloudWriteVerified) {
          _recordVerifiedCloudPersistenceFailure(error, stack);
          return true;
        }
        await _recordSyncFailure(error, stack);
      }
      return false;
    } finally {
      _completeRemoteOperation(generation, accountKey);
    }
  }

  void cancelSync() {
    if (_remoteCancelToken case final token? when !token.isCancelled) {
      token.cancel('Blacklist sync cancelled');
    }
  }

  void _handleAuthChanged(DanbooruAuthState? previous, DanbooruAuthState next) {
    final previousKey = _accountKey(previous);
    final nextKey = _accountKey(next);
    if (previousKey != nextKey) {
      _remoteGeneration++;
      _remoteCancelToken?.cancel('Danbooru account changed');
      _incrementalSyncDebounce?.cancel();
    }
    if (!state.isInitialized) return;
    final snapshot = nextKey == null ? null : _store.remoteSnapshots[nextKey];
    state = state.copyWith(
      currentAccountKey: nextKey,
      clearCurrentAccountKey: nextKey == null,
      isCloudAvailable: next.isLoggedIn,
      hasCloudCredentials: next.credentials != null,
      remoteTags: immutableTagSet(snapshot?.simpleTags ?? const {}),
      opaqueRemoteRules: List.unmodifiable(snapshot?.opaqueRules ?? const []),
      lastSyncAt: snapshot?.lastSyncAt,
      clearLastSyncAt: snapshot == null,
      lastSyncError: snapshot?.lastError,
      clearLastSyncError: snapshot?.lastError == null,
      syncPhase: GalleryBlacklistSyncPhase.idle,
    );
    _resumeRequestedIncrementalSync();
  }

  String? _accountKey(DanbooruAuthState? auth) {
    final user = auth?.user;
    return user == null ? null : 'danbooru:${user.id}';
  }

  Future<DanbooruAuthState> _waitAuthReadyForStartup() async {
    var auth = _ref.read(danbooruAuthProvider);
    for (var i = 0; i < _authWaitMaxRounds && auth.isLoading; i++) {
      await Future<void>.delayed(_authWaitStep);
      auth = _ref.read(danbooruAuthProvider);
    }
    return auth;
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() action) async {
    await ensureInitialized();
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  void _captureUndo() {
    _undo = GalleryBlacklistUndo(
      desiredTags: immutableTagSet(_store.desiredTags),
      tombstones: immutableTagSet(_store.tombstones),
      pendingRemoteDeletions: immutableTagSet(_store.pendingRemoteDeletions),
    );
  }

  Future<void> _replaceDesired(
    Set<String> desiredTags,
    Set<String> tombstones, {
    Set<String>? pendingRemoteDeletions,
    bool canUndo = true,
  }) async {
    await _persistStore(
      _store.copyWith(
        revision: _store.revision + 1,
        desiredTags: immutableTagSet(desiredTags),
        tombstones: immutableTagSet(tombstones),
        pendingRemoteDeletions: immutableTagSet(
          pendingRemoteDeletions ?? _store.pendingRemoteDeletions,
        ),
      ),
    );
    _applyStore(canUndo: canUndo);
  }

  Future<void> _persistStore(GalleryBlacklistStore next) async {
    await _repository.save(next);
    _store = next;
  }

  Future<void> _persistRemoteSnapshot(
    GalleryBlacklistRemoteSnapshot snapshot,
  ) async {
    await _persistStore(
      _store.copyWith(
        remoteSnapshots: Map.unmodifiable({
          ..._store.remoteSnapshots,
          snapshot.accountKey: snapshot,
        }),
      ),
    );
  }

  Future<void> _persistVerifiedSnapshot(
    GalleryBlacklistRemoteSnapshot snapshot,
  ) async {
    await _persistStore(
      _store.copyWith(
        tombstones: immutableTagSet(_store.tombstones),
        // Keep explicit single-tag deletion intents until a local re-add.
        // Accounts discovered later must honor the same unified blacklist.
        pendingRemoteDeletions: immutableTagSet(_store.pendingRemoteDeletions),
        remoteSnapshots: Map.unmodifiable({
          ..._store.remoteSnapshots,
          snapshot.accountKey: snapshot,
        }),
        legacyUnscopedRules: const [],
        clearLegacyUnscopedLastSyncAt: true,
      ),
    );
  }

  void _applyStore({GalleryBlacklistSyncPhase? syncPhase, bool? canUndo}) {
    final accountKey = state.currentAccountKey;
    final snapshot = accountKey == null
        ? null
        : _store.remoteSnapshots[accountKey];
    state = state.copyWith(
      tags: immutableTagSet(_store.desiredTags),
      tombstones: immutableTagSet(_store.tombstones),
      remoteTags: immutableTagSet(snapshot?.simpleTags ?? const {}),
      opaqueRemoteRules: List.unmodifiable(snapshot?.opaqueRules ?? const []),
      lastSyncAt: snapshot?.lastSyncAt,
      clearLastSyncAt: snapshot == null,
      lastSyncError: snapshot?.lastError,
      clearLastSyncError: snapshot?.lastError == null,
      revision: _store.revision,
      syncPhase: syncPhase,
      canUndo: canUndo ?? _undo != null,
    );
  }

  (int, String, CancelToken)? _beginRemoteOperation(
    GalleryBlacklistSyncPhase phase,
  ) {
    final auth = _ref.read(danbooruAuthProvider);
    final accountKey = _accountKey(auth);
    if (!auth.isLoggedIn ||
        accountKey == null ||
        accountKey != state.currentAccountKey ||
        state.isSyncing) {
      return null;
    }
    _remoteGeneration++;
    _remoteCancelToken?.cancel('Superseded blacklist sync');
    final token = CancelToken();
    _remoteCancelToken = token;
    state = state.copyWith(syncPhase: phase, clearLastSyncError: true);
    return (_remoteGeneration, accountKey, token);
  }

  bool _isCurrentRemoteOperation(int generation, String accountKey) {
    return mounted &&
        generation == _remoteGeneration &&
        accountKey == state.currentAccountKey;
  }

  void _completeRemoteOperation(int generation, String accountKey) {
    if (_isCurrentRemoteOperation(generation, accountKey) && state.isSyncing) {
      state = state.copyWith(syncPhase: GalleryBlacklistSyncPhase.idle);
    }
    _resumeRequestedIncrementalSync();
  }

  void _resumeRequestedIncrementalSync() {
    if (_incrementalSyncRequested && !state.isSyncing) {
      _scheduleIncrementalSync();
    }
  }

  void _scheduleIncrementalSync() {
    _incrementalSyncRequested = true;
    _incrementalSyncDebounce?.cancel();
    if (_store.desiredTags.isEmpty && _store.pendingRemoteDeletions.isEmpty) {
      _incrementalSyncRequested = false;
      return;
    }
    if (!state.isCloudAvailable ||
        state.isSyncing ||
        _store.legacyUnscopedRules.isNotEmpty) {
      return;
    }
    _incrementalSyncDebounce = Timer(const Duration(milliseconds: 500), () {
      _incrementalSyncDebounce = null;
      unawaited(_syncIncrementally());
    });
  }

  Future<void> _syncIncrementally() async {
    final operation = _beginRemoteOperation(GalleryBlacklistSyncPhase.pushing);
    if (operation == null) return;
    _incrementalSyncRequested = false;
    final (generation, accountKey, cancelToken) = operation;
    var cloudWriteVerified = false;
    try {
      final latestRules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules(cancelToken: cancelToken);
      if (!_isCurrentRemoteOperation(generation, accountKey)) return;
      final latest = GalleryBlacklistRemoteSnapshot(
        accountKey: accountKey,
        rules: List.unmodifiable(latestRules),
        lastSyncAt: DateTime.now(),
      );
      final target = await _enqueueMutation(() async {
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        final next = _store.copyWith(
          remoteSnapshots: Map.unmodifiable({
            ..._store.remoteSnapshots,
            accountKey: latest,
          }),
        );
        await _persistStore(next);
        if (!_isCurrentRemoteOperation(generation, accountKey)) return null;
        _applyStore();
        final targetTags = <String>{...latest.simpleTags, ..._store.desiredTags}
          ..removeAll(_store.pendingRemoteDeletions);
        return (immutableTagSet(targetTags), _store.revision);
      });
      if (target == null) return;
      final (targetTags, targetRevision) = target;
      final targetRules = _mergeRulesPreservingOpaque(latest.rules, targetTags);
      await _ref
          .read(danbooruApiServiceProvider)
          .updateBlacklistRules(
            targetRules,
            expectedUserId: _danbooruUserId(accountKey),
          );
      if (!_isCurrentRemoteOperation(generation, accountKey)) return;
      state = state.copyWith(syncPhase: GalleryBlacklistSyncPhase.verifying);
      final verifiedRules = await _ref
          .read(danbooruApiServiceProvider)
          .fetchBlacklistRules();
      if (!_isCurrentRemoteOperation(generation, accountKey)) return;
      final verified = GalleryBlacklistRemoteSnapshot(
        accountKey: accountKey,
        rules: List.unmodifiable(verifiedRules),
        lastSyncAt: DateTime.now(),
      );
      final expectedOpaque = latest.opaqueRules;
      if (!_setEquals(verified.simpleTags, targetTags) ||
          !_listEquals(verified.opaqueRules, expectedOpaque)) {
        throw StateError('Danbooru blacklist verification mismatch');
      }
      cloudWriteVerified = true;
      await _enqueueMutation(() async {
        if (!_isCurrentRemoteOperation(generation, accountKey)) return;
        await _persistVerifiedSnapshot(verified);
        if (!_isCurrentRemoteOperation(generation, accountKey)) return;
        _applyStore(syncPhase: GalleryBlacklistSyncPhase.idle);
      });
      if (_isCurrentRemoteOperation(generation, accountKey) &&
          _store.revision != targetRevision) {
        _scheduleIncrementalSync();
      }
    } catch (error, stack) {
      if (_isCurrentRemoteOperation(generation, accountKey)) {
        if (cloudWriteVerified) {
          _recordVerifiedCloudPersistenceFailure(error, stack);
        } else {
          await _recordSyncFailure(error, stack, background: true);
        }
      }
    } finally {
      _completeRemoteOperation(generation, accountKey);
    }
  }

  List<String> _mergeRulesPreservingOpaque(
    List<String> remoteRules,
    Set<String> desired,
  ) {
    final output = <String>[];
    final emitted = <String>{};
    for (final rule in remoteRules) {
      final simple = GalleryBlacklistTagNormalizer.simpleCloudRule(rule);
      if (simple == null) {
        output.add(rule);
      } else if (desired.contains(simple) && emitted.add(simple)) {
        output.add(simple);
      }
    }
    final remaining = desired.difference(emitted).toList()..sort();
    output.addAll(remaining);
    return output;
  }

  void _recordVerifiedCloudPersistenceFailure(Object error, StackTrace stack) {
    final message =
        'Cloud blacklist was updated, but local sync status could not be saved: '
        '$error';
    AppLogger.e(
      'Failed to persist verified cloud blacklist state',
      error,
      stack,
      'OnlineGalleryBlacklist',
    );
    if (mounted) {
      state = state.copyWith(lastSyncError: message);
    }
  }

  Future<void> _recordSyncFailure(
    Object error,
    StackTrace stack, {
    bool background = false,
  }) async {
    AppLogger.w('Blacklist sync failed: $error', 'OnlineGalleryBlacklist');
    AppLogger.d('$stack', 'OnlineGalleryBlacklist');
    await _setSyncError('$error');
    if (!background) {
      state = state.copyWith(syncPhase: GalleryBlacklistSyncPhase.idle);
    }
  }

  Future<void> _setSyncError(String message) async {
    final accountKey = state.currentAccountKey;
    if (accountKey != null) {
      try {
        await _enqueueMutation(() async {
          if (state.currentAccountKey != accountKey) return;
          final snapshot = _store.remoteSnapshots[accountKey];
          if (snapshot != null) {
            await _persistRemoteSnapshot(snapshot.copyWith(lastError: message));
          }
        });
      } catch (error, stack) {
        AppLogger.e(
          'Failed to persist blacklist sync error',
          error,
          stack,
          'OnlineGalleryBlacklist',
        );
      }
    }
    if (mounted && state.currentAccountKey == accountKey) {
      state = state.copyWith(
        syncPhase: GalleryBlacklistSyncPhase.idle,
        lastSyncError: message,
      );
    }
  }

  int _danbooruUserId(String accountKey) {
    final userId = int.tryParse(accountKey.split(':').last);
    if (userId == null) {
      throw StateError('Invalid Danbooru blacklist account key: $accountKey');
    }
    return userId;
  }

  bool _setEquals(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void _dispose() {
    _incrementalSyncDebounce?.cancel();
    _remoteCancelToken?.cancel('Blacklist notifier disposed');
  }
}

final onlineGalleryBlacklistNotifierProvider =
    StateNotifierProvider<
      OnlineGalleryBlacklistNotifier,
      OnlineGalleryBlacklistState
    >((ref) {
      return OnlineGalleryBlacklistNotifier(
        ref,
        ref.read(localStorageServiceProvider),
        ref.read(onlineGalleryBlacklistRepositoryProvider),
      );
    });
