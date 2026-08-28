import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/image_generation_provider.dart';
import 'generation_preparation_runtime.dart';
import 'generation_tool_results.dart';
import 'generation_workspace_path_resolver.dart';

class GenerationExecutionService {
  GenerationExecutionService(
    this._ref, {
    required GenerationWorkspacePathResolver pathResolver,
    required int maxGenerateCount,
    required AgentChatResourceReference Function(String imageId)
    generatedImageReference,
  }) : _pathResolver = pathResolver,
       _maxGenerateCount = maxGenerateCount,
       _generatedImageReference = generatedImageReference;
  final Ref _ref;
  final GenerationWorkspacePathResolver _pathResolver;
  final int _maxGenerateCount;
  final AgentChatResourceReference Function(String imageId)
  _generatedImageReference;
  Future<AgentToolResult> generate(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final prepared = args['_prepared_generation'] as GenerationPreparation;
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return generationErrorResult('Parameter "prompt" is required.');
    }

    final requestedCount = (args['count'] as num?)?.toInt() ?? 1;
    if (requestedCount < 1 || requestedCount > _maxGenerateCount) {
      return generationErrorResult(
        'Parameter "count" must be between 1 and $_maxGenerateCount.',
      );
    }
    final count = requestedCount;
    final base = prepared.params;
    final requestedSeed = (args['seed'] as num?)?.toInt() ?? -1;
    final width = (args['width'] as num?)?.toInt() ?? base.width;
    final height = (args['height'] as num?)?.toInt() ?? base.height;
    final resolutionIssue = NaiResolutionAdapter.validateGenerationResolution(
      width,
      height,
    );
    if (resolutionIssue != null) {
      return generationErrorResult(
        'Invalid generation resolution ${width}x$height. Width and height '
        'must be multiples of 64, each side must be between 64 and '
        '${NaiResolutionAdapter.generationMaxSide}, and total pixels must '
        'not exceed ${NaiResolutionAdapter.officialMaxPixels}. Nearest valid '
        'size: ${resolutionIssue.suggestedWidth}x'
        '${resolutionIssue.suggestedHeight}.',
      );
    }
    final negativePrompt =
        (args['negative_prompt'] as String?)?.trim() ?? base.negativePrompt;

    // img2img / inpaint：提供 source_image 才启用；未提供时强制纯文生图，
    // 不受生成页当前 img2img 状态影响（请求构建器按 action 门控源图）。
    Uint8List? sourceBytes = prepared.sourceImage;
    Uint8List? maskBytes = prepared.maskImage;
    var action = prepared.params.action;
    final sourceImagePath = (args['source_image'] as String?)?.trim() ?? '';
    if (sourceImagePath.isNotEmpty) {
      String resolvedSourcePath;
      try {
        resolvedSourcePath = await _pathResolver.resolveLocalImagePath(
          sourceImagePath,
        );
      } on Object {
        return generationErrorResult('Source image path is not permitted.');
      }
      final sourceFile = File(resolvedSourcePath);
      if (!sourceFile.existsSync()) {
        return generationErrorResult('Source image not found.');
      }
      sourceBytes = await sourceFile.readAsBytes();
      final maskImagePath = (args['mask_image'] as String?)?.trim() ?? '';
      if (maskImagePath.isNotEmpty) {
        String resolvedMaskPath;
        try {
          resolvedMaskPath = await _pathResolver.resolveLocalImagePath(
            maskImagePath,
          );
        } on Object {
          return generationErrorResult('Mask image path is not permitted.');
        }
        final maskFile = File(resolvedMaskPath);
        if (!maskFile.existsSync()) {
          return generationErrorResult('Mask image not found.');
        }
        maskBytes = await maskFile.readAsBytes();
        action = ImageGenerationAction.infill;
      } else {
        action = ImageGenerationAction.img2img;
      }
    }
    double? clamp01Ratio(String key) {
      final raw = (args[key] as num?)?.toDouble();
      if (raw == null) {
        return null;
      }
      return raw.clamp(0.0, 0.99);
    }

