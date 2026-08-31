import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/model_capabilities.dart';
import '../../core/services/android_generation_foreground_service.dart';
import '../../core/services/anlas_calculator.dart';
import '../../core/services/character_conversion_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/character_center_resolver.dart';
import '../../core/utils/image_save_utils.dart';
import '../../core/utils/image_share_sanitizer.dart';
import '../../core/utils/inpaint_mask_utils.dart';
import '../../core/utils/nai_prompt_formatter.dart';
import '../../core/utils/nai_resolution_adapter.dart';
import '../../core/utils/pica_lanczos_resizer.dart';
import '../../core/utils/prompt_preset_resolution.dart';
import '../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../data/models/character/character_prompt.dart' as ui_character;
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/image/image_stream_chunk.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/alias_resolver_service.dart';
import '../../data/services/statistics_cache_service.dart';
import '../services/generation_history_storage_service.dart';
import 'auth_provider.dart';
import 'character_prompt_provider.dart';
import 'fixed_tags_provider.dart';
import 'generation/generation_command.dart';
import 'generation/generation_cooldown_provider.dart';
import 'generation/generation_models.dart';
import 'generation/generation_params_notifier.dart';
import 'generation/generation_request_preparation_service.dart';
import 'generation/generation_result_lifecycle_service.dart';
import 'generation/generation_settings_notifiers.dart';
import 'generation/image_generation_coordinator.dart';
import 'generation/image_workflow_controller.dart';
import 'image_save_settings_provider.dart';
import 'local_gallery_provider.dart';
import 'prompt_config_provider.dart';
import 'quality_preset_provider.dart';
import 'queue_execution_provider.dart';
import 'subscription_provider.dart';
import 'uc_preset_provider.dart';

export 'generation/generation_models.dart';
export 'generation/generation_cooldown_provider.dart';
export 'generation/generation_params_notifier.dart';
export 'generation/generation_auxiliary_notifiers.dart';
export 'generation/generation_settings_notifiers.dart';
export 'generation/reference_panel_notifier.dart';
export 'generation/generation_command.dart';
export 'generation/image_generation_coordinator.dart';
export 'generation/generation_request_preparation_service.dart';
export 'generation/generation_result_lifecycle_service.dart';
export 'generation/image_generation_service.dart';
export 'generation/batch_generation_notifier.dart';
export 'generation/stream_generation_notifier.dart';
export 'generation/metadata_preload_notifier.dart';
export 'generation/retry_policy_notifier.dart';

part 'image_generation_provider.g.dart';

class _RememberedStreamPreview {
  const _RememberedStreamPreview({
    required this.bytes,
    required this.params,
    this.focusedPreviewPlacement,
  });

  final Uint8List bytes;
  final ImageParams params;
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;
}

@Riverpod(keepAlive: true)
class ImageGenerationNotifier extends _$ImageGenerationNotifier {
  Future<void>? _historyRestoreInFlight;
  bool _hasRestoredHistory = false;
  bool _generationInvocationStarting = false;
  Completer<void>? _generationInvocationSettled;
  int _invocationCounter = 0;
  int _activeInvocationId = 0;
  int _runCounter = 0;
  int _activeRunId = 0;
  GenerationRunHandle? _activeRun;
  ImageGenerationCoordinator? _coordinator;
  final Set<int> _foregroundInvocationIds = <int>{};
  final Map<String, String?> _persistedHistoryFilePaths = <String, String?>{};
  final Map<String, _RememberedStreamPreview> _streamPreviews = {};
  final Set<String> _failedSnapshotKeys = {};
  ImageComparisonSource? _activeComparisonSource;
  bool _isDisposed = false;
  int _lifecycleEpoch = 0;

