import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../../data/models/online_gallery/gallery_item.dart';

enum GalleryDetailPriority { interactive, visible }

typedef GalleryDetailLoader =
    Future<GalleryDetail> Function(GalleryItem item, CancelToken cancelToken);

class OnlineGalleryDetailCoordinator {
  OnlineGalleryDetailCoordinator({
    required GalleryDetailLoader loader,
    this.maxConcurrent = 4,
    this.maxCompletedEntries = 256,
    this.completedTtl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _loader = loader,
       _now = now ?? DateTime.now;

  final GalleryDetailLoader _loader;
  final int maxConcurrent;
  final int maxCompletedEntries;
  final Duration completedTtl;
  final DateTime Function() _now;

  final LinkedHashMap<String, _CompletedDetail> _completed =
      LinkedHashMap<String, _CompletedDetail>();
  final Map<String, _DetailTask> _tasks = <String, _DetailTask>{};
  final List<_DetailTask> _interactiveQueue = <_DetailTask>[];
  final List<_DetailTask> _visibleQueue = <_DetailTask>[];
  final Map<String, int> _revisions = <String, int>{};
  int _active = 0;

  int get activeCount => _active;
  int get queuedCount => _interactiveQueue.length + _visibleQueue.length;
  int get completedCount {
    _pruneExpired();
    return _completed.length;
  }

  Future<GalleryDetail> request(
    GalleryItem item, {
    GalleryDetailPriority priority = GalleryDetailPriority.interactive,
    bool forceRefresh = false,
  }) {
    final key = item.detailStableKey;
    if (forceRefresh) {
      _completed.remove(key);
      final oldTask = _tasks.remove(key);
      if (oldTask != null) {
        _interactiveQueue.remove(oldTask);
        _visibleQueue.remove(oldTask);
        if (!oldTask.started && !oldTask.completer.isCompleted) {
          oldTask.cancelToken.cancel('Superseded by a forced detail refresh');
          oldTask.completer.completeError(
            DioException.requestCancelled(
              requestOptions: RequestOptions(path: item.postUrl),
              reason: 'Superseded by a forced detail refresh',
            ),
          );
        } else if (!oldTask.cancelToken.isCancelled) {
          oldTask.cancelToken.cancel('Superseded by a forced detail refresh');
        }
      }
    } else {
      final cached = _takeCompleted(key);
      if (cached != null) return Future<GalleryDetail>.value(cached);
      final existing = _tasks[key];
      if (existing != null) {
        if (!existing.started &&
            priority == GalleryDetailPriority.interactive &&
            existing.priority == GalleryDetailPriority.visible) {
          _visibleQueue.remove(existing);
          existing.priority = GalleryDetailPriority.interactive;
          _interactiveQueue.add(existing);
        }
        return existing.completer.future;
      }
    }

    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    final task = _DetailTask(
      item: item,
      revision: revision,
      priority: priority,
    );
    _tasks[key] = task;
    (priority == GalleryDetailPriority.interactive
            ? _interactiveQueue
            : _visibleQueue)
        .add(task);
    _pump();
    return task.completer.future;
  }

  void cancelQueuedVisible() {
    _cancelVisibleTasks(includeActive: false);
  }

  void cancelVisible() {
    _cancelVisibleTasks(includeActive: true);
  }

  void _cancelVisibleTasks({required bool includeActive}) {
    final tasks = _tasks.values
        .where(
          (task) =>
              task.priority == GalleryDetailPriority.visible &&
              (includeActive || !task.started),
        )
        .toList(growable: false);
    for (final task in tasks) {
      _interactiveQueue.remove(task);
      _visibleQueue.remove(task);
      if (_tasks[task.item.detailStableKey] == task) {
        _tasks.remove(task.item.detailStableKey);
      }
      if (!task.cancelToken.isCancelled) {
        task.cancelToken.cancel('Gallery scope changed');
      }
      if (!task.completer.isCompleted) {
        task.completer.completeError(
          DioException.requestCancelled(
            requestOptions: RequestOptions(path: task.item.postUrl),
            reason: 'Gallery scope changed',
          ),
        );
      }
    }
    _pump();
  }

  void cancel(GalleryItem item, {String reason = 'Detail request cancelled'}) {
    final key = item.detailStableKey;
    final task = _tasks.remove(key);
    if (task == null) return;
    _revisions[key] = (_revisions[key] ?? task.revision) + 1;
    _interactiveQueue.remove(task);
    _visibleQueue.remove(task);
    if (!task.cancelToken.isCancelled) task.cancelToken.cancel(reason);
    if (!task.completer.isCompleted) {
      task.completer.completeError(
        DioException.requestCancelled(
          requestOptions: RequestOptions(path: item.postUrl),
          reason: reason,
        ),
      );
    }
    _pump();
  }

  void clear() {
    for (final task in _tasks.values) {
      if (!task.cancelToken.isCancelled) task.cancelToken.cancel('Disposed');
      if (!task.completer.isCompleted) {
        task.completer.completeError(
          DioException.requestCancelled(
            requestOptions: RequestOptions(path: task.item.postUrl),
            reason: 'Disposed',
          ),
        );
      }
    }
    _tasks.clear();
    _interactiveQueue.clear();
    _visibleQueue.clear();
    _completed.clear();
  }

  GalleryDetail? _takeCompleted(String key) {
    final entry = _completed.remove(key);
    if (entry == null) return null;
    if (_now().difference(entry.completedAt) >= completedTtl) return null;
    _completed[key] = entry;
    return entry.detail;
  }

  void _pruneExpired() {
    final now = _now();
    final expired = <String>[];
    for (final entry in _completed.entries) {
      if (now.difference(entry.value.completedAt) >= completedTtl) {
        expired.add(entry.key);
      }
    }
    for (final key in expired) {
      _completed.remove(key);
    }
  }

  void _storeCompleted(String key, GalleryDetail detail) {
    _pruneExpired();
    _completed.remove(key);
    _completed[key] = _CompletedDetail(detail, _now());
    while (_completed.length > maxCompletedEntries) {
      _completed.remove(_completed.keys.first);
    }
  }

  void _pump() {
    while (_active < maxConcurrent) {
      final task = _interactiveQueue.isNotEmpty
          ? _interactiveQueue.removeAt(0)
          : _visibleQueue.isNotEmpty
          ? _visibleQueue.removeAt(0)
          : null;
      if (task == null) return;
      if (_tasks[task.item.detailStableKey] != task ||
          task.completer.isCompleted) {
        continue;
      }
      _active++;
      task.started = true;
      unawaited(_run(task));
    }
  }

  Future<void> _run(_DetailTask task) async {
    final key = task.item.detailStableKey;
    try {
      final detail = await _loader(task.item, task.cancelToken);
      if (_tasks[key] == task && _revisions[key] == task.revision) {
        _storeCompleted(key, detail);
        _tasks.remove(key);
      }
      if (!task.completer.isCompleted) task.completer.complete(detail);
    } catch (error, stackTrace) {
      if (_tasks[key] == task && _revisions[key] == task.revision) {
        _tasks.remove(key);
      }
      if (!task.completer.isCompleted) {
        task.completer.completeError(error, stackTrace);
      }
    } finally {
      _active--;
      _pump();
    }
  }
}

class _DetailTask {
  _DetailTask({
    required this.item,
    required this.revision,
    required this.priority,
  });

  final GalleryItem item;
  final int revision;
  GalleryDetailPriority priority;
  final CancelToken cancelToken = CancelToken();
  final Completer<GalleryDetail> completer = Completer<GalleryDetail>();
  bool started = false;
}

class _CompletedDetail {
  const _CompletedDetail(this.detail, this.completedAt);

  final GalleryDetail detail;
  final DateTime completedAt;
}
