import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/models/image/image_params.dart';
import '../auth_provider.dart';
import '../image_generation_provider.dart';
import '../image_save_settings_provider.dart';
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

final novelAiUpscaleTaskProvider =
    NotifierProvider<NovelAiUpscaleTaskNotifier, NovelAiUpscaleTaskState>(
      NovelAiUpscaleTaskNotifier.new,
    );

class NovelAiUpscaleTaskNotifier extends Notifier<NovelAiUpscaleTaskState> {
  static const String _tag = 'NovelAI-Upscale';

  @override
  NovelAiUpscaleTaskState build() => const NovelAiUpscaleTaskState();

  Future<void> execute({
    required ImageParams params,
    required Uint8List sourceImage,
  }) async {
    if (state.isRunning) return;
    if (!requireAuthenticatedAction(ref, AuthPromptReason.novelAiUpscale)) {
      return;
    }

    state = const NovelAiUpscaleTaskState(
      status: NovelAiUpscaleTaskStatus.running,
    );
    final subscriptionNotifier = ref.read(
      subscriptionNotifierProvider.notifier,
    );

    AppLogger.i(
      'Upscale begin: sourceBytes=${sourceImage.length}, '
      'paramsSize=${params.width}x${params.height}, '
      'action=${params.action.name}, model=${params.model}',
      _tag,
    );

    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final result = await apiService.upscaleImage(sourceImage, scale: 2);
      AppLogger.i('Upscale API returned: bytes=${result.length}', _tag);

      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .registerExternalImage(
            result,
            params: params,
            comparisonSourceImage: sourceImage,
            saveToLocal: saveSettings.autoSave,
            replaceCurrentDisplay: true,
          );

      state = const NovelAiUpscaleTaskState(
        status: NovelAiUpscaleTaskStatus.completed,
      );
      AppLogger.i('Upscale result registered', _tag);
    } catch (error, stackTrace) {
      final message = error.toString();
      state = NovelAiUpscaleTaskState(
        status: NovelAiUpscaleTaskStatus.failed,
        errorMessage: message,
      );
      AppLogger.e('Upscale failed', error, stackTrace, _tag);
    } finally {
      subscriptionNotifier.schedulePostBillingRefresh();
      AppLogger.d('Upscale end', _tag);
    }
  }
}