    final strength = clamp01Ratio('strength');
    final noise = clamp01Ratio('noise');
    final inpaintStrength = clamp01Ratio('inpaint_strength');

    // 用户停止时应连正在进行的 NAI 生成一起取消。
    void cancelRunningGeneration() {
      try {
        _ref.read(imageGenerationNotifierProvider.notifier).cancel();
      } catch (e) {
        AppLogger.w('cancel generation failed: $e', 'AgentChat');
      }
    }

    // 生成页忙时按顺序排队等待（默认行为）；空闲则立即通过。
    onUpdate?.call(generationProgressResult('Checking generation page...'));
    final pageReady = await _waitIfBusy(
      timeout: const Duration(seconds: 300),
      signal: signal,
      onAborted: cancelRunningGeneration,
    );
    if (!pageReady) {
      return generationErrorResult(
        'Another generation is still running after 300s. Check '
        'get_generation_status.',
      );
    }

    // 生成间隔冷却中 generate() 会静默跳过，必须先等冷却结束。
    final cooldown = _ref.read(generationCooldownProvider);
    if (cooldown.isActive) {
      onUpdate?.call(
        generationProgressResult(
          'Waiting for generation cooldown (${cooldown.remainingSeconds}s)...',
        ),
      );
      await _ref.read(generationCooldownProvider.notifier).waitUntilAvailable();
      throwIfAborted(signal);
    }

