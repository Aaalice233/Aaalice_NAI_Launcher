import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/prompt_assistant/assistant_execution_settings.dart';
import '../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import 'assistant_cancellation.dart';
import 'llm_request_retry_policy.dart';

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
  static const _maxRetries = 2;
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
      try {
        _retryOrFail(job, epoch, error, stack);
      } catch (inspectionError) {
        // An escaped exception here would leave the caller waiting forever.
        _fail(job, error, stack);
        AppLogger.w(
          'retry inspection failed: ${inspectionError.runtimeType}',
          'PromptAssistant',
        );
      }
    } finally {
      _running.remove(job);
      _pump();
    }
  }

  void _retryOrFail(
    _QueuedRequest job,
    int epoch,
    Object error,
    StackTrace stack,
  ) {
    final delay = error is DioException && !job.cancelToken.isCancelled
        ? _retryDelay(error, job.retries)
        : null;
    if (delay == null) {
      _fail(job, error, stack);
      return;
    }
    _throttle(epoch, delay);
    if (job.retries++ >= _maxRetries || job.result.isCompleted) {
      _fail(job, error, stack);
    } else {
      _pending.add(job);
    }
  }

  void _fail(_QueuedRequest job, Object error, StackTrace stack) {
    if (!job.result.isCompleted) job.result.completeError(error, stack);
  }

  void _throttle(int epoch, Duration delay) {
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
    return llmRetryAfter(response, now: _now()) ??
        Duration(seconds: 1 << math.min(retries, 2));
  }

  void dispose() {
    _cooldown?.cancel();
    for (final job in [..._pending, ..._running]) {
      job.cancelToken.cancel('assistant scheduler disposed');
    }
    _pending.clear();
  }
}
