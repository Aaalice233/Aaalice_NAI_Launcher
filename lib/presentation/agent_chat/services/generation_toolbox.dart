import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_result.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/image/image_params.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../../data/models/queue/replication_task.dart';
import 'prompt_toolbox.dart';

AgentToolResult _textResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
  );
}

AgentToolResult _errorResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
    isError: true,
  );
}

/// 生成 / 反推工具集：桥接应用的图片生成管线、任务队列与 VLM 反推。
///
/// - `interrogate_image`：读本地图片反推提示词；对话模型支持图片输入时
///   直接解析，专用 reverse 模型仅作 fallback（不再强制配置）；
/// - `generate_image`：以当前生成页参数为基底同步生成，`count` 直接映射
///   应用原生的「生成数量」（nSamples，应用内逐批循环，最多 8 张），支持
///   source_image/mask 切 img2img/infill，返回保存路径与缩略图；
/// - `queue_image_task`：批量写入生成队列并可选自动启动；
/// - `get_generation_status`：生成进度 + 队列统计 + 最近产物；
/// - `get/update_generation_settings`：读写模型/采样器/步数/CFG 等页面
///   设置（持久化，UI 即时生效）。
class GenerationToolbox {
  GenerationToolbox(
    this._ref, {
    String? workspaceDir,
    bool allowOutsideWorkspace = false,
  }) : _fileEnv = DartIoExecutionEnv(
         workingDirectory: workspaceDir,
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       );

  static const int maxGenerateCount = 8;

  final Ref _ref;
  final DartIoExecutionEnv _fileEnv;

