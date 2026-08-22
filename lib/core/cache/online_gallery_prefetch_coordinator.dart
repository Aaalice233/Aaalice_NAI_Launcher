import 'dart:async';
import 'dart:collection';

import 'gallery_image_request.dart';

typedef GalleryImagePreloader =
    Future<void> Function(GalleryImageRequest request);

class OnlineGalleryPrefetchCoordinator {
  OnlineGalleryPrefetchCoordinator({
    required GalleryImagePreloader preloader,
    this.maxConcurrent = 4,
    DateTime Function()? now,
  }) : _preloader = preloader,
       _now = now ?? DateTime.now;

  final GalleryImagePreloader _preloader;
  final int maxConcurrent;
  final DateTime Function() _now;

  final ListQueue<_PrefetchTask> _interactive = ListQueue<_PrefetchTask>();
  final ListQueue<_PrefetchTask> _hover = ListQueue<_PrefetchTask>();
  final ListQueue<_PrefetchTask> _visible = ListQueue<_PrefetchTask>();
  final ListQueue<_PrefetchTask> _lookahead = ListQueue<_PrefetchTask>();
  final Map<String, _PrefetchTask> _pending = <String, _PrefetchTask>{};
  final Map<String, _PrefetchTask> _inFlight = <String, _PrefetchTask>{};
  final LinkedHashMap<String, DateTime> _completedSamples =
      LinkedHashMap<String, DateTime>();
  final LinkedHashMap<String, DateTime> _failures =
      LinkedHashMap<String, DateTime>();

  int _generation = 0;
  int _active = 0;
  bool _lowPriorityPaused = false;

  int get generation => _generation;
  int get activeCount => _active;
  int get queueDepth => _pending.length;
  int debugRequestCount = 0;
  int debugDeduplicatedCount = 0;

  bool isSampleReady(GalleryImageRequest request) =>
      _completedSamples.containsKey(request.stableRequestKey);

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
    _generation++;
    for (final task in _pending.values) {
      if (!task.completer.isCompleted) task.completer.complete(false);
    }
    _pending.clear();
    _interactive.clear();
    _hover.clear();
    _visible.clear();
    _lookahead.clear();
  }

  void setScrolling(bool scrolling) {
    _lowPriorityPaused = scrolling;
    if (!scrolling) _pump();
  }

  Future<bool> submit(
    GalleryImageRequest request, {
    required GalleryImagePriority priority,
    bool retry = false,
  }) {
    if (retry) _failures.remove(request.stableRequestKey);
    if (!retry && isNegativelyCached(request)) {
      return Future<bool>.value(false);
    }
    if (request.tier == GalleryImageTier.sample && isSampleReady(request)) {
      return Future<bool>.value(true);
    }
    final key = request.stableRequestKey;
    final existing = _pending[key];
    if (existing != null) {
      debugDeduplicatedCount++;
      if (priority.index < existing.priority.index) {
        _removeFromQueue(existing);
        existing.priority = priority;
        _queueFor(priority).add(existing);
      }
      return existing.completer.future;
    }
    final active = _inFlight[key];
    if (active != null) {
      debugDeduplicatedCount++;
      if (active.generation == _generation) return active.completer.future;
      final submittedGeneration = _generation;
      return active.downloadCompleter.future.then((downloaded) {
        if (!downloaded || submittedGeneration != _generation) return false;
        if (request.tier == GalleryImageTier.sample) {
          _rememberCompletedSample(key);
        }
        return true;
      });
    }

    final task = _PrefetchTask(
      request: request,
      priority: priority,
      generation: _generation,
    );
    _pending[key] = task;
    _queueFor(priority).add(task);
    _pump();
    return task.completer.future;
  }

  void dispose() {
    rotateGeneration();
    _completedSamples.clear();
    _failures.clear();
  }

  ListQueue<_PrefetchTask> _queueFor(GalleryImagePriority priority) {
    return switch (priority) {
      GalleryImagePriority.interactiveDetail => _interactive,
      GalleryImagePriority.hover => _hover,
      GalleryImagePriority.visible => _visible,
      GalleryImagePriority.lookahead => _lookahead,
    };
  }

  void _removeFromQueue(_PrefetchTask task) {
    _queueFor(task.priority).remove(task);
  }

  _PrefetchTask? _takeNext() {
    if (_interactive.isNotEmpty) return _interactive.removeFirst();
    if (_hover.isNotEmpty) return _hover.removeFirst();
    if (_lowPriorityPaused) return null;
    if (_visible.isNotEmpty) return _visible.removeFirst();
    if (_lookahead.isNotEmpty) return _lookahead.removeFirst();
    return null;
  }

  void _pump() {
    while (_active < maxConcurrent) {
      final task = _takeNext();
      if (task == null) return;
      final key = task.request.stableRequestKey;
      if (_pending.remove(key) != task || task.generation != _generation) {
        if (!task.completer.isCompleted) task.completer.complete(false);
        continue;
      }
      _active++;
      _inFlight[key] = task;
      debugRequestCount++;
      unawaited(_run(task));
    }
  }

  Future<void> _run(_PrefetchTask task) async {
    final key = task.request.stableRequestKey;
    try {
      await _preloader(task.request);
      if (!task.downloadCompleter.isCompleted) {
        task.downloadCompleter.complete(true);
      }
      if (task.generation != _generation) {
        if (!task.completer.isCompleted) task.completer.complete(false);
        return;
      }
      if (task.request.tier == GalleryImageTier.sample) {
        _rememberCompletedSample(key);
      }
      if (!task.completer.isCompleted) task.completer.complete(true);
    } catch (_) {
      if (task.generation == _generation) {
        _failures.remove(key);
        _failures[key] = _now();
        while (_failures.length > 500) {
          _failures.remove(_failures.keys.first);
        }
      }
      if (!task.downloadCompleter.isCompleted) {
        task.downloadCompleter.complete(false);
      }
      if (!task.completer.isCompleted) task.completer.complete(false);
    } finally {
      _inFlight.remove(key);
      _active--;
      _pump();
    }
  }

  void _rememberCompletedSample(String key) {
    _completedSamples.remove(key);
    _completedSamples[key] = _now();
    while (_completedSamples.length > 16) {
      _completedSamples.remove(_completedSamples.keys.first);
    }
  }
}

class _PrefetchTask {
  _PrefetchTask({
    required this.request,
    required this.priority,
    required this.generation,
  });

  final GalleryImageRequest request;
  GalleryImagePriority priority;
  final int generation;
  final Completer<bool> completer = Completer<bool>();
  final Completer<bool> downloadCompleter = Completer<bool>();
}
