import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'gallery_image_request.dart';

typedef GalleryImagePreloader =
    GalleryImagePreloadOperation Function(GalleryImageRequest request);

class GalleryImagePreloadOperation {
  GalleryImagePreloadOperation({
    required this.future,
    required void Function() cancel,
  }) : _cancel = cancel;

  factory GalleryImagePreloadOperation.fromFuture(Future<void> future) =>
      GalleryImagePreloadOperation(future: future, cancel: () {});

  final Future<void> future;
  final void Function() _cancel;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

enum GalleryPrefetchPauseReason {
  scrolling,
  pageHidden,
  appBackground,
  criticalNetworkActivity,
}

class OnlineGalleryPrefetchCoordinator extends ChangeNotifier {
  OnlineGalleryPrefetchCoordinator({
    required GalleryImagePreloader preloader,
    this.maxConcurrent = 4,
    this.maxQueued = 64,
    DateTime Function()? now,
  }) : assert(maxConcurrent > 0),
       _preloader = preloader,
       _now = now ?? DateTime.now;

  final GalleryImagePreloader _preloader;
  final int maxConcurrent;
  final int maxQueued;
  final DateTime Function() _now;
  final Map<GalleryImagePriority, ListQueue<_PrefetchTask>> _queues = {
    for (final priority in GalleryImagePriority.values)
      priority: ListQueue<_PrefetchTask>(),
  };
  final Map<String, _PrefetchTask> _pending = {};
  final Map<String, _PrefetchTask> _inFlight = {};
  final LinkedHashMap<String, DateTime> _completedThumbnails = LinkedHashMap();
  final LinkedHashMap<String, DateTime> _completedSamples = LinkedHashMap();
  final LinkedHashMap<String, DateTime> _failures = LinkedHashMap();
  final Set<GalleryPrefetchPauseReason> _pauseReasons = {};

  int _generation = 0;
  int _active = 0;
  int _interactiveStreak = 0;
  bool _notificationScheduled = false;
  bool _disposed = false;
  int debugRequestCount = 0;
  int debugDeduplicatedCount = 0;
  int debugCancelledCount = 0;
  int debugNegativeCacheHitCount = 0;

  int get generation => _generation;
  int get activeCount => _active;
  int get queueDepth => _pending.length;
  bool get isPaused => _pauseReasons.isNotEmpty;
  bool get isScrollingPaused =>
      _pauseReasons.contains(GalleryPrefetchPauseReason.scrolling);
  bool get isDisposed => _disposed;
  Set<GalleryPrefetchPauseReason> get pauseReasons =>
      Set.unmodifiable(_pauseReasons);

  String _completionKey(
    GalleryImageRequest request, [
    GalleryImageTier? tier,
  ]) => '${request.transportKey}:${(tier ?? request.tier).name}';

  String _taskKey(GalleryImageRequest request) =>
      request.tier == GalleryImageTier.original
      ? request.stableRequestKey
      : _completionKey(request);

  String retentionKeyFor(GalleryImageRequest request) => _taskKey(request);

  bool isSampleReady(GalleryImageRequest request) =>
      _completedSamples.containsKey(_completionKey(request));

  bool isReady(GalleryImageRequest request) => switch (request.tier) {
    GalleryImageTier.thumbnail => _completedThumbnails.containsKey(
      _completionKey(request),
    ),
    GalleryImageTier.sample => isSampleReady(request),
    GalleryImageTier.original => false,
  };

  /// Forgets cached transport readiness after Flutter reports invalid bytes.
  void invalidateCompleted(GalleryImageRequest request) {
    _completedThumbnails.remove(
      _completionKey(request, GalleryImageTier.thumbnail),
    );
    _completedSamples.remove(_completionKey(request, GalleryImageTier.sample));
  }

  bool isNegativelyCached(GalleryImageRequest request) {
    final failedAt = _failures[request.stableRequestKey];
    if (failedAt == null) return false;
    if (_now().difference(failedAt) >= const Duration(seconds: 15)) {
      _failures.remove(request.stableRequestKey);
      return false;
    }
    return true;
  }

