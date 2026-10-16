import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/services/anlas_calculator.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/services/metadata/unified_metadata_parser.dart';
import '../../providers/comfyui/comfyui_provider.dart';
import '../../providers/generation/derivative_image_adopter.dart';
import '../../providers/generation/image_upscale_coordinator.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/generation/novel_ai_upscale_task_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/subscription_provider.dart';
import 'agent_image_source_loader.dart';
import 'defined_agent_tool.dart';
import 'generation_image_read_contract.dart';
import 'generation_preparation_runtime.dart';
import 'generation_save_path_exporter.dart';
import 'generation_save_path_validator.dart';

const _backendWireNames = {
  'novelai': UpscaleBackend.novelai,
  'comfyui': UpscaleBackend.comfyui,
};

typedef ImageUpscaleQuote = ({String key, int cost});

/// 智能体与 MCP 的放大：后端与倍率只按本次参数覆盖，不写回生成页设置；
/// 结果按衍生图登记进生成历史，携带原图自身的元数据。
final class ImageUpscaleService {
  ImageUpscaleService(
    this._ref, {
    required AgentImageSourceLoader sourceLoader,
    required GenerationSavePathValidator savePathValidator,
    required GenerationSavePathExporter exporter,
    required GenerationImageReadContract readContract,
    required bool referencesGalleryOriginal,
  }) : _sourceLoader = sourceLoader,
       _savePathValidator = savePathValidator,
       _exporter = exporter,
       _readContract = readContract,
       _referencesGalleryOriginal = referencesGalleryOriginal;

  static const _logTag = 'AgentUpscale';
  static const _busyTimeout = Duration(seconds: 300);
  static const _busyPollInterval = Duration(milliseconds: 500);

  static List<String> get backendWireNames => _backendWireNames.keys.toList();

  final Ref _ref;
  final AgentImageSourceLoader _sourceLoader;
  final GenerationSavePathValidator _savePathValidator;
  final GenerationSavePathExporter _exporter;
  final GenerationImageReadContract _readContract;
  final bool _referencesGalleryOriginal;

  /// 只有会发出 NovelAI 请求的调用才有报价。
  Future<ImageUpscaleQuote?> quote(Map<String, dynamic> args) async {
    final settings = _resolveSettings(args).valueOrNull;
    if (settings == null || settings.backend == UpscaleBackend.comfyui) {
      return null;
    }
    final bytes = (await _sourceLoader.load(args)).bytes;
    if (bytes == null) return null;
    return (key: _quoteKey(args), cost: _novelAiCost(bytes));
  }

  /// [quote] 是审批时报出的价格，付费请求只按它执行。
  Future<AgentToolResult> upscale(
    String toolCallId,
    Map<String, dynamic> args,
    ImageUpscaleQuote? quote, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final settingsResult = _resolveSettings(args);
    if (settingsResult.errorOrNull case final rejection?) return rejection;
    final settings = settingsResult.valueOrNull!;
    final source = await _sourceLoader.load(args);
    if (source.error case final error?) return error;
    final sourceBytes = source.bytes!;
    final savePathResult = await _resolveSavePath(args['save_path']);
    if (savePathResult.errorOrNull case final rejection?) return rejection;
    final savePath = savePathResult.valueOrNull;

    if (settings.backend == UpscaleBackend.novelai) {
      final rejection = _rejectUnapprovedCost(sourceBytes, args, quote);
      if (rejection != null) return rejection;
    } else if (!_ref.read(comfyUISettingsProvider).enabled) {
      return agentToolError(
        'comfyui_disabled',
        'ComfyUI is not enabled in Settings; enable it or use backend novelai.',
      );
    }

    // ComfyUI 两个 provider 是 autoDispose，生成页未挂载时得订阅住拉取与执行全程。
    final keepAlive = [
      _ref.listen(comfyUITaskProvider, (_, _) {}),
      _ref.listen(comfyUISeedvr2ModelsProvider, (_, _) {}),
    ];
    try {
      if (settings.backend == UpscaleBackend.comfyui &&
          settings.comfyModule != ComfyUpscaleModule.rtx) {
        onUpdate?.call(
          agentToolTextResult('Loading ComfyUI upscale models...'),
        );
        await _ref.read(comfyUISeedvr2ModelsProvider.notifier).fetch();
      }
      if (!await _waitUntilIdle(settings.backend, signal, onUpdate)) {
        return agentToolError(
          'upscale_busy',
          'Another upscale is still running after '
              '${_busyTimeout.inSeconds}s; try again later.',
        );
      }
      throwIfAborted(signal);
      onUpdate?.call(
        agentToolTextResult('Upscaling with ${settings.backend.name}...'),
      );
      return await _run(settings, sourceBytes, savePath, onUpdate);
    } finally {
      for (final subscription in keepAlive) {
        subscription.close();
      }
    }
  }

