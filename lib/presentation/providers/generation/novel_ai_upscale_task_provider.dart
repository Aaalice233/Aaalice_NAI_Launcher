import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/services/auth_provider.dart';
import '../subscription_provider.dart';

enum NovelAiUpscaleTaskStatus { idle, running, completed, failed }

class NovelAiUpscaleTaskState {
  const NovelAiUpscaleTaskState({
    this.status = NovelAiUpscaleTaskStatus.idle,
    this.errorMessage,
  });

  final NovelAiUpscaleTaskStatus status;
  final String? errorMessage;

  bool get isRunning => status == NovelAiUpscaleTaskStatus.running;
}

sealed class NovelAiUpscaleOutcome {
  const NovelAiUpscaleOutcome();
}

final class NovelAiUpscaleCompleted extends NovelAiUpscaleOutcome {
  const NovelAiUpscaleCompleted(this.bytes);

  final Uint8List bytes;
}

enum NovelAiUpscaleSkipReason { busy, unauthenticated }

/// 没有发出请求，也就没有扣点。
final class NovelAiUpscaleSkipped extends NovelAiUpscaleOutcome {
  const NovelAiUpscaleSkipped(this.reason);

  final NovelAiUpscaleSkipReason reason;
}

final class NovelAiUpscaleFailed extends NovelAiUpscaleOutcome {
  const NovelAiUpscaleFailed(this.message);

  final String message;
}

final novelAiUpscaleTaskProvider =
    NotifierProvider<NovelAiUpscaleTaskNotifier, NovelAiUpscaleTaskState>(
      NovelAiUpscaleTaskNotifier.new,
    );

class NovelAiUpscaleTaskNotifier extends Notifier<NovelAiUpscaleTaskState> {
  static const String _tag = 'NovelAI-Upscale';

  @override
  NovelAiUpscaleTaskState build() => const NovelAiUpscaleTaskState();

  /// [adopt] 在运行态内登记结果，登记完成前放大入口保持禁用。
  Future<NovelAiUpscaleOutcome> execute({
    required Uint8List sourceImage,
    required Future<void> Function(Uint8List result) adopt,
  }) async {
    if (state.isRunning) {
      return const NovelAiUpscaleSkipped(NovelAiUpscaleSkipReason.busy);
    }
    if (!requireAuthenticatedAction(ref, AuthPromptReason.novelAiUpscale)) {
      return const NovelAiUpscaleSkipped(
        NovelAiUpscaleSkipReason.unauthenticated,
      );
    }

    state = const NovelAiUpscaleTaskState(
      status: NovelAiUpscaleTaskStatus.running,
    );
    final subscriptionNotifier = ref.read(
      subscriptionNotifierProvider.notifier,
    );

    AppLogger.i('Upscale begin: sourceBytes=${sourceImage.length}', _tag);

    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final result = await apiService.upscaleImage(sourceImage, scale: 2);
      AppLogger.i('Upscale API returned: bytes=${result.length}', _tag);

      await adopt(result);

      state = const NovelAiUpscaleTaskState(
        status: NovelAiUpscaleTaskStatus.completed,
      );
      AppLogger.i('Upscale result registered', _tag);
      return NovelAiUpscaleCompleted(result);
    } catch (error, stackTrace) {
      final message = error.toString();
      state = NovelAiUpscaleTaskState(
        status: NovelAiUpscaleTaskStatus.failed,
        errorMessage: message,
      );
      AppLogger.e('Upscale failed', error, stackTrace, _tag);
      return NovelAiUpscaleFailed(message);
    } finally {
      subscriptionNotifier.schedulePostBillingRefresh();
      AppLogger.d('Upscale end', _tag);
    }
  }
}