  void rotateGeneration() {
    if (_disposed) return;
    _generation++;
    _cancelWhere((_) => true, reason: 'generation-rotated');
    _scheduleNotification();
  }

  void setScrolling(bool scrolling) => _setPause(
    GalleryPrefetchPauseReason.scrolling,
    scrolling,
    // A running transfer is reusable disk-cache work. Scrolling only blocks
    // new lookahead starts; the moving window may evict stale queued work.
    cancelPriorities: const {},
  );

  void setPageVisible(bool visible) => _setPause(
    GalleryPrefetchPauseReason.pageHidden,
    !visible,
    cancelPriorities: GalleryImagePriority.values.toSet(),
  );

  void setAppForeground(bool foreground) => _setPause(
    GalleryPrefetchPauseReason.appBackground,
    !foreground,
    cancelPriorities: GalleryImagePriority.values.toSet(),
  );

  void setCriticalNetworkActive(bool active) => _setPause(
    GalleryPrefetchPauseReason.criticalNetworkActivity,
    active,
    cancelPriorities: const {
      GalleryImagePriority.visible,
      GalleryImagePriority.hover,
      GalleryImagePriority.lookahead,
    },
  );

  /// Cancels queued work for a card that left the active viewport window.
  /// Downloads already handed to the image pipeline are allowed to finish so
  /// the shared disk cache is not left with a partially consumed response.
  void cancelPending(GalleryImageRequest request) {
    final key = _taskKey(request);
    final task = _pending[key];
    if (task == null) return;
    task.coordinatorOwned = false;
    if (task.consumers.isNotEmpty) return;
    _pending.remove(key);
    _removeFromQueue(task);
    _completeCancelled(task);
    _scheduleNotification();
  }

  /// Releases one widget's interest without cancelling a request still used
  /// by another card or by the moving prefetch window.
  void releasePending(GalleryImageRequest request, Object consumer) {
    final key = _taskKey(request);
    final task = _pending[key];
    if (task == null || !task.consumers.remove(consumer)) return;
    if (task.coordinatorOwned || task.consumers.isNotEmpty) return;
    _pending.remove(key);
    _removeFromQueue(task);
    _completeCancelled(task);
    _scheduleNotification();
  }

  /// Keeps the moving thumbnail window bounded while a user scrolls through
  /// many rows faster than the network can consume them.
  void retainThumbnailWindow(Set<String> retentionKeys) {
    final stale = _pending.values
        .where(
          (task) =>
              task.request.tier == GalleryImageTier.thumbnail &&
              (task.priority == GalleryImagePriority.visible ||
                  task.priority == GalleryImagePriority.lookahead) &&
              !retentionKeys.contains(_taskKey(task.request)),
        )
        .toList(growable: false);
    var cancelled = false;
    for (final task in stale) {
      task.coordinatorOwned = false;
      if (task.consumers.isNotEmpty) continue;
      _pending.remove(_taskKey(task.request));
      _removeFromQueue(task);
      _completeCancelled(task);
      cancelled = true;
    }
    if (cancelled) _scheduleNotification();
  }

  Future<bool> submit(
    GalleryImageRequest request, {
    required GalleryImagePriority priority,
    bool retry = false,
    Object? consumer,
  }) {
    if (_disposed || !_accepts(priority)) return Future.value(false);
    if (retry) {
      final key = request.stableRequestKey;
      _failures.remove(key);
      _completedThumbnails.remove(_completionKey(request));
      _completedSamples.remove(_completionKey(request));
    }
    if (!retry && isNegativelyCached(request)) {
      debugNegativeCacheHitCount++;
      return Future.value(false);
    }
    if (isReady(request)) {
      return Future.value(true);
    }
    final key = _taskKey(request);
    final existing = _pending[key] ?? _inFlight[key];
    if (existing != null && !existing.cancelled) {
      if (consumer == null) {
        existing.coordinatorOwned = true;
      } else {
        existing.consumers.add(consumer);
      }
      debugDeduplicatedCount++;
      if (_pending[key] != null && priority.index < existing.priority.index) {
        _queues[existing.priority]!.remove(existing);
        existing.priority = priority;
        _queues[priority]!.add(existing);
      }
      return existing.completer.future;
    }

    if (_pending.length >= maxQueued && !_makeRoomFor(priority)) {
      return Future<bool>.value(false);
    }

    final task = _PrefetchTask(
      request: request,
      priority: priority,
      generation: _generation,
      coordinatorOwned: consumer == null,
    );
    if (consumer != null) task.consumers.add(consumer);
    _pending[key] = task;
    _queues[priority]!.add(task);
    _pump();
    return task.completer.future;
  }

