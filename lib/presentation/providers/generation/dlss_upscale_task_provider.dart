import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/services/dlss/dlss_options.dart';
import '../../../data/services/dlss/dlss_worker.dart';
import '../dlss_provider.dart';
import '../image_generation_provider.dart';
import '../image_save_settings_provider.dart';

class DlssUpscaleTaskState {
  const DlssUpscaleTaskState({this.running = false, this.error});
  final bool running;
  final Object? error;
}

final dlssUpscaleTaskProvider =
    NotifierProvider<DlssUpscaleTaskNotifier, DlssUpscaleTaskState>(
      DlssUpscaleTaskNotifier.new,
    );

class DlssUpscaleTaskNotifier extends Notifier<DlssUpscaleTaskState> {
  Completer<void>? _cancellation;
  int _epoch = 0;

  @override
  DlssUpscaleTaskState build() {
    _epoch++;
    ref.onDispose(() {
      _epoch++;
      cancel();
    });
    return const DlssUpscaleTaskState();
  }

  void cancel() {
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  Future<bool> execute({
    required ImageParams params,
    required Uint8List source,
  }) async {
    if (state.running) return false;
    final epoch = _epoch;
    final controller = ref.read(dlssProvider);
    final scale = controller.options.scale;
    if (controller.options.nativeScale == 1) return false;
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    final autoSave = ref.read(imageSaveSettingsNotifierProvider).autoSave;
    final cancellation = _cancellation = Completer<void>();
    state = const DlssUpscaleTaskState(running: true);
    try {
      // In this runtime detail=0 selects the SR working image at composition.
      // NR is still evaluated internally; it contributes no pixels to output.
      final output = await controller.enhance(
        source,
        DlssOptions(scale: scale, detail: 0),
        cancelled: cancellation.future,
      );
      if (_epoch != epoch || cancellation.isCompleted) return false;
      await generation.registerExternalImage(
        output,
        params: params,
        comparisonSourceImage: source,
        saveToLocal: autoSave,
        replaceCurrentDisplay: true,
        embedNaiMetadata: false,
      );
      if (_epoch == epoch) state = const DlssUpscaleTaskState();
      return true;
    } on DlssCancelled {
      if (_epoch == epoch) state = const DlssUpscaleTaskState();
      return false;
    } catch (error, stackTrace) {
      AppLogger.e('DLSS SR upscale failed', error, stackTrace, 'DLSS-Upscale');
      if (_epoch == epoch) state = DlssUpscaleTaskState(error: error);
      return false;
    } finally {
      if (_epoch == epoch && state.running) {
        state = const DlssUpscaleTaskState();
      }
      if (identical(_cancellation, cancellation)) _cancellation = null;
    }
  }
}