    try {
      onUpdate?.call(generationProgressResult('Generating $count image(s)...'));
      final params = base.copyWith(
        prompt: prompt,
        negativePrompt: negativePrompt,
        width: width,
        height: height,
        // count > 1 时应用原生管线会给每批随机种子（与生成页一致）。
        seed: requestedSeed,
        nSamples: count,
        action: action,
        sourceImage: sourceBytes,
        maskImage: maskBytes,
        strength: strength ?? base.strength,
        noise: noise ?? base.noise,
        inpaintStrength: inpaintStrength ?? base.inpaintStrength,
      );
      final previousImageIds = _ref
          .read(imageGenerationNotifierProvider)
          .currentImages
          .map((image) => image.id)
          .toList(growable: false);
      var lastProgress = -1;
      final invocation = _ref
          .read(imageGenerationNotifierProvider.notifier)
          .generate(params, batchSizeOverride: prepared.batchSize);
      final finished = await _waitForCompletion(
        invocation: invocation,
        expectedImages: count,
        signal: signal,
        onAborted: cancelRunningGeneration,
        onTick: () {
          // 实时转发生成页进度（第几张/共几张 + 百分比）到工具活动卡片。
          final state = _ref.read(imageGenerationNotifierProvider);
          if (state.status != GenerationStatus.generating) {
            return;
          }
          final percent = (state.progress * 100).round();
          if (percent != lastProgress) {
            lastProgress = percent;
            onUpdate?.call(
              generationProgressResult(
                'Generating image '
                '${state.currentImage}/${state.totalImages}... $percent%',
              ),
            );
          }
        },
      );
      if (!finished) {
        return generationErrorResult(
          'Generation timed out or was interrupted. Check '
          'get_generation_status for the latest state.',
        );
      }
      final state = _ref.read(imageGenerationNotifierProvider);
      if (state.status == GenerationStatus.error) {
        return generationErrorResult(
          'Generation failed: ${state.errorMessage ?? 'unknown error'}.',
        );
      }
      if (state.status == GenerationStatus.cancelled) {
        return generationErrorResult('Generation was cancelled.');
      }
      final currentImageIds = state.currentImages
          .map((image) => image.id)
          .toList(growable: false);
      if (state.status != GenerationStatus.completed ||
          currentImageIds.isEmpty ||
          _sameIds(currentImageIds, previousImageIds)) {
        return generationErrorResult(
          'Generation was not started (authentication may be required).',
        );
      }
      onUpdate?.call(generationProgressResult('Saving images...'));
      // 等待自动保存回填 filePath（保存是异步的，随张数放宽时限）。
      final saveDeadline = DateTime.now().add(
        Duration(seconds: 30 + 10 * count),
      );
      while (DateTime.now().isBefore(saveDeadline)) {
        throwIfAborted(signal);
        if (_ref
            .read(imageGenerationNotifierProvider)
            .currentImages
            .every((image) => image.filePath != null)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final report = <Map<String, dynamic>>[];
      final savedFiles = <String>[];
      for (final image
          in _ref.read(imageGenerationNotifierProvider).currentImages) {
        final reference = _generatedImageReference(image.id);
        if (image.filePath case final path?) savedFiles.add(path);
        report.add({
          'seed': image.metadata?.seed,
          'size': '${image.width}x${image.height}',
          'saved': image.filePath != null,
          'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
            reference,
          ),
        });
      }
      final content = <ToolResultContent>[
        ToolResultTextContent(jsonEncode({'ok': true, 'images': report})),
      ];
      for (final image
          in _ref.read(imageGenerationNotifierProvider).currentImages) {
        final thumbnail = await DisplayThumbnailUtils.normalize(image.bytes);
        final mime = thumbnail == null
            ? null
            : detectSupportedImageMimeType(thumbnail);
        if (thumbnail != null && mime != null) {
          content.add(
            ToolResultImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: mime,
                  base64Data: base64Encode(thumbnail),
                ),
              ),
            ),
          );
        }
      }
      return AgentToolResult(
        content: content,
        details: <String, dynamic>{
          'images': report,
          if (savedFiles.isNotEmpty) ...{
            'files': savedFiles,
            'preferFileImages': true,
          },
        },
      );
    } on Object catch (error) {
      AppLogger.w('Agent generation failed: $error', 'AgentChat');
      return generationErrorResult('Generation failed to start.');
    }
  }

  /// 排队等待：生成页忙时等其结束；空闲立即通过（不空转）。
  Future<bool> _waitIfBusy({
    required Duration timeout,
    AbortSignal? signal,
    void Function()? onAborted,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (signal?.aborted == true) {
        onAborted?.call();
        throwIfAborted(signal);
      }
      final status = _ref.read(imageGenerationNotifierProvider).status;
      if (status != GenerationStatus.generating) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// 等待刚触发的 generation invocation 真正结束。
  ///
  /// 基础超时随 [expectedImages] 放宽；生成推进中（进度签名变化）自动
  /// 续期，因此大批量不会因固定时限被误判超时。
  Future<bool> _waitForCompletion({
    required Future<void> invocation,
    required int expectedImages,
    required AbortSignal? signal,
    required void Function()? onAborted,
    required void Function()? onTick,
  }) async {
    var invocationCompleted = false;
    Object? invocationError;
    StackTrace? invocationStackTrace;
    unawaited(
      invocation.then<void>(
        (_) => invocationCompleted = true,
        onError: (Object error, StackTrace stackTrace) {
          invocationError = error;
          invocationStackTrace = stackTrace;
          invocationCompleted = true;
        },
      ),
    );
    var deadline = DateTime.now().add(
      Duration(seconds: 240 + 120 * (expectedImages - 1)),
    );
    var lastSignature = '';
    while (DateTime.now().isBefore(deadline)) {
      if (signal?.aborted == true) {
        onAborted?.call();
        throwIfAborted(signal);
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (signal?.aborted == true) {
        onAborted?.call();
        throwIfAborted(signal);
      }
      onTick?.call();
      if (invocationCompleted) {
        if (invocationError != null) {
          Error.throwWithStackTrace(invocationError!, invocationStackTrace!);
        }
        return true;
      }
      final state = _ref.read(imageGenerationNotifierProvider);
      final status = state.status;
      if (status == GenerationStatus.generating) {
        // 有进度推进就续期，只有彻底停滞才等到超时。
        final signature =
            '${state.currentImage}/${state.totalImages}/'
            '${(state.progress * 100).round()}';
        if (signature != lastSignature) {
          lastSignature = signature;
          deadline = DateTime.now().add(const Duration(seconds: 180));
        }
        continue;
      }
    }
    return false;
  }

  bool _sameIds(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // queue_image_task
  // -------------------------------------------------------------------------
}