  @override
  ImageGenerationState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _lifecycleEpoch++;
      _generationInvocationStarting = false;
      _activeComparisonSource = null;
      final invocationSettled = _generationInvocationSettled;
      _generationInvocationSettled = null;
      if (invocationSettled != null && !invocationSettled.isCompleted) {
        invocationSettled.complete();
      }
      final coordinator = _coordinator;
      final handle = _activeRun;
      if (coordinator != null && handle != null) coordinator.cancel(handle);
    });
    Future.microtask(ensureGenerationHistoryRestored);
    return const ImageGenerationState();
  }

  bool _isCurrentLifecycle(int epoch) =>
      !_isDisposed && epoch == _lifecycleEpoch;

  GenerationResultLifecycleService _lifecycle() {
    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    final statistics = ref.read(statisticsCacheServiceProvider);
    return GenerationResultLifecycleService(
      GenerationResultLifecycleDependencies(
        historyStorage: ref.read(generationHistoryStorageServiceProvider),
        resolveGalleryRootPath: GalleryFolderRepository.instance.getRootPath,
        addGalleryImages: gallery.addNewlySavedImages,
        refreshGallery: gallery.refresh,
        incrementStatistics: statistics.incrementImageCount,
      ),
    );
  }

  ImageComparisonSource? _comparisonSourceFor(Uint8List bytes) {
    return ImageComparisonSource.fromBytes(
      bytes,
      reuseCandidates: _retainedComparisonSources(),
    );
  }

  /// Reuses only sources already owned by live results; there is deliberately
  /// no separate cache that could outlive history eviction or display cleanup.
  Iterable<ImageComparisonSource> _retainedComparisonSources() sync* {
    final seen = <ImageComparisonSource>{};
    final active = _activeComparisonSource;
    if (active != null && seen.add(active)) yield active;

    for (final images in <List<GeneratedImage>>[
      state.currentImages,
      state.history,
      state.displayImages,
    ]) {
      for (final image in images) {
        final source = image.comparisonSource;
        if (source != null && seen.add(source)) yield source;
      }
    }
  }

  Future<void> ensureGenerationHistoryRestored() {
    if (_isDisposed || _hasRestoredHistory) return Future<void>.value();
    final current = _historyRestoreInFlight;
    if (current != null) return current;
    final epoch = _lifecycleEpoch;
    final lifecycle = _lifecycle();
    late final Future<void> restore;
    restore = _restoreGenerationHistory(lifecycle, epoch).whenComplete(() {
      if (_isCurrentLifecycle(epoch) &&
          identical(_historyRestoreInFlight, restore)) {
        _historyRestoreInFlight = null;
      }
    });
    _historyRestoreInFlight = restore;
    return restore;
  }

  Future<void> _restoreGenerationHistory(
    GenerationResultLifecycleService lifecycle,
    int epoch,
  ) async {
    try {
      final restored = await lifecycle.loadHistory();
      if (!_isCurrentLifecycle(epoch)) return;
      _hasRestoredHistory = true;
      if (restored.isEmpty) return;
      final merged = lifecycle.mergeHistory(state.history, restored);
      final restorePreview =
          !state.isGenerating &&
          state.displayImages.isEmpty &&
          merged.isNotEmpty;
      _persistedHistoryFilePaths
        ..clear()
        ..addEntries(
          restored.map((image) => MapEntry(image.id, image.filePath)),
        );
      state = state.copyWith(
        status: state.status == GenerationStatus.idle
            ? GenerationStatus.completed
            : state.status,
        history: merged,
        displayImages: restorePreview ? [merged.first] : state.displayImages,
        displayWidth: restorePreview ? merged.first.width : state.displayWidth,
        displayHeight: restorePreview
            ? merged.first.height
            : state.displayHeight,
      );
      _retainHistoryCaches();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to restore generation history', error, stackTrace);
    }
  }

  Future<void> flushGenerationHistory() {
    if (_isDisposed) return Future<void>.value();
    return _lifecycle().flushHistory();
  }

  void _retainHistoryCaches() {
    if (_isDisposed) return;
    final retainedIds = <String>{
      for (final image in state.currentImages) image.id,
      for (final image in state.history) image.id,
    };
    unawaited(
      ShareImagePreparationService.instance.retainHistoryImageIds(retainedIds),
    );
    final changed = state.history
        .where(
          (image) =>
              !_persistedHistoryFilePaths.containsKey(image.id) ||
              _persistedHistoryFilePaths[image.id] != image.filePath,
        )
        .toList();
    final historyIds = state.history.map((image) => image.id).toSet();
    final epoch = _lifecycleEpoch;
    final lifecycle = _lifecycle();
    unawaited(
      lifecycle
          .persistHistory(
            changedImages: changed,
            order: state.history.map((image) => image.id).toList(),
          )
          .then((_) {
            if (!_isCurrentLifecycle(epoch)) return;
            _persistedHistoryFilePaths
              ..removeWhere((id, _) => !historyIds.contains(id))
              ..addEntries(
                changed.map((image) => MapEntry(image.id, image.filePath)),
              );
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> waitUntilGenerationInvocationSettled() =>
      _generationInvocationSettled?.future ?? Future<void>.value();

  Future<void> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
  }) async {
    if (_isDisposed || _generationInvocationStarting || state.isGenerating) {
      return;
    }
    _generationInvocationStarting = true;
    final invocationSettled = Completer<void>();
    _generationInvocationSettled = invocationSettled;
    final epoch = _lifecycleEpoch;
    final lifecycle = _lifecycle();
    final subscription = ref.exists(subscriptionNotifierProvider)
        ? ref.read(subscriptionNotifierProvider.notifier)
        : null;
    final invocationId = ++_invocationCounter;
    _activeInvocationId = invocationId;
    var foregroundStarted = false;

    try {
      if (!requireAuthenticatedAction(ref, AuthPromptReason.imageGeneration)) {
        return;
      }
      final liveParams = ref.read(generationParamsNotifierProvider);
      final useRestoredLiveParams = identical(params, liveParams);
      if (ref.read(generationSessionPersistenceEnabledProvider)) {
        await Future.wait<void>([
          ensureGenerationHistoryRestored(),
          ref
              .read(generationParamsNotifierProvider.notifier)
              .restoreGenerationState(),
        ]);
        if (!_isCurrentLifecycle(epoch) ||
            _activeInvocationId != invocationId) {
          return;
        }
      }
      final effectiveParams = useRestoredLiveParams
          ? ref.read(generationParamsNotifierProvider)
          : params;
      final issue = NaiResolutionAdapter.validateGenerationResolution(
        effectiveParams.width,
        effectiveParams.height,
      );
      if (issue != null) {
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: issue.errorCode,
          progress: 0,
        );
        return;
      }
      if (!ref.read(generationCooldownProvider.notifier).tryStartGeneration()) {
        return;
      }

      try {
        await AndroidGenerationForegroundService.start();
        foregroundStarted = AndroidGenerationForegroundService.isSupported;
        if (foregroundStarted) _foregroundInvocationIds.add(invocationId);
      } catch (error, stackTrace) {
        AppLogger.e(
          'Unable to start Android generation foreground service',
          error,
          stackTrace,
        );
      }
      if (!_isCurrentLifecycle(epoch) || _activeInvocationId != invocationId) {
        return;
      }

      final preparation = _preparationService(
        preserveCharacterSnapshot: preserveCharacterSnapshot,
      );
      late final GenerationPreparationResult prepared;
      try {
        prepared = await preparation.prepareInitial(effectiveParams);
      } on UnsupportedRandomPromptModelException catch (error, stackTrace) {
        AppLogger.e(
          'Generation preparation rejected an unsupported random model',
          error,
          stackTrace,
        );
        if (_isCurrentLifecycle(epoch) && _activeInvocationId == invocationId) {
          state = state.copyWith(
            status: GenerationStatus.error,
            errorMessage: error.encodedMessage,
            progress: 0,
          );
        }
        return;
      }
      if (!_isCurrentLifecycle(epoch) || _activeInvocationId != invocationId) {
        return;
      }
      final runId = ++_runCounter;
      _activeRunId = runId;
      _streamPreviews.clear();
      _failedSnapshotKeys.clear();
      final coordinator = ImageGenerationCoordinator(
        apiService: ref.read(naiImageGenerationApiServiceProvider),
      );
      _coordinator = coordinator;
      final command = GenerationCommand(
        runId: runId,
        params: prepared.params,
        batchCount: prepared.params.nSamples,
        batchSize: batchSizeOverride ?? ref.read(imagesPerRequestProvider),
        prepareBatch: (batch, current) async {
          if (batch == 0) return current;
          final next = await preparation.prepareSubsequentBatch(current);
          return next;
        },
        focusedInpaintEnabled: prepared.focusedSnapshot.enabled,
        minimumContextMegaPixels:
            prepared.focusedSnapshot.minimumContextMegaPixels,
        focusedSelectionRect: prepared.focusedSnapshot.selectionRect,
        streamPreviewEnabled: ref.read(generationStreamPreviewSettingsProvider),
      );
      final handle = coordinator.start(command);
      _activeRun = handle;
      await for (final event in coordinator.execute(command, handle)) {
        await _reduce(event, epoch);
      }
    } finally {
      if (_isCurrentLifecycle(epoch) && _activeInvocationId == invocationId) {
        _activeInvocationId = 0;
        _generationInvocationStarting = false;
        _activeComparisonSource = null;
      }
      if (!invocationSettled.isCompleted) {
        invocationSettled.complete();
      }
      if (identical(_generationInvocationSettled, invocationSettled)) {
        _generationInvocationSettled = null;
      }
      if (foregroundStarted) {
        _foregroundInvocationIds.remove(invocationId);
        if (_foregroundInvocationIds.isEmpty) {
          try {
            await AndroidGenerationForegroundService.stop();
          } catch (error, stackTrace) {
            AppLogger.e(
              'Unable to stop Android generation foreground service',
              error,
              stackTrace,
            );
          }
        }
      }
      try {
        await lifecycle.flushHistory();
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to flush generation history after generation',
          error,
          stackTrace,
        );
      }
      if (_isCurrentLifecycle(epoch)) {
        subscription?.schedulePostBillingRefresh();
      }
    }
  }

  GenerationRequestPreparationService _preparationService({
    bool preserveCharacterSnapshot = false,
  }) {
    var queueExecuting = false;
    try {
      final queue = ref.read(queueExecutionNotifierProvider);
      queueExecuting = queue.isRunning || queue.isReady;
    } catch (_) {
      queueExecuting = false;
    }
    final aliases = ref.read(aliasResolverServiceProvider.notifier);
    final fixedTags = ref.read(fixedTagsNotifierProvider);
    return GenerationRequestPreparationService(
      GenerationPreparationDependencies(
        prompt: GenerationPromptPreparation(
          randomModeEnabled: ref.read(randomPromptModeProvider),
          queueExecuting: queueExecuting,
          generateAndApplyRandomPrompt: (model) =>
              generateAndApplyRandomPrompt(model: model),
          resolveAliases: aliases.resolveAliases,
          applyFixedPositiveTags: fixedTags.applyToPrompt,
          applyFixedNegativeTags: fixedTags.applyToNegativePrompt,
          resolvePresets: _resolvePromptPresets,
        ),
        characters: GenerationCharacterPreparation(
          read: (_) {
            final config = ref.read(characterPromptNotifierProvider);
            final characters = _convertCharactersToApiFormat(config);
            return CharacterPreparationSnapshot(
              characters: characters,
              useCoords: characters.isNotEmpty && !config.globalAiChoice,
            );
          },
        ),
        focused: GenerationFocusedPreparation(
          read: () {
            final workflow = ref.read(imageWorkflowControllerProvider);
            return GenerationFocusedSnapshot(
              enabled: workflow.focusedInpaintEnabled,
              minimumContextMegaPixels: workflow.minimumContextMegaPixels,
              selectionRect: workflow.focusedSelectionRect,
            );
          },
        ),
        vibes: GenerationVibePreparation(prepare: _prepareVibesForGeneration),
      ),
      preserveCharacterSnapshot: preserveCharacterSnapshot,
    );
  }

  Future<void> _reduce(GenerationEvent event, int epoch) async {
    if (!_isCurrentLifecycle(epoch) || event.runId != _activeRunId) return;
    switch (event) {
      case GenerationStarted(:final params, :final totalImages):
        final sourceImage = params.sourceImage;
        // Generate may still carry canvas data, but only image transformations
        // have a source that represents the visual input to the result.
        _activeComparisonSource =
            sourceImage != null &&
                params.action != ImageGenerationAction.generate
            ? _comparisonSourceFor(sourceImage)
            : null;
        state = state.copyWith(
          currentImages: [],
          status: GenerationStatus.generating,
          progress: 0,
          currentImage: totalImages > 0 ? 1 : 0,
          totalImages: totalImages,
          batchWidth: params.width,
          batchHeight: params.height,
          clearStreamPreview: true,
        );
      case GenerationRequestStarted(
        :final params,
        :final startImage,
        :final requestSize,
        :final totalImages,
      ):
        state = state.copyWith(
          currentImage: startImage,
          totalImages: totalImages,
          progress: (startImage - 1) / totalImages,
          batchWidth: params.width,
          batchHeight: params.height,
          streamPreviewSlots: [
            for (var i = 0; i < requestSize; i++)
              StreamPreviewSlot(
                imageNumber: startImage + i,
                totalImages: totalImages,
                progress: 0,
              ),
          ],
          clearStreamPreview: true,
        );
      case GenerationImageStarted(:final imageNumber, :final totalImages):
        state = state.copyWith(
          currentImage: imageNumber,
          progress: (imageNumber - 1) / totalImages,
        );
      case GenerationPreviewReceived(
        :final params,
        :final imageNumber,
        :final totalImages,
        :final progress,
        :final bytes,
        :final focusedPreviewPlacement,
      ):
        _rememberPreview(
          event.runId,
          imageNumber,
          bytes,
          params,
          focusedPreviewPlacement,
        );
        final slot = StreamPreviewSlot(
          imageNumber: imageNumber,
          totalImages: totalImages,
          progress: progress,
          previewBytes: bytes,
          focusedPreviewPlacement: focusedPreviewPlacement,
        );
        state = state.copyWith(
          currentImage: imageNumber,
          progress: ((imageNumber - 1) + progress) / totalImages,
          streamPreview: bytes,
          focusedPreviewPlacement: focusedPreviewPlacement,
          clearFocusedPreviewPlacement: focusedPreviewPlacement == null,
          streamPreviewSlots: _replacePreviewSlot(
            state.streamPreviewSlots,
            slot,
          ),
        );
      case GenerationRequestCompleted(
        :final params,
        :final startImage,
        :final totalImages,
        :final images,
        :final vibeEncodings,
      ):
        final generated = images
            .map(
              (bytes) => GeneratedImage.create(
                bytes,
                width: params.width,
                height: params.height,
                comparisonSource: _activeComparisonSource,
              ),
            )
            .toList();
        final current = [...state.currentImages, ...generated];
        state = state.copyWith(
          currentImages: current,
          history: [
            ...generated,
            ...state.history,
          ].take(GenerationResultLifecycleService.historyLimit).toList(),
          progress: (startImage - 1 + images.length) / totalImages,
          clearStreamPreview: true,
        );
        for (var i = 0; i < max(images.length, params.nSamples); i++) {
          _streamPreviews.remove(_snapshotKey(event.runId, startImage + i));
        }
        _saveVibeEncodings(vibeEncodings);
        _retainHistoryCaches();
      case GenerationRequestSkipped(:final startImage, :final requestSize):
        _appendFailedSnapshots(event.runId);
        for (var i = 0; i < requestSize; i++) {
          _streamPreviews.remove(_snapshotKey(event.runId, startImage + i));
        }
        state = state.copyWith(clearStreamPreview: true);
      case GenerationRequestFailed(:final error, :final isTerminal):
        _appendFailedSnapshots(event.runId);
        if (isTerminal) {
          _activeComparisonSource = null;
          state = state.copyWith(
            status: GenerationStatus.error,
            errorMessage: error.toString(),
            progress: 0,
            currentImage: 0,
            totalImages: 0,
            clearStreamPreview: true,
          );
        }
      case GenerationCompleted(:final params):
        final images = List<GeneratedImage>.from(state.currentImages);
        _activeComparisonSource = null;
        state = state.copyWith(
          status: GenerationStatus.completed,
          displayImages: images,
          displayWidth: images.isEmpty ? params.width : images.first.width,
          displayHeight: images.isEmpty ? params.height : images.first.height,
          progress: 1,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
        if (images.isNotEmpty) {
          final lifecycle = _lifecycle();
          final settings = ref.read(imageSaveSettingsNotifierProvider);
          if (settings.autoSave) {
            await _saveImages(images, params, epoch: epoch);
            if (!_isCurrentLifecycle(epoch) || event.runId != _activeRunId) {
              return;
            }
          }
          lifecycle.preloadMetadata(images);
        }
      case GenerationCancelled():
        _appendFailedSnapshots(event.runId);
        _activeComparisonSource = null;
        state = state.copyWith(
          status: GenerationStatus.cancelled,
          progress: 0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
      case GenerationFailed(:final error):
        _appendFailedSnapshots(event.runId);
        _activeComparisonSource = null;
        state = state.copyWith(
          status: GenerationStatus.error,
          errorMessage: error.toString(),
          progress: 0,
          currentImage: 0,
          totalImages: 0,
          clearStreamPreview: true,
        );
    }
  }

  void _rememberPreview(
    int runId,
    int imageNumber,
    Uint8List bytes,
    ImageParams params,
    FocusedStreamPreviewPlacement? placement,
  ) {
    if (bytes.isEmpty) return;
    _streamPreviews[_snapshotKey(
      runId,
      imageNumber,
    )] = _RememberedStreamPreview(
      bytes: Uint8List.fromList(bytes),
      params: params,
      focusedPreviewPlacement: placement?.copyWith(
        sourceImage: Uint8List.fromList(placement.sourceImage),
        maskImage: placement.maskImage == null
            ? null
            : Uint8List.fromList(placement.maskImage!),
      ),
    );
  }

  String _snapshotKey(int runId, int imageNumber) => '$runId:$imageNumber';

  void _appendFailedSnapshots(int runId) {
    final numbers = state.streamPreviewSlots.isNotEmpty
        ? state.streamPreviewSlots.map((slot) => slot.imageNumber).toList()
        : state.currentImage > 0
        ? [state.currentImage]
        : const <int>[];
    for (final number in numbers.reversed) {
      final key = _snapshotKey(runId, number);
      final preview = _streamPreviews[key];
      if (preview == null || !_failedSnapshotKeys.add(key)) continue;
      final bytes = _materializePreview(preview);
      final size =
          NaiResolutionAdapter.readImageSize(bytes) ??
          (preview.params.width, preview.params.height);
      final snapshot = GeneratedImage.create(
        bytes,
        width: size.$1,
        height: size.$2,
        kind: GeneratedImageKind.failedStreamSnapshot,
        metadata: _metadataFromParams(
          preview.params,
          outputWidth: size.$1,
          outputHeight: size.$2,
        ),
      );
      state = state.copyWith(
        history: [
          snapshot,
          ...state.history,
        ].take(GenerationResultLifecycleService.historyLimit).toList(),
      );
      _streamPreviews.remove(key);
    }
    _retainHistoryCaches();
  }

  Uint8List _materializePreview(_RememberedStreamPreview preview) {
    final placement = preview.focusedPreviewPlacement;
    if (placement == null || !placement.isValid) return preview.bytes;
    final source = img.decodeImage(placement.sourceImage);
    final generated = img.decodeImage(preview.bytes);
    final mask = placement.maskImage == null
        ? null
        : img.decodeImage(placement.maskImage!);
    if (source == null || generated == null) return preview.bytes;
    final x = (placement.xPercent * source.width)
        .round()
        .clamp(0, max(0, source.width - 1))
        .toInt();
    final y = (placement.yPercent * source.height)
        .round()
        .clamp(0, max(0, source.height - 1))
        .toInt();
    final width = (placement.widthPercent * source.width)
        .round()
        .clamp(1, max(1, source.width - x))
        .toInt();
    final height = (placement.heightPercent * source.height)
        .round()
        .clamp(1, max(1, source.height - y))
        .toInt();
    img.Image patch;
    if (mask == null) {
      patch = PicaLanczosResizer.resizeImage(
        generated,
        width: width,
        height: height,
      );
    } else {
      final requestPreview = PicaLanczosResizer.resizeImage(
        generated,
        width: mask.width,
        height: mask.height,
      );
      patch = PicaLanczosResizer.resizeImage(
        InpaintMaskUtils.applyCompositeMaskToGeneratedImage(
          requestPreview,
          mask,
        ),
        width: width,
        height: height,
      );
    }
    final composed = img.Image.from(source, noAnimation: true);
    img.compositeImage(
      composed,
      patch,
      dstX: x,
      dstY: y,
      dstW: width,
      dstH: height,
      blend: mask == null ? img.BlendMode.direct : img.BlendMode.alpha,
    );
    return Uint8List.fromList(img.encodePng(composed, level: 1));
  }

  List<StreamPreviewSlot> _replacePreviewSlot(
    List<StreamPreviewSlot> slots,
    StreamPreviewSlot replacement,
  ) {
    final found = slots.any(
      (slot) => slot.imageNumber == replacement.imageNumber,
    );
    final result = <StreamPreviewSlot>[
      for (final slot in slots)
        if (slot.imageNumber == replacement.imageNumber) replacement else slot,
      if (!found) replacement,
    ];
    result.sort((a, b) => a.imageNumber.compareTo(b.imageNumber));
    return result;
  }

  void skipCurrentRequest() {
    final coordinator = _coordinator;
    final handle = _activeRun;
    if (coordinator == null || handle == null) {
      cancel();
      return;
    }
    _appendFailedSnapshots(_activeRunId);
    if (!coordinator.skipCurrentRequest(handle)) return;
    state = state.copyWith(clearStreamPreview: true);
  }

  void cancel() {
    if (_isDisposed) return;
    final runId = _activeRunId;
    _activeInvocationId = 0;
    _generationInvocationStarting = false;
    _activeComparisonSource = null;
    _appendFailedSnapshots(runId);
    final coordinator = _coordinator;
    final handle = _activeRun;
    if (coordinator != null && handle != null) coordinator.cancel(handle);
    _activeRunId = ++_runCounter;
    state = state.copyWith(
      status: GenerationStatus.cancelled,
      progress: 0,
      currentImage: 0,
      totalImages: 0,
      clearStreamPreview: true,
    );
  }

  /// Registers a result produced outside the normal generation stream.
  ///
  /// [comparisonSourceImage] is supplied by single-source transformations such
  /// as NovelAI upscale and local upscale so their result can be compared.
  Future<String?> registerExternalImage(
    Uint8List imageBytes, {
    required ImageParams params,
    int? width,
    int? height,
    Uint8List? comparisonSourceImage,
    bool saveToLocal = false,
    String? saveDirectoryPath,
    bool syncToGalleryIndex = true,
    bool addToDisplay = false,
    bool replaceCurrentDisplay = false,
    bool embedNaiMetadata = true,
  }) async {
    assert(!addToDisplay || !replaceCurrentDisplay);
    if (_isDisposed) return null;
    final epoch = _lifecycleEpoch;
    final lifecycle = _lifecycle();
    final prepared = await lifecycle.prepareExternalImage(
      imageBytes,
      params: params,
      width: width,
      height: height,
      comparisonSource: comparisonSourceImage == null
          ? null
          : _comparisonSourceFor(comparisonSourceImage),
      embedNaiMetadata: embedNaiMetadata,
    );
    if (!_isCurrentLifecycle(epoch)) return null;
    var image = prepared.image;
    final shouldDisplay = addToDisplay || replaceCurrentDisplay;
    state = state.copyWith(
      currentImages: replaceCurrentDisplay
          ? [image]
          : addToDisplay
          ? [image, ...state.currentImages]
          : state.currentImages,
      history: [
        image,
        ...state.history,
      ].take(GenerationResultLifecycleService.historyLimit).toList(),
      displayImages: replaceCurrentDisplay
          ? [image]
          : addToDisplay
          ? [image, ...state.displayImages]
          : state.displayImages,
      displayWidth: shouldDisplay ? image.width : state.displayWidth,
      displayHeight: shouldDisplay ? image.height : state.displayHeight,
    );
    _retainHistoryCaches();
    if (saveToLocal) {
      final result = await _saveImages(
        [image],
        prepared.params,
        epoch: epoch,
        directoryPath: saveDirectoryPath,
        syncToGalleryIndex: syncToGalleryIndex,
      );
      image = result.images.first;
      return image.filePath;
    }
    lifecycle.preloadMetadata([image]);
    return null;
  }

  Future<GenerationSaveResult> _saveImages(
    List<GeneratedImage> images,
    ImageParams params, {
    required int epoch,
    String? directoryPath,
    bool syncToGalleryIndex = true,
  }) async {
    if (!_isCurrentLifecycle(epoch)) {
      return GenerationSaveResult(images, const []);
    }
    final fixed = ref.read(fixedTagsNotifierProvider);
    final lifecycle = _lifecycle();
    final result = await lifecycle.saveImages(
      images,
      params,
      snapshot: GenerationSaveSnapshot(
        fixedPrefixTags: fixed.enabledPrefixes
            .sortedByOrder()
            .map((entry) => entry.weightedContent)
            .where((content) => content.isNotEmpty)
            .toList(),
        fixedSuffixTags: fixed.enabledSuffixes
            .sortedByOrder()
            .map((entry) => entry.weightedContent)
            .where((content) => content.isNotEmpty)
            .toList(),
        fixedNegativePrefixTags: fixed.negativeEnabledPrefixes
            .sortedByOrder()
            .map((entry) => entry.weightedContent)
            .where((content) => content.isNotEmpty)
            .toList(),
        fixedNegativeSuffixTags: fixed.negativeEnabledSuffixes
            .sortedByOrder()
            .map((entry) => entry.weightedContent)
            .where((content) => content.isNotEmpty)
            .toList(),
        useCoords: params.useCoords,
      ),
      directoryPath: directoryPath,
      syncToGalleryIndex: syncToGalleryIndex,
    );
    if (!_isCurrentLifecycle(epoch)) return result;
    for (final image in result.images) {
      if (image.filePath != null) _replaceImage(image.id, image);
    }
    return result;
  }

  void _replaceImage(String id, GeneratedImage replacement) {
    state = state.copyWith(
      currentImages: state.currentImages
          .map((image) => image.id == id ? replacement : image)
          .toList(),
      history: state.history
          .map((image) => image.id == id ? replacement : image)
          .toList(),
      displayImages: state.displayImages
          .map((image) => image.id == id ? replacement : image)
          .toList(),
    );
    _retainHistoryCaches();
  }

  void clearCurrent() {
    state = state.copyWith(currentImages: [], status: GenerationStatus.idle);
    _retainHistoryCaches();
  }

  void clearError() {
    if (state.status == GenerationStatus.error) {
      state = state.copyWith(status: GenerationStatus.idle, errorMessage: null);
    }
  }

  void clearHistory() {
    state = state.copyWith(currentImages: [], history: []);
    _retainHistoryCaches();
  }

  void updateDisplayImages(List<GeneratedImage> images) {
    state = state.copyWith(displayImages: images);
  }

  void updateImageFilePath(String imageId, String filePath) {
    final image = state.findImageById(imageId);
    if (image == null) return;
    _replaceImage(imageId, image.copyWithFilePath(filePath));
  }

  Future<ImageParams> _prepareVibesForGeneration(ImageParams params) async {
    if (!AnlasCalculator.usesVibeReferences(params) ||
        !params.capabilities.supportsEncodedVibeTransfer) {
      return params;
    }
    final encoded = await ref
        .read(generationParamsNotifierProvider.notifier)
        .ensureVibeReferencesEncoded(
          params.vibeReferencesV4,
          model: params.model,
          syncCurrentState: true,
        );
    return identical(encoded, params.vibeReferencesV4)
        ? params
        : params.copyWith(vibeReferencesV4: encoded);
  }

  PromptPresetResolution _resolvePromptPresets(ImageParams params) {
    final quality = ref.read(qualityPresetNotifierProvider);
    final uc = ref.read(ucPresetNotifierProvider);
    return resolvePromptPresetSettings(
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      qualityMode: quality.mode,
      qualityContent: ref
          .read(qualityPresetNotifierProvider.notifier)
          .getEffectiveContent(params.model),
      ucPresetType: uc.presetType,
      ucPresetContent: ref
          .read(ucPresetNotifierProvider.notifier)
          .getEffectiveContent(params.model),
      useCustomUcPreset: uc.isCustom,
    );
  }

  List<CharacterPrompt> _convertCharactersToApiFormat(
    ui_character.CharacterPromptConfig config,
  ) {
    return CharacterConversionService(
      aliasResolver: ref
          .read(aliasResolverServiceProvider.notifier)
          .resolveAliases,
    ).convert(config).characters;
  }

  Future<String> generateAndApplyRandomPrompt({
    int? seed,
    String? model,
  }) async {
    if (_isDisposed) return '';
    final epoch = _lifecycleEpoch;
    final params = ref.read(generationParamsNotifierProvider);
    final selectedModel = model ?? params.model;
    final capabilities = ModelCapabilityRegistry.of(selectedModel);
    final result = await ref
        .read(promptConfigNotifierProvider.notifier)
        .generateRandomPrompt(model: selectedModel, seed: seed);
    final formatted = NaiPromptFormatter.format(result.mainPrompt);
    if (!_isCurrentLifecycle(epoch)) return formatted;
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(formatted);
    if (result.hasCharacters &&
        capabilities.randomPromptProfile.supportsCharacterPrompts) {
      final characters = result.toCharacterPrompts().map((character) {
        return character.copyWith(
          prompt: NaiPromptFormatter.format(character.prompt),
          negativePrompt: character.negativePrompt.isEmpty
              ? character.negativePrompt
              : NaiPromptFormatter.format(character.negativePrompt),
        );
      }).toList();
      ref.read(characterPromptNotifierProvider.notifier).replaceAll(characters);
    } else if (result.noHumans) {
      ref.read(characterPromptNotifierProvider.notifier).clearAll();
    }
    return formatted;
  }

  void _saveVibeEncodings(Map<int, String> encodings) {
    for (final entry in encodings.entries) {
      if (entry.value.isEmpty) continue;
      ref
          .read(generationParamsNotifierProvider.notifier)
          .updateVibeReference(entry.key, vibeEncoding: entry.value);
    }
  }

  NaiImageMetadata _metadataFromParams(
    ImageParams params, {
    required int outputWidth,
    required int outputHeight,
  }) {
    final effective = params.copyWith(width: outputWidth, height: outputHeight);
    final charCaptions = <Map<String, dynamic>>[];
    final charNegCaptions = <Map<String, dynamic>>[];
    for (var index = 0; index < effective.characters.length; index++) {
      final character = effective.characters[index];
      final center = CharacterCenterResolver.resolve(
        character,
        index: index,
        total: effective.characters.length,
        useCoords: effective.useCoords,
      );
      final x = center.x;
      final y = center.y;
      charCaptions.add({
        'char_caption': character.prompt,
        'centers': [
          {'x': x, 'y': y},
        ],
      });
      charNegCaptions.add({
        'char_caption': character.negativePrompt,
        'centers': [
          {'x': x, 'y': y},
        ],
      });
    }
    final comment = ImageSaveUtils.buildCommentJson(
      params: effective,
      actualSeed: effective.seed,
      charCaptions: charCaptions,
      charNegCaptions: charNegCaptions,
      useCoords: effective.useCoords,
    );
    final raw = jsonEncode(comment);
    return NaiImageMetadata.fromNaiComment({
      'Comment': raw,
      'Software': 'NovelAI',
      'Source': ImageSaveUtils.getModelSourceName(effective.model),
    }, rawJson: raw);
  }
}
