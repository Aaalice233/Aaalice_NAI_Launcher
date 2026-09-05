import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/assistant_execution_settings.dart';
import '../models/prompt_assistant_models.dart';
import 'assistant_cancellation.dart';

/// One queue per configured endpoint, shared by every prompt-assistant task.
class AssistantRequestScheduler {
  AssistantRequestScheduler({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final Map<String, _ProviderQueue> _queues = {};
  bool _disposed = false;

  Future<String> run({
    required ProviderConfig provider,
    required CancelToken cancelToken,
    required Future<String> Function() request,
  }) {
    if (_disposed) throw StateError('Assistant request scheduler is disposed');
    cancelToken.throwIfCancelled();
    final key = '${provider.id}/${provider.protocol.name}/${provider.baseUrl}';
    final queue = _queues.putIfAbsent(key, () => _ProviderQueue(_now));
    queue.configure(provider.concurrency);
    return queue.add(request, cancelToken);
  }

  int concurrencyFor(ProviderConfig provider) =>
      _queues['${provider.id}/${provider.protocol.name}/${provider.baseUrl}']
          ?.limit ??
      (provider.concurrency.mode == AssistantConcurrencyMode.manual
          ? provider.concurrency.maxConcurrentRequests
          : AssistantConcurrencySettings.initialAutomaticConcurrency);

  void dispose() {
    _disposed = true;
    for (final queue in _queues.values) {
      queue.dispose();
    }
    _queues.clear();
  }
}

class _QueuedRequest {
  _QueuedRequest(this.request, this.cancelToken);
  final Future<String> Function() request;
  final CancelToken cancelToken;
  final Completer<String> result = Completer<String>();
  int retries = 0;
}

class _ProviderQueue {
  _ProviderQueue(this._now);
  final DateTime Function() _now;
  final Queue<_QueuedRequest> _pending = Queue();
  final Set<_QueuedRequest> _running = {};
  AssistantConcurrencySettings _settings = const AssistantConcurrencySettings();
  int limit = AssistantConcurrencySettings.initialAutomaticConcurrency;
  int _successes = 0;
  int _congestionEpoch = 0;
  Timer? _cooldown;
  DateTime? _resumeAt;

  void configure(AssistantConcurrencySettings settings) {
    if (_settings.mode != settings.mode) {
      limit = AssistantConcurrencySettings.initialAutomaticConcurrency;
      _successes = 0;
    }
    _settings = settings;
    if (settings.mode == AssistantConcurrencyMode.manual) {
      limit = settings.maxConcurrentRequests;
    }
  }

  Future<String> add(Future<String> Function() request, CancelToken token) {
    final job = _QueuedRequest(request, token);
    _pending.add(job);
    // Cancellation must also remove work that has not reached the HTTP client.
    unawaited(
      token.whenCancel.then((error) {
        _pending.remove(job);
        if (!job.result.isCompleted) job.result.completeError(error);
        _pump();
      }),
    );
    _pump();
    return job.result.future;
  }

  void _pump() {
    if (_pending.isEmpty) {
      _cooldown?.cancel();
      _cooldown = null;
      return;
    }
    final remaining = _resumeAt?.difference(_now());
    if (remaining != null && remaining > Duration.zero) {
      _cooldown ??= Timer(remaining, () {
        _cooldown = null;
        _pump();
      });
      return;
    }
    while (_running.length < limit && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      if (job.result.isCompleted) continue;
      _running.add(job);
      unawaited(_execute(job, _congestionEpoch));
    }
  }

  Future<void> _execute(_QueuedRequest job, int epoch) async {
    try {
      job.cancelToken.throwIfCancelled();
      final value = await job.request();
      job.cancelToken.throwIfCancelled();
      if (!job.result.isCompleted) job.result.complete(value);
      // Ignore successes from requests started before the last congestion event.
      if (epoch == _congestionEpoch &&
          _settings.mode == AssistantConcurrencyMode.automatic &&
          _pending.isNotEmpty &&
          ++_successes >= limit) {
        limit++;
        _successes = 0;
      }
    } catch (error, stack) {
      final delay = error is DioException
          ? _retryDelay(error, job.retries)
          : null;
      if (delay != null && !job.cancelToken.isCancelled) {
        if (epoch == _congestionEpoch) {
          _congestionEpoch++;
          _successes = 0;
          if (_settings.mode == AssistantConcurrencyMode.automatic) {
            limit = math.max(1, limit ~/ 2);
          }
        }
        final resumeAt = _now().add(delay);
        if (_resumeAt == null || resumeAt.isAfter(_resumeAt!)) {
          _resumeAt = resumeAt;
          _cooldown?.cancel();
          _cooldown = null;
        }
        if (job.retries++ < 2 && !job.result.isCompleted) {
          _pending.add(job);
        } else if (!job.result.isCompleted) {
          job.result.completeError(error, stack);
        }
      } else if (!job.result.isCompleted) {
        job.result.completeError(error, stack);
      }
    } finally {
      _running.remove(job);
      _pump();
    }
  }

  Duration? _retryDelay(DioException error, int retries) {
    final response = error.response;
    if (response?.statusCode != 429 && response?.statusCode != 503) return null;
    final detail = response?.data.toString().toLowerCase() ?? '';
    if (RegExp(
      r'insufficient_quota|insufficient.balance|billing|daily.quota',
    ).hasMatch(detail)) {
      return null;
    }
    final retryAfter = response?.headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = double.tryParse(retryAfter);
      if (seconds != null && seconds.isFinite && seconds >= 0) {
        return Duration(milliseconds: (seconds * 1000).ceil());
      }
      try {
        final delay = HttpDate.parse(retryAfter).difference(_now());
        return delay.isNegative ? Duration.zero : delay;
      } on FormatException {
        // Malformed optional headers do not replace the original HTTP failure.
      }
    }
    return Duration(seconds: 1 << math.min(retries, 2));
  }

  void dispose() {
    _cooldown?.cancel();
    for (final job in [..._pending, ..._running]) {
      job.cancelToken.cancel('assistant scheduler disposed');
    }
    _pending.clear();
  }
}