  void cancel(
    GalleryImageRequest request, {
    GalleryImagePriority? priority,
    String reason = 'request-cancelled',
  }) {
    if (_disposed) return;
    final key = _taskKey(request);
    _cancelWhere(
      (task) =>
          _taskKey(task.request) == key &&
          (priority == null || task.priority == priority),
      reason: reason,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelWhere((_) => true, reason: 'disposed');
    _completedThumbnails.clear();
    _completedSamples.clear();
    _failures.clear();
    super.dispose();
  }

  void _setPause(
    GalleryPrefetchPauseReason reason,
    bool paused, {
    required Set<GalleryImagePriority> cancelPriorities,
  }) {
    if (_disposed) return;
    final changed = paused
        ? _pauseReasons.add(reason)
        : _pauseReasons.remove(reason);
    if (!changed) return;
    if (paused) {
      _cancelWhere(
        (task) => cancelPriorities.contains(task.priority),
        reason: reason.name,
      );
    } else {
      _pump();
    }
    _scheduleNotification();
    AppLogger.d(
      'Gallery prefetch ${paused ? 'paused' : 'resumed'}: '
          'reason=${reason.name}, queue=$queueDepth, active=$activeCount, '
          'reasons=${_pauseReasons.map((value) => value.name).join(',')}',
      'GalleryPrefetch',
    );
  }

  bool _accepts(GalleryImagePriority priority) {
    if (_pauseReasons.contains(GalleryPrefetchPauseReason.pageHidden) ||
        _pauseReasons.contains(GalleryPrefetchPauseReason.appBackground)) {
      return false;
    }
    if (_pauseReasons.contains(
          GalleryPrefetchPauseReason.criticalNetworkActivity,
        ) &&
        priority != GalleryImagePriority.interactiveDetail) {
      return false;
    }
    if (_pauseReasons.contains(GalleryPrefetchPauseReason.scrolling) &&
        priority == GalleryImagePriority.lookahead) {
      return false;
    }
    return true;
  }

  ListQueue<_PrefetchTask> _queueFor(GalleryImagePriority priority) =>
      _queues[priority]!;

  void _removeFromQueue(_PrefetchTask task) {
    _queueFor(task.priority).remove(task);
  }

  bool _makeRoomFor(GalleryImagePriority incoming) {
    for (final priority in GalleryImagePriority.values.reversed) {
      if (priority.index < incoming.index) continue;
      final queue = _queueFor(priority);
      if (queue.isEmpty) continue;
      final evicted = queue.removeLast();
      _pending.remove(_taskKey(evicted.request));
      _completeCancelled(evicted);
      return true;
    }
    return false;
  }

  void _completeCancelled(_PrefetchTask task) {
    if (!task.completer.isCompleted) task.completer.complete(false);
  }

  _PrefetchTask? _takeNext() {
    final interactive = _queues[GalleryImagePriority.interactiveDetail]!;
    final visible = _queues[GalleryImagePriority.visible]!;
    if (interactive.isNotEmpty && (_interactiveStreak < 3 || visible.isEmpty)) {
      _interactiveStreak++;
      return interactive.removeFirst();
    }
    if (visible.isNotEmpty) {
      _interactiveStreak = 0;
      return visible.removeFirst();
    }
    for (final priority in const [
      GalleryImagePriority.hover,
      GalleryImagePriority.lookahead,
    ]) {
      if (!_accepts(priority)) continue;
      final queue = _queues[priority]!;
      if (queue.isNotEmpty) return queue.removeFirst();
    }
    return null;
  }

  void _pump() {
    if (_disposed) return;
    while (_active < maxConcurrent) {
      final task = _takeNext();
      if (task == null) return;
      final key = _taskKey(task.request);
      if (_pending.remove(key) != task || task.generation != _generation) {
        _completeCancelled(task);
        continue;
      }
      _active++;
      _inFlight[key] = task;
      debugRequestCount++;
      unawaited(_run(task));
    }
  }

  Future<void> _run(_PrefetchTask task) async {
    final taskKey = _taskKey(task.request);
    final failureKey = task.request.stableRequestKey;
    try {
      final operation = _preloader(task.request);
      task.operation = operation;
      if (task.cancelled) operation.cancel();
      await operation.future;
      if (task.cancelled ||
          task.generation != _generation ||
          operation.isCancelled) {
        _completeCancelled(task);
        return;
      }
      _rememberCompleted(task.request);
      if (!task.completer.isCompleted) task.completer.complete(true);
    } catch (error) {
      if (!task.cancelled && task.generation == _generation) {
        _failures.remove(failureKey);
        _failures[failureKey] = _now();
        while (_failures.length > 500) {
          _failures.remove(_failures.keys.first);
        }
        AppLogger.d(
          'Gallery prefetch failed: source=${task.request.sourceKey}, '
              'tier=${task.request.tier.name}, '
              'errorType=${error.runtimeType}',
          'GalleryPrefetch',
        );
      }
      if (!task.completer.isCompleted) task.completer.complete(false);
    } finally {
      if (_inFlight[taskKey] == task) _inFlight.remove(taskKey);
      _active--;
      _pump();
      _scheduleNotification();
    }
  }

  void _cancelWhere(
    bool Function(_PrefetchTask task) predicate, {
    required String reason,
  }) {
    var cancelled = 0;
    var pendingCapacityChanged = false;
    for (final task in _pending.values.toList()) {
      if (!predicate(task)) continue;
      _pending.remove(_taskKey(task.request));
      _queues[task.priority]!.remove(task);
      task.cancelled = true;
      _completeCancelled(task);
      cancelled++;
      pendingCapacityChanged = true;
    }
    for (final task in _inFlight.values.toList()) {
      if (!predicate(task) || task.cancelled) continue;
      task.cancelled = true;
      task.operation?.cancel();
      _completeCancelled(task);
      cancelled++;
    }
    if (cancelled > 0) {
      debugCancelledCount += cancelled;
      if (pendingCapacityChanged) _scheduleNotification();
      AppLogger.d(
        'Gallery prefetch cancelled: reason=$reason, count=$cancelled, '
            'queue=$queueDepth, active=$activeCount',
        'GalleryPrefetch',
      );
    }
  }

  void _scheduleNotification() {
    if (_disposed || _notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _rememberCompleted(GalleryImageRequest request) {
    if (request.tier == GalleryImageTier.original) return;
    final key = _completionKey(request);
    final completed = request.tier == GalleryImageTier.thumbnail
        ? _completedThumbnails
        : _completedSamples;
    final limit = request.tier == GalleryImageTier.thumbnail ? 1000 : 64;
    completed.remove(key);
    completed[key] = _now();
    while (completed.length > limit) {
      completed.remove(completed.keys.first);
    }
  }
}

class _PrefetchTask {
  _PrefetchTask({
    required this.request,
    required this.priority,
    required this.generation,
    required this.coordinatorOwned,
  });

  final GalleryImageRequest request;
  GalleryImagePriority priority;
  final int generation;
  bool coordinatorOwned;
  final Set<Object> consumers = {};
  final Completer<bool> completer = Completer<bool>();
  GalleryImagePreloadOperation? operation;
  bool cancelled = false;
}
