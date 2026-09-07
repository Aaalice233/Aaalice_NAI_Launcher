import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/image_share_sanitizer.dart';
import '../../data/services/discord_share_service.dart';

class DiscordShareSubmission {
  DiscordShareSubmission({
    required this.session,
    required Uint8List bytes,
    required this.fileName,
    required this.stripMetadata,
    required Set<String> targetIds,
    required this.prompt,
    required this.caption,
    required this.width,
    required this.height,
    required this.longPromptAsFile,
  }) : bytes = Uint8List.fromList(bytes),
       targetIds = Set.unmodifiable(targetIds);

  final DiscordShareSession session;
  final Uint8List bytes;
  final String fileName;
  final bool stripMetadata;
  final Set<String> targetIds;
  final String prompt;
  final String caption;
  final int? width;
  final int? height;
  final bool longPromptAsFile;
}

class DiscordShareTaskState {
  const DiscordShareTaskState({
    this.running = false,
    this.result,
    this.error,
    this.retrySeconds = 0,
    this.canRetry = false,
  });

  final bool running;
  final DiscordShareResult? result;
  final Object? error;
  final int retrySeconds;
  final bool canRetry;
}

class DiscordShareTaskNotifier extends StateNotifier<DiscordShareTaskState?> {
  DiscordShareTaskNotifier(this._service, {ShareImagePrepareFunction? prepare})
    : _prepare =
          prepare ?? ImageShareSanitizer.prepareForCopyOrDragInBackground,
      super(null);

  final DiscordShareService _service;
  final ShareImagePrepareFunction _prepare;
  DiscordShareSubmission? _submission;
  SanitizedShareImage? _image;
  Set<String> _remaining = {};
  Timer? _timer;

  void submit(DiscordShareSubmission submission) {
    if (state?.running == true) {
      throw const DiscordShareException(
        code: 'share_in_progress',
        message: 'A Discord share is in progress.',
      );
    }
    _timer?.cancel();
    _submission = submission;
    _image = null;
    _remaining = Set.of(submission.targetIds);
    unawaited(_run());
  }

  void retry() {
    if (state?.canRetry != true || (state?.retrySeconds ?? 0) > 0) return;
    unawaited(_run());
  }

  Future<void> _run() async {
    final submission = _submission!;
    state = const DiscordShareTaskState(running: true);
    try {
      final image = _image ??= await _prepare(
        submission.bytes,
        fileName: submission.fileName,
        stripMetadata: submission.stripMetadata,
      );
      if (!mounted) return;
      final result = await _service.share(
        session: submission.session,
        image: image,
        targetIds: _remaining,
        prompt: submission.prompt,
        caption: submission.caption,
        width: submission.width,
        height: submission.height,
        longPromptAsFile: submission.longPromptAsFile,
      );
      // Retry uses stable IDs from the relay, never presentation labels.
      _remaining = result.failedTargetIds.toSet();
      if (!mounted) return;
      state = DiscordShareTaskState(
        result: result,
        canRetry: _remaining.isNotEmpty,
      );
      if (!result.isPartial) _releaseImage();
    } catch (error) {
      if (!mounted) return;
      final delay = error is DiscordShareException ? error.retryAfter : null;
      state = DiscordShareTaskState(
        error: error,
        canRetry: true,
        retrySeconds: delay == null ? 0 : (delay.inMilliseconds / 1000).ceil(),
      );
      if (delay != null) _startCooldown(error, delay);
    }
  }

  void _startCooldown(Object error, Duration delay) {
    final elapsed = Stopwatch()..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds = ((delay - elapsed.elapsed).inMilliseconds / 1000).ceil();
      state = DiscordShareTaskState(
        error: error,
        canRetry: true,
        retrySeconds: seconds > 0 ? seconds : 0,
      );
      if (seconds <= 0) timer.cancel();
    });
  }

  void dismiss() {
    if (state?.running == true) return;
    _timer?.cancel();
    _releaseImage();
    state = null;
  }

  void _releaseImage() {
    _submission = null;
    _image = null;
    _remaining = {};
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final discordShareTaskProvider =
    StateNotifierProvider<DiscordShareTaskNotifier, DiscordShareTaskState?>(
      (ref) => DiscordShareTaskNotifier(ref.watch(discordShareServiceProvider)),
    );