  Future<AgentToolResult> _run(
    UpscaleWorkflowSettings settings,
    Uint8List source,
    String? savePath,
    AgentToolUpdateCallback? onUpdate,
  ) async {
    GeneratedImage? adopted;
    final result = await _ref
        .read(imageUpscaleCoordinatorProvider)
        .execute(
          ImageUpscaleRequest(source: source, settings: settings),
          adopt: (output) async {
            adopted = await _ref
                .read(derivativeImageAdopterProvider)
                .adopt(
                  result: _carrySourceMetadata(source, output.bytes),
                  source: source,
                );
          },
        );
    switch (result) {
      case ImageUpscaleRejected(:final reason, :final detail):
        return _rejectionError(reason, detail);
      case ImageUpscaleSuccess(:final kind):
        final image = adopted;
        if (image == null) {
          return agentToolError(
            'upscale_result_unavailable',
            'The upscaled image was removed before it could be returned.',
          );
        }
        onUpdate?.call(agentToolTextResult('Saving image...'));
        final export = await _export(image, savePath);
        final sourceSize = NaiResolutionAdapter.readImageSize(source);
        return _readContract.buildResult(
          [image],
          exports: {if (export != null) image.id: export},
          extra: {
            'backend': settings.backend.name,
            'upscaler': _kindWireName(kind),
            if (sourceSize != null)
              'source_size': '${sourceSize.$1}x${sourceSize.$2}',
          },
        );
    }
  }

  HarnessResult<UpscaleWorkflowSettings, AgentToolResult> _resolveSettings(
    Map<String, dynamic> args,
  ) {
    final page = _ref.read(imageWorkflowControllerProvider).upscale;
    final rawBackend = args['backend'];
    final backend = rawBackend == null
        ? page.backend
        : _backendWireNames[rawBackend];
    if (backend == null) {
      return err(
        agentToolError(
          'invalid_backend',
          'backend must be one of ${backendWireNames.join(', ')}.',
        ),
      );
    }
    final rawScale = args['scale'];
    if (rawScale == null) return ok(page.copyWith(backend: backend));
    if (backend == UpscaleBackend.novelai) {
      return err(
        agentToolError(
          'scale_unsupported',
          'NovelAI upscale has a fixed output scale; omit scale.',
        ),
      );
    }
    if (rawScale is! num ||
        rawScale < UpscaleWorkflowSettings.minScale ||
        rawScale > UpscaleWorkflowSettings.maxScale) {
      return err(
        agentToolError(
          'invalid_scale',
          'scale must be a number from ${UpscaleWorkflowSettings.minScale} '
              'to ${UpscaleWorkflowSettings.maxScale}.',
        ),
      );
    }
    return ok(page.copyWith(backend: backend, comfyScale: rawScale.toDouble()));
  }

  int _novelAiCost(Uint8List source) {
    final size = NaiResolutionAdapter.readImageSize(source);
    if (size == null) return AnlasCalculator.invalidCost;
    final subscription = _ref.read(subscriptionNotifierProvider).subscription;
    // 计费按实际上传的原图面积，不是生成页导入后的请求尺寸。
    return AnlasCalculator.calculateNovelAiUpscaleCost(
      inputWidth: size.$1,
      inputHeight: size.$2,
      scale: 2,
      subscriptionTier: subscription?.isOpus == true
          ? AnlasCalculator.opusTier
          : 0,
    );
  }

  /// 只按审批时报过的价格发付费请求，原图在审批期间被换掉也不会多扣。
  AgentToolResult? _rejectUnapprovedCost(
    Uint8List source,
    Map<String, dynamic> args,
    ImageUpscaleQuote? quote,
  ) {
    final cost = _novelAiCost(source);
    if (cost == AnlasCalculator.invalidCost) {
      return agentToolError(
        'upscale_source_too_large',
        'NovelAI upscale accepts sources up to '
            '${AnlasCalculator.novelAiUpscaleMaxInputPixels} pixels; use '
            'backend comfyui or a smaller source.',
      );
    }
    if (cost == 0) return null;
    if (quote == null || quote.key != _quoteKey(args) || cost > quote.cost) {
      return agentToolError(
        'upscale_cost_changed',
        'The Anlas cost of this upscale differs from the approved estimate; '
            'call upscale_image again so the new cost can be approved.',
      );
    }
    return null;
  }