  List<AgentTool> tools() {
    return [
      DefinedAgentTool(
        name: 'interrogate_image',
        label: 'Interrogate Image',
        description:
            'Reverse-engineer a NovelAI prompt from an image. '
            'Returns English comma-separated tags. Routing: uses the '
            'current chat model directly when it supports image input; '
            'the dedicated "reverse" vision model (Settings > '
            'Integrations) is only a fallback and is NOT required. '
            'Requirements: "path" must be an existing local image file '
            '(workspace-relative or absolute).',
        parameters: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description':
                  'Image file path (workspace-relative or absolute).',
            },
          },
          'required': ['path'],
        },
        executeFn: (_, params) => _interrogate(params),
      ),
      DefinedAgentTool(
        name: 'generate_image',
        label: 'Generate Image',
        description:
            'SYNCHRONOUS image generation (the default): waits for the '
            'images to finish and shows them as thumbnails in the chat. '
            'Uses the current generation page settings, overriding prompt '
            '/ negative_prompt / width / height / count / seed. '
            'Important: "count" generates N variations of the SAME prompt '
            '(e.g. count=3 -> three versions of one prompt). For several '
            'DIFFERENT prompts, call this tool once per prompt instead. '
            '"prompt" is required; write English danbooru-style tags. '
            '(2) "count" = how many variations of the SAME prompt; minimum '
            '1, maximum $maxGenerateCount. It maps 1:1 to the app '
            '"generation count" setting and runs on the app-native batch '
            'pipeline as sequential requests (429 concurrency limits are '
            'retried automatically). Total images = count x the "images '
            'per request" app setting (default 1, so count usually equals '
            'total). '
            '(3) "width"/"height": prefer NAI presets — Normal portrait '
            '832x1216, landscape 1216x832, square 1024x1024; Large '
            '1024x1536 / 1536x1024 / 1472x1472; Wallpaper 1088x1920 / '
            '1920x1088; Small 512x768 / 768x512 / 640x640. Custom sizes '
            'are allowed but limited: width and height MUST be multiples '
            'of 64 (minimum 64), each side at most 2048, total pixels at '
            'most 2088960 (wallpaper level). Omit to reuse the generation '
            'page size. '
            '(4) "seed": omit or -1 for random. A fixed seed is honored '
            'only when count = 1; with count > 1 every image gets an '
            'independent random seed (identical to the generation page). '
            '(5) img2img/inpaint: provide "source_image" (local file path) '
            'to base the generation on an existing image; "strength" '
            '(0-0.99) controls how different the result may be; add '
            '"mask_image" (same size as source, white = redrawn area) to '
            'switch to inpaint with "inpaint_strength" (0-0.99); "noise" '
            '(0-0.99) adds variation. Without "source_image" this is plain '
            'text-to-image regardless of the generation page img2img '
            'state. '
            'If a generation is already running, this waits up to 300s and '
            'runs in order. Returns the saved file paths plus thumbnails, '
            'which appear in the chat. For normal "draw/generate" requests '
            'always use this tool instead of queue_image_task.',
        parameters: const {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Positive prompt; English danbooru-style tags.',
            },
            'negative_prompt': {
              'type': 'string',
              'description':
                  'Omit to reuse the generation page negative '
                  'prompt.',
            },
            'width': {
              'type': 'number',
              'description':
                  'Width in px; must be a multiple of 64. Prefer preset '
                  'values (512/640/768/832/1024/1088/1216/1472/1536/1920).',
            },
            'height': {
              'type': 'number',
              'description':
                  'Height in px; must be a multiple of 64. Prefer preset '
                  'values (768/640/512/1216/1024/832/1536/1472/1920/1088).',
            },
            'count': {
              'type': 'number',
              'minimum': 1,
              'maximum': maxGenerateCount,
              'description':
                  'How many variations of the SAME prompt to generate '
                  '(max $maxGenerateCount). Default 1. For DIFFERENT '
                  'prompts, call the tool once per prompt.',
            },
            'seed': {
              'type': 'number',
              'description':
                  'Omit or -1 for random. A fixed seed only '
                  'applies when count = 1.',
            },
            'source_image': {
              'type': 'string',
              'description': 'Local image file path to use as img2img base.',
            },
            'mask_image': {
              'type': 'string',
              'description':
                  'Local mask file path (white = redraw area, '
                  'same size as source) to switch to inpaint.',
            },
            'strength': {
              'type': 'number',
              'description':
                  'img2img strength 0-0.99. Higher = further from '
                  'the source image.',
            },
            'noise': {
              'type': 'number',
              'description': 'Extra img2img noise 0-0.99.',
            },
            'inpaint_strength': {
              'type': 'number',
              'description':
                  'Inpaint strength 0-0.99 (only with '
                  'mask_image).',
            },
          },
          'required': ['prompt'],
        },
        executeWithControl: _generate,
      ),
      DefinedAgentTool(
        name: 'queue_image_task',
        label: 'Queue Image Task',
        description:
            'ASYNCHRONOUS queueing: enqueues N IDENTICAL tasks (same '
            'prompt) into the generation queue and returns immediately '
            'WITHOUT producing images in the chat. "count" only creates '
            'N copies of the SAME prompt; for DIFFERENT prompts call this '
            'tool once per prompt (or use generate_image for synchronous '
            'results). ONLY use this when the user explicitly asks to '
            'add tasks to a queue / background batch; for normal image '
            'requests use generate_image instead. Requirements: "prompt" '
            'is required; "count" 1-50, capped by the queue\'s remaining '
            'capacity (tool reports an error when full); "auto_start" '
            'starts the queue after adding (default true). Queue outputs '
            'do NOT appear automatically; get_recent_images can retrieve '
            'them later.',
        parameters: const {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Positive prompt; English danbooru-style tags.',
            },
            'negative_prompt': {
              'type': 'string',
              'description':
                  'Omit to reuse the generation page negative '
                  'prompt.',
            },
            'count': {
              'type': 'number',
              'minimum': 1,
              'maximum': kMaxQueueCapacity,
              'description':
                  'How many identical tasks to enqueue. Default 1. '
                  'Maximum 50 and capped by remaining queue capacity.',
            },
            'auto_start': {
              'type': 'boolean',
              'description': 'Start the queue after adding. Default true.',
            },
          },
          'required': ['prompt'],
        },
        executeFn: (_, params) => _queueTask(params),
      ),
      DefinedAgentTool(
        name: 'get_generation_status',
        label: 'Get Generation Status',
        description:
            'Report current generation progress, queue statistics, '
            'and the file paths of recently generated images.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async => _textResult(_statusJson()),
      ),
      DefinedAgentTool(
        name: 'get_recent_images',
        label: 'Get Recent Images',
        description:
            'Return recently generated images (including queue outputs) '
            'as chat thumbnails plus file paths for history review or when '
            'visual context is useful.',
        parameters: const {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'number',
              'description': 'Max images to return, 1-20. Default 6.',
            },
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _recentImages(params),
      ),
      DefinedAgentTool(
        name: 'get_generation_settings',
        label: 'Get Generation Settings',
        description:
            'Read all image generation settings: model, sampler, '
            'steps, scale (CFG), cfg_rescale, noise_schedule, uc_preset, '
            'quality_toggle, variety_plus, decrisp, smea flags, '
            'transparent_background, width/height, seed, generation count, '
            'action (generate/img2img/infill) and strength values. Call '
            'this before update_generation_settings to learn current values '
            'and valid model ids.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async => _textResult(_settingsJson()),
      ),
      DefinedAgentTool(
        name: 'update_generation_settings',
        label: 'Update Generation Settings',
        description:
            'Persistently change generation page settings. Only '
            'provided fields are changed. Requirements: "model" accepts an '
            'exact model id OR a friendly name like "v5", "v5 curated", '
            '"v4.5 full", "v3" (get_generation_settings lists all); '
            'switching model may auto-adjust scale/steps defaults. '
            '"sampler" examples: k_euler_ancestral, k_euler, k_dpmpp_2m, '
            'k_dpmpp_2m_sde. "steps" clamped to 1-50; "scale" 0-10; '
            '"cfg_rescale" 0-1; "noise_schedule" one of '
            'native/karras/exponential/polyexponential (V4+ models, '
            '"light" on V5); "uc_preset" integer preset index; "seed" -1 '
            'for random; the rest are booleans. "transparent_background" '
            'is the transparency switch — enable it when the user asks '
            'for a transparent background (V5 renders native alpha; '
            'optionally reinforce with the prompt tags). Changes apply to '
            'the generation page UI immediately and persist across '
            'restarts.',
        parameters: const {
          'type': 'object',
          'properties': {
            'model': {'type': 'string'},
            'sampler': {'type': 'string'},
            'steps': {'type': 'number'},
            'scale': {'type': 'number'},
            'cfg_rescale': {'type': 'number'},
            'noise_schedule': {'type': 'string'},
            'uc_preset': {'type': 'number'},
            'quality_toggle': {'type': 'boolean'},
            'variety_plus': {'type': 'boolean'},
            'decrisp': {'type': 'boolean'},
            'transparent_background': {'type': 'boolean'},
            'smea': {'type': 'boolean'},
            'smea_dyn': {'type': 'boolean'},
            'seed': {'type': 'number', 'description': '-1 for random.'},
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _updateSettings(params),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // interrogate_image
  // -------------------------------------------------------------------------

  Future<String> _resolveLocalImagePath(String rawPath) async {
    final result = await _fileEnv.absolutePath(rawPath);
    final resolved = result.valueOrNull;
    if (resolved == null) {
      throw StateError(result.errorOrNull?.message ?? 'Invalid image path');
    }
    return resolved;
  }

  Future<AgentToolResult> _interrogate(Map<String, dynamic> args) async {
    final path = (args['path'] as String?)?.trim() ?? '';
    if (path.isEmpty) {
      return _errorResult('Parameter "path" is required.');
    }
    String resolvedPath;
    try {
      resolvedPath = await _resolveLocalImagePath(path);
    } catch (e) {
      return _errorResult('Image path is not permitted: $e');
    }
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return _errorResult('Image not found: $resolvedPath');
    }
    // 路由优先级：支持图片输入的对话模型直读 > 专用 reverse 模型（fallback）。
    final config = _ref.read(promptAssistantConfigProvider);
    final chatProviderId = config.routing.providerIdFor(AssistantTaskType.chat);
    final chatProvider = config.providers
        .where((p) => p.id == chatProviderId && p.enabled)
        .firstOrNull;
    final chatCapable = chatProvider != null && chatProvider.allowImageInput;
    final reverseProviderId = config.routing.providerIdFor(
      AssistantTaskType.reverse,
    );
    final reverseReady = config.providers.any(
      (p) => p.id == reverseProviderId && p.enabled,
    );
    if (!chatCapable && !reverseReady) {
      return _errorResult(
        'No image-capable model available for interrogation. Enable a chat '
        'provider with image input support, or configure a "reverse" task '
        'vision model in Settings > Integrations.',
      );
    }
    try {
      final bytes = await file.readAsBytes();
      final service = _ref.read(promptAssistantServiceProvider);
      // 对话模型支持图片时直接解析；失败或不可用时回退 reverse 路由。
      if (chatCapable) {
        try {
          final viaChat = await _collectInterrogation(
            service,
            bytes,
            AssistantTaskType.chat,
          );
          if (viaChat.isNotEmpty) {
            return _textResult(viaChat);
          }
          AppLogger.w(
            'interrogate via chat route returned empty prompt',
            'AgentChat',
          );
        } catch (e) {
          AppLogger.w('interrogate via chat route failed: $e', 'AgentChat');
          if (!reverseReady) {
            return _errorResult('Interrogation failed: $e');
          }
        }
      }
      final prompt = await _collectInterrogation(
        service,
        bytes,
        AssistantTaskType.reverse,
      );
      if (prompt.isEmpty) {
        return _errorResult(
          'Interrogation returned an empty prompt. The reverse model may not '
          'support image input.',
        );
      }
      return _textResult(prompt);
    } catch (e) {
      AppLogger.w('interrogate_image failed: $e', 'AgentChat');
      return _errorResult('Interrogation failed: $e');
    }
  }

  /// 按指定任务路由反推图片并聚合流式输出为完整提示词。
  Future<String> _collectInterrogation(
    PromptAssistantService service,
    Uint8List bytes,
    AssistantTaskType route,
  ) async {
    final buffer = StringBuffer();
    await for (final chunk in service.reverseImagePrompt(
      bytes,
      sessionId: 'agent_interrogate',
      taskType: route,
    )) {
      buffer.write(chunk.delta);
    }
    return buffer.toString().trim();
  }

  // -------------------------------------------------------------------------
  // generate_image
  // -------------------------------------------------------------------------

  Future<AgentToolResult> _generate(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return _errorResult('Parameter "prompt" is required.');
    }

    final requestedCount = (args['count'] as num?)?.toInt() ?? 1;
    if (requestedCount < 1 || requestedCount > maxGenerateCount) {
      return _errorResult(
        'Parameter "count" must be between 1 and $maxGenerateCount.',
      );
    }
    final count = requestedCount;
    final base = _ref.read(generationParamsNotifierProvider);
    final requestedSeed = (args['seed'] as num?)?.toInt() ?? -1;
    final width = (args['width'] as num?)?.toInt() ?? base.width;
    final height = (args['height'] as num?)?.toInt() ?? base.height;
    final negativePrompt =
        (args['negative_prompt'] as String?)?.trim() ?? base.negativePrompt;

    // img2img / inpaint：提供 source_image 才启用；未提供时强制纯文生图，
    // 不受生成页当前 img2img 状态影响（请求构建器按 action 门控源图）。
    Uint8List? sourceBytes;
    Uint8List? maskBytes;
    var action = ImageGenerationAction.generate;
    final sourceImagePath = (args['source_image'] as String?)?.trim() ?? '';
    if (sourceImagePath.isNotEmpty) {
      String resolvedSourcePath;
      try {
        resolvedSourcePath = await _resolveLocalImagePath(sourceImagePath);
      } catch (e) {
        return _errorResult('Source image path is not permitted: $e');
      }
      final sourceFile = File(resolvedSourcePath);
      if (!sourceFile.existsSync()) {
        return _errorResult('Source image not found: $resolvedSourcePath');
      }
      sourceBytes = await sourceFile.readAsBytes();
      final maskImagePath = (args['mask_image'] as String?)?.trim() ?? '';
      if (maskImagePath.isNotEmpty) {
        String resolvedMaskPath;
        try {
          resolvedMaskPath = await _resolveLocalImagePath(maskImagePath);
        } catch (e) {
          return _errorResult('Mask image path is not permitted: $e');
        }
        final maskFile = File(resolvedMaskPath);
        if (!maskFile.existsSync()) {
          return _errorResult('Mask image not found: $resolvedMaskPath');
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
    onUpdate?.call(_progressResult('Checking generation page...'));
    final pageReady = await _waitIfBusy(
      timeout: const Duration(seconds: 300),
      signal: signal,
      onAborted: cancelRunningGeneration,
    );
    if (!pageReady) {
      return _errorResult(
        'Another generation is still running after 300s. Check '
        'get_generation_status.',
      );
    }

    // 生成间隔冷却中 generate() 会静默跳过，必须先等冷却结束。
    final cooldown = _ref.read(generationCooldownProvider);
    if (cooldown.isActive) {
      onUpdate?.call(
        _progressResult(
          'Waiting for generation cooldown (${cooldown.remainingSeconds}s)...',
        ),
      );
      await _ref.read(generationCooldownProvider.notifier).waitUntilAvailable();
      throwIfAborted(signal);
    }

    try {
      onUpdate?.call(_progressResult('Generating $count image(s)...'));
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
      unawaited(
        _ref.read(imageGenerationNotifierProvider.notifier).generate(params),
      );
      var lastProgress = -1;
      final finished = await _waitForCompletion(
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
              _progressResult(
                'Generating image '
                '${state.currentImage}/${state.totalImages}... $percent%',
              ),
            );
          }
        },
      );
      if (!finished) {
        return _errorResult(
          'Generation timed out or was interrupted. Check '
          'get_generation_status for the latest state.',
        );
      }
      final state = _ref.read(imageGenerationNotifierProvider);
      if (state.status == GenerationStatus.error) {
        return _errorResult(
          'Generation failed: ${state.errorMessage ?? 'unknown error'}.',
        );
      }
      if (state.status == GenerationStatus.cancelled) {
        return _errorResult('Generation was cancelled.');
      }
      onUpdate?.call(_progressResult('Saving images...'));
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
      final files = <String>[];
      final report = <Map<String, dynamic>>[];
      for (final image
          in _ref.read(imageGenerationNotifierProvider).currentImages) {
        report.add({
          'seed': image.metadata?.seed,
          'size': '${image.width}x${image.height}',
          'file': image.filePath,
        });
        if (image.filePath != null) {
          files.add(image.filePath!);
        }
      }
      final content = <ToolResultContent>[
        ToolResultTextContent(jsonEncode({'ok': true, 'images': report})),
      ];
      return _resultWithImages(content, files, report);
    } catch (e) {
      return _errorResult('Generation failed to start: $e');
    }
  }

  AgentToolResult _progressResult(String text) {
    return AgentToolResult(
      content: [ToolResultTextContent(text)],
      details: const <String, dynamic>{},
    );
  }

  /// 组装结果：文本报告 + 缩略图；details 携带原图路径供 UI 展开原图。
  AgentToolResult _resultWithImages(
    List<ToolResultContent> content,
    List<String> files,
    List<Map<String, dynamic>> report,
  ) {
    return AgentToolResult(
      content: content,
      details: <String, dynamic>{'files': files, 'images': report},
    );
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

  /// 等待刚触发的生成本次完成（completed/error/cancelled）。
  ///
  /// 基础超时随 [expectedImages] 放宽；生成推进中（进度签名变化）自动
  /// 续期，因此大批量不会因固定时限被误判超时。
  Future<bool> _waitForCompletion({
    required int expectedImages,
    required AbortSignal? signal,
    required void Function()? onAborted,
    required void Function()? onTick,
  }) async {
    var deadline = DateTime.now().add(
      Duration(seconds: 240 + 120 * (expectedImages - 1)),
    );
    var lastSignature = '';
    var sawGenerating =
        _ref.read(imageGenerationNotifierProvider).status ==
        GenerationStatus.generating;
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
      final state = _ref.read(imageGenerationNotifierProvider);
      final status = state.status;
      if (status == GenerationStatus.generating) {
        sawGenerating = true;
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
      if (status == GenerationStatus.completed ||
          status == GenerationStatus.error ||
          status == GenerationStatus.cancelled) {
        return true;
      }
      // 生成完成后状态可能被外部重置为 idle：见过 generating 即视为完成。
      if (sawGenerating && status == GenerationStatus.idle) {
        return true;
      }
      // 尚未启动（idle 且未见 generating）：generate() 启动延迟，继续等。
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // queue_image_task
  // -------------------------------------------------------------------------

  Future<AgentToolResult> _queueTask(Map<String, dynamic> args) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return _errorResult('Parameter "prompt" is required.');
    }
    final requestedCount = (args['count'] as num?)?.toInt() ?? 1;
    if (requestedCount < 1 || requestedCount > kMaxQueueCapacity) {
      return _errorResult(
        'Parameter "count" must be between 1 and $kMaxQueueCapacity.',
      );
    }
    final remaining = _ref
        .read(replicationQueueNotifierProvider)
        .remainingCapacity;
    if (remaining <= 0) {
      return _errorResult(
        'Queue is full (capacity $kMaxQueueCapacity). Clear or complete tasks first.',
      );
    }
    final count = math.min(requestedCount, remaining);
    final autoStart = args['auto_start'] as bool? ?? true;
    final base = _ref.read(generationParamsNotifierProvider);
    final tasks = List.generate(count, (_) {
      return ReplicationTask.create(
        prompt: prompt,
        negativePrompt:
            (args['negative_prompt'] as String?)?.trim() ?? base.negativePrompt,
        source: ReplicationTaskSource.local,
        sampler: base.sampler,
        steps: base.steps,
        cfgScale: base.scale,
        model: base.model,
        width: base.width,
        height: base.height,
      );
    });
    try {
      final added = await _ref
          .read(replicationQueueNotifierProvider.notifier)
          .addAll(tasks);
      if (added == 0) {
        return _errorResult(
          'Queue is full (capacity $kMaxQueueCapacity). Clear or complete tasks first.',
        );
      }
      String started = 'not started';
      if (autoStart) {
        final result = await _ref
            .read(queueExecutionNotifierProvider.notifier)
            .startQueue();
        started = switch (result) {
          QueueStartResult.started => 'started',
          QueueStartResult.busy => 'busy (already running)',
          QueueStartResult.empty => 'empty',
          QueueStartResult.authRequired => 'authentication required',
        };
      }
      final queue = _ref.read(replicationQueueNotifierProvider);
      return _textResult(
        jsonEncode({
          'ok': true,
          'added': added,
          if (added < requestedCount) 'requested': requestedCount,
          'queue_pending': queue.count,
          'queue_started': started,
        }),
      );
    } catch (e) {
      return _errorResult('Failed to enqueue: $e');
    }
  }

  // -------------------------------------------------------------------------
  // get_generation_status
  // -------------------------------------------------------------------------

  String _statusJson() {
    final gen = _ref.read(imageGenerationNotifierProvider);
    final queue = _ref.read(replicationQueueNotifierProvider);
    final execution = _ref.read(queueExecutionNotifierProvider);
    return jsonEncode({
      'generation': {
        'status': gen.status.name,
        'progress': (gen.progress * 100).round(),
        'image': '${gen.currentImage}/${gen.totalImages}',
        if (gen.errorMessage != null) 'error': gen.errorMessage,
        'recent_files': [
          for (final image in gen.history.take(5))
            if (image.filePath != null) image.filePath!,
        ],
      },
      'queue': {
        'pending': queue.count,
        'completed': queue.completedCount,
        'failed': queue.failedCount,
        'execution': execution.status.name,
        'session_progress': (execution.progress * 100).round(),
      },
    });
  }

  // -------------------------------------------------------------------------
  // get/update_generation_settings
  // -------------------------------------------------------------------------

  String _settingsJson() {
    final params = _ref.read(generationParamsNotifierProvider);
    return jsonEncode({
      'model': params.model,
      'available_models': [
        for (final id in ImageModels.allModels)
          {'id': id, 'name': ImageModels.modelDisplayNames[id] ?? id},
      ],
      'sampler': params.sampler,
      'steps': params.steps,
      'scale': params.scale,
      'cfg_rescale': params.cfgRescale,
      'noise_schedule': params.noiseSchedule,
      'uc_preset': params.ucPreset,
      'quality_toggle': params.qualityToggle,
      'variety_plus': params.varietyPlus,
      'decrisp': params.decrisp,
      'smea': params.smea,
      'smea_dyn': params.smeaDyn,
      'smea_auto': params.smeaAuto,
      'transparent_background': params.transparentBackground,
      'width': params.width,
      'height': params.height,
      'seed': params.seed,
      'n_samples': params.nSamples,
      'action': params.action.name,
      'strength': params.strength,
      'noise': params.noise,
      'inpaint_strength': params.inpaintStrength,
    });
  }

  Future<AgentToolResult> _updateSettings(Map<String, dynamic> args) async {
    if (args.isEmpty) {
      return _errorResult('Provide at least one setting to change.');
    }
    final notifier = _ref.read(generationParamsNotifierProvider.notifier);
    final applied = <String, dynamic>{};

    // model 先应用（切换模型可能联动 steps/scale 默认值），随后显式字段覆盖。
    // 支持友好别名（v5 / v4.5 curated / v3 等），解析失败时列出可选模型。
    final model = (args['model'] as String?)?.trim();
    if (model != null && model.isNotEmpty) {
      final resolved = _resolveModelId(model);
      if (resolved == null) {
        return _errorResult(
          'Unknown model "$model". Available models: '
          '${ImageModels.allModels.join(", ")}.',
        );
      }
      notifier.updateModel(resolved);
      applied['model'] = resolved;
    }
    final sampler = (args['sampler'] as String?)?.trim();
    if (sampler != null && sampler.isNotEmpty) {
      notifier.updateSampler(sampler);
      applied['sampler'] = sampler;
    }
    final steps = (args['steps'] as num?)?.toInt();
    if (steps != null) {
      final value = steps.clamp(1, 50);
      notifier.updateSteps(value);
      applied['steps'] = value;
    }
    final scale = (args['scale'] as num?)?.toDouble();
    if (scale != null) {
      final value = scale.clamp(0.0, 10.0);
      notifier.updateScale(value);
      applied['scale'] = value;
    }
    final cfgRescale = (args['cfg_rescale'] as num?)?.toDouble();
    if (cfgRescale != null) {
      final value = cfgRescale.clamp(0.0, 1.0);
      notifier.updateCfgRescale(value);
      applied['cfg_rescale'] = value;
    }
    final noiseSchedule = (args['noise_schedule'] as String?)?.trim();
    if (noiseSchedule != null && noiseSchedule.isNotEmpty) {
      notifier.updateNoiseSchedule(noiseSchedule);
      applied['noise_schedule'] = noiseSchedule;
    }
    final ucPreset = (args['uc_preset'] as num?)?.toInt();
    if (ucPreset != null) {
      notifier.updateUcPreset(ucPreset);
      applied['uc_preset'] = ucPreset;
    }
    final seed = (args['seed'] as num?)?.toInt();
    if (seed != null) {
      notifier.updateSeed(seed);
      applied['seed'] = seed;
    }
    void applyBool(String key, void Function(bool) setter) {
      final raw = args[key];
      if (raw is bool) {
        setter(raw);
        applied[key] = raw;
      }
    }

    applyBool('quality_toggle', notifier.updateQualityToggle);
    applyBool('variety_plus', notifier.updateVarietyPlus);
    applyBool('decrisp', notifier.updateDecrisp);
    applyBool('transparent_background', notifier.updateTransparentBackground);
    applyBool('smea', notifier.updateSmea);
    applyBool('smea_dyn', notifier.updateSmeaDyn);

    if (applied.isEmpty) {
      return _errorResult(
        'No recognized settings found in arguments. Call '
        'get_generation_settings for valid field names.',
      );
    }
    // updateXxx 经 Future.microtask 写入 state，冲刷后再回读生效值。
    await Future<void>.delayed(Duration.zero);
    return _textResult(
      jsonEncode({'ok': true, 'applied': applied, 'current': _settingsJson()}),
    );
  }

  /// 把用户/模型给出的模型称呼解析为确切模型 ID：
  /// 精确 ID → 常见别名 → 显示名/ID 子串匹配。
  String? _resolveModelId(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final id in ImageModels.allModels) {
      if (id.toLowerCase() == normalized) {
        return id;
      }
    }
    const aliases = <String, String>{
      'v5': ImageModels.animeDiffusionV5Full,
      'v5 full': ImageModels.animeDiffusionV5Full,
      'v5 curated': ImageModels.animeDiffusionV5Curated,
      'v4.5': ImageModels.animeDiffusionV45Full,
      'v45': ImageModels.animeDiffusionV45Full,
      'v4.5 full': ImageModels.animeDiffusionV45Full,
      'v4.5 curated': ImageModels.animeDiffusionV45Curated,
      'v4': ImageModels.animeDiffusionV4Full,
      'v4 full': ImageModels.animeDiffusionV4Full,
      'v4 curated': ImageModels.animeDiffusionV4Curated,
      'v3': ImageModels.animeDiffusionV3,
      'latest': ImageModels.animeDiffusionV5Full,
      'newest': ImageModels.animeDiffusionV5Full,
    };
    final alias = aliases[normalized];
    if (alias != null) {
      return alias;
    }
    for (final entry in ImageModels.modelDisplayNames.entries) {
      if (entry.value.toLowerCase().contains(normalized)) {
        return entry.key;
      }
    }
    for (final id in ImageModels.allModels) {
      if (id.toLowerCase().contains(normalized)) {
        return id;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // get_recent_images
  // -------------------------------------------------------------------------

  /// 最近生成图（含队列产物）：details 携带文件路径，
  /// 会话内自动渲染为缩略图。
  Future<AgentToolResult> _recentImages(Map<String, dynamic> args) async {
    final limit = ((args['limit'] as num?)?.toInt() ?? 6).clamp(1, 20);
    final history = _ref.read(imageGenerationNotifierProvider).history;
    final images = [
      for (final image in history)
        if (image.filePath != null) image,
    ].take(limit).toList();
    final files = [for (final image in images) image.filePath!];
    final report = [
      for (final image in images)
        {
          'seed': image.metadata?.seed,
          'size': '${image.width}x${image.height}',
          'file': image.filePath,
        },
    ];
    if (images.isEmpty) {
      return _errorResult(
        'No saved images yet. generate_image results and queue outputs '
        'appear here after they are saved.',
      );
    }
    return AgentToolResult(
      content: [
        ToolResultTextContent(jsonEncode({'ok': true, 'images': report})),
      ],
      details: <String, dynamic>{'files': files, 'images': report},
    );
  }
}
