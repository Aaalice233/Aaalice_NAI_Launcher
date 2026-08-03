import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../share_image_settings_provider.dart';

class GenerationCooldownState {
  const GenerationCooldownState({this.availableAt, this.remainingSeconds = 0});

  final DateTime? availableAt;
  final int remainingSeconds;

  bool get isActive => remainingSeconds > 0;
}

final generationCooldownClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final generationCooldownProvider =
    NotifierProvider<GenerationCooldownNotifier, GenerationCooldownState>(
      GenerationCooldownNotifier.new,
    );

class GenerationCooldownNotifier extends Notifier<GenerationCooldownState> {
  static const _tickInterval = Duration(milliseconds: 250);

  Timer? _ticker;
  DateTime? _lastGenerationStartedAt;

  LocalStorageService get _storage => ref.read(localStorageServiceProvider);
  DateTime get _now => ref.read(generationCooldownClockProvider)();
  int get _intervalSeconds =>
      ref.read(shareImageSettingsProvider).effectiveGenerationIntervalSeconds;

  @override
  GenerationCooldownState build() {
    final storedTimestamp = _storage.getSetting<int>(
      StorageKeys.protectionLastGenerationStartedAt,
    );
    _lastGenerationStartedAt = storedTimestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(storedTimestamp, isUtc: true);
    if (_lastGenerationStartedAt?.isAfter(_now) ?? false) {
      _lastGenerationStartedAt = _now;
    }

    ref.listen<ShareImageSettings>(shareImageSettingsProvider, (_, __) {
      _refresh();
    });
    ref.onDispose(() => _ticker?.cancel());

    final initialState = _calculateState();
    if (initialState.isActive) {
      _startTicker();
    }
    return initialState;
  }

  bool tryStartGeneration() {
    _refresh();
    if (state.isActive) {
      return false;
    }

    if (_intervalSeconds <= 0) {
      return true;
    }

    _lastGenerationStartedAt = _now;
    _refresh();
    unawaited(_persistLastGenerationStartedAt());
    return true;
  }

  Future<void> _persistLastGenerationStartedAt() async {
    try {
      await _storage.setSetting(
        StorageKeys.protectionLastGenerationStartedAt,
        _lastGenerationStartedAt!.toUtc().millisecondsSinceEpoch,
      );
    } catch (error) {
      AppLogger.w(
        'Failed to persist generation cooldown timestamp: $error',
        'GenerationCooldown',
      );
    }
  }

  Future<void> waitUntilAvailable() async {
    while (true) {
      _refresh();
      if (!state.isActive) {
        return;
      }
      await Future<void>.delayed(_tickInterval);
    }
  }

  GenerationCooldownState _calculateState() {
    final intervalSeconds = _intervalSeconds;
    final startedAt = _lastGenerationStartedAt;
    if (intervalSeconds <= 0 || startedAt == null) {
      return const GenerationCooldownState();
    }

    final availableAt = startedAt.add(Duration(seconds: intervalSeconds));
    final remainingMilliseconds = availableAt.difference(_now).inMilliseconds;
    if (remainingMilliseconds <= 0) {
      return const GenerationCooldownState();
    }

    return GenerationCooldownState(
      availableAt: availableAt,
      remainingSeconds: (remainingMilliseconds / 1000).ceil(),
    );
  }

  void _refresh() {
    final nextState = _calculateState();
    if (state.availableAt != nextState.availableAt ||
        state.remainingSeconds != nextState.remainingSeconds) {
      state = nextState;
    }

    if (nextState.isActive) {
      _startTicker();
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _startTicker() {
    if (_ticker?.isActive ?? false) {
      return;
    }
    _ticker = Timer.periodic(_tickInterval, (_) => _refresh());
  }
}