  Future<HarnessResult<String?, AgentToolResult>> _resolveSavePath(
    Object? requested,
  ) async {
    // 衍生图不带生成种子，{seed} 必然展开失败，付费前就拒绝。
    if (requested is String && requested.contains('{seed}')) {
      return err(
        agentToolError(
          'invalid_save_path',
          'Upscaled images have no seed; use {id} instead of {seed}.',
        ),
      );
    }
    return _savePathValidator.validate(requested, total: 1);
  }

  Future<GeneratedImageExportOutcome?> _export(
    GeneratedImage image,
    String? savePath,
  ) {
    final source = savePath != null
        ? GenerationSavePathSource.caller
        : _referencesGalleryOriginal
        ? GenerationSavePathSource.galleryOriginal
        : null;
    if (source == null) return Future.value();
    return _exporter.export(
      source: source,
      id: image.id,
      index: 1,
      total: 1,
      seed: null,
      bytes: image.bytes,
      label: '${image.id}.png',
      template: savePath,
      originalPath: image.filePath,
    );
  }

  Future<bool> _waitUntilIdle(
    UpscaleBackend backend,
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ) async {
    final deadline = DateTime.now().add(_busyTimeout);
    var announced = false;
    while (_isBusy(backend)) {
      throwIfAborted(signal);
      if (!DateTime.now().isBefore(deadline)) return false;
      if (!announced) {
        announced = true;
        onUpdate?.call(
          agentToolTextResult('Waiting for the running upscale to finish...'),
        );
      }
      await Future<void>.delayed(_busyPollInterval);
    }
    return true;
  }

  bool _isBusy(UpscaleBackend backend) => switch (backend) {
    UpscaleBackend.novelai => _ref.read(novelAiUpscaleTaskProvider).isRunning,
    UpscaleBackend.comfyui => _ref.read(comfyUITaskProvider).isRunning,
  };

  /// 与 DLSS 等衍生图一致：只搬原图的文本与 EXIF 块，结果已付费，搬不了也保留。
  static Uint8List _carrySourceMetadata(Uint8List source, Uint8List output) {
    try {
      return UnifiedMetadataParser.copySupportedMetadata(
        source: source,
        targetPng: output,
      );
    } on FormatException catch (error) {
      AppLogger.w(
        'Upscale result kept without source metadata: $error',
        _logTag,
      );
      return output;
    }
  }

  static String _quoteKey(Map<String, dynamic> args) => jsonEncode({
    for (final key in const ['resource_ref', 'image_path', 'backend'])
      key: args[key],
  });

  static String _kindWireName(ImageUpscaleKind kind) => switch (kind) {
    ImageUpscaleKind.novelAi => 'novelai',
    ImageUpscaleKind.regular => 'comfyui_model',
    ImageUpscaleKind.seedVr2Native => 'seedvr2_native',
    ImageUpscaleKind.seedVr2Legacy => 'seedvr2_legacy',
    ImageUpscaleKind.seedVr2Tiled => 'seedvr2_tiled',
    ImageUpscaleKind.rtx => 'rtx',
  };

  static AgentToolResult _rejectionError(
    ImageUpscaleFailure reason,
    String? detail,
  ) {
    String withDetail(String message) =>
        detail == null ? message : '$message ($detail)';
    return switch (reason) {
      ImageUpscaleFailure.engineUnavailable ||
      ImageUpscaleFailure.nativeVaeUnavailable => agentToolError(
        'comfyui_engine_unavailable',
        'The SeedVR2 engine selected on the generation page is unavailable '
            'in ComfyUI.',
      ),
      ImageUpscaleFailure.regularModelUnavailable ||
      ImageUpscaleFailure.seedVr2ModelUnavailable => agentToolError(
        'comfyui_model_unavailable',
        'ComfyUI has no model for the upscale module selected on the '
            'generation page.',
      ),
      ImageUpscaleFailure.sourceMissing ||
      ImageUpscaleFailure.sourceDecodeFailed => agentToolError(
        'invalid_image',
        'The provided data could not be decoded as an image.',
      ),
      ImageUpscaleFailure.busy => agentToolError(
        'upscale_busy',
        'Another upscale started first; try again later.',
      ),
      ImageUpscaleFailure.authenticationRequired => agentToolError(
        'authentication_required',
        'Sign in to NovelAI in the launcher before upscaling with novelai.',
      ),
      ImageUpscaleFailure.requestFailed ||
      ImageUpscaleFailure.noResult => agentToolError(
        'upscale_failed',
        withDetail('The upscale produced no image.'),
      ),
    };
  }
}
