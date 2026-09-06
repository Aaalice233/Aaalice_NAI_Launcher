import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/services/anlas_calculator.dart';
import '../../../core/services/character_conversion_service.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/services/alias_resolver_service.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/vibe_library_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_anlas_estimator.dart';
import 'generation_character_orchestration.dart';
import 'generation_preparation_runtime.dart';
import 'generation_workspace_path_resolver.dart';

class GenerationPreparationService {
  GenerationPreparationService(
    this._ref, {
    required GenerationPreparationRuntime runtime,
    required AgentResourceResolver resourceResolver,
    required GenerationWorkspacePathResolver pathResolver,
    required int maxGenerateCount,
    required GenerationAnlasEstimator anlasEstimator,
    required Future<AgentToolResult> Function(
      String,
      Map<String, dynamic>,
      AbortSignal?,
      AgentToolUpdateCallback?,
    )
    executeGeneration,
    required Future<AgentToolResult> Function(
      Map<String, dynamic>, {
      required GenerationPreparation prepared,
    })
    executeQueue,
  }) : _runtime = runtime,
       _resourceResolver = resourceResolver,
       _pathResolver = pathResolver,
       _maxGenerateCount = maxGenerateCount,
       _anlasEstimator = anlasEstimator,
       _executeGeneration = executeGeneration,
       _executeQueue = executeQueue;
  final Ref _ref;
  final GenerationPreparationRuntime _runtime;
  final AgentResourceResolver _resourceResolver;
  final GenerationWorkspacePathResolver _pathResolver;
  final int _maxGenerateCount;
  final GenerationAnlasEstimator _anlasEstimator;
  final Future<AgentToolResult> Function(
    String,
    Map<String, dynamic>,
    AbortSignal?,
    AgentToolUpdateCallback?,
  )
  _executeGeneration;
  final Future<AgentToolResult> Function(
    Map<String, dynamic>, {
    required GenerationPreparation prepared,
  })
  _executeQueue;

  Future<AgentToolResult> generateLegacy(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    final id = args['preparation_id'] as String?;
    if (id == null) {
      return prepareForKind(GenerationPreparationKind.generate, args);
    }
    if (_runtime.get(id)?.kind != GenerationPreparationKind.generate) {
      return Future.value(
        agentToolError(
          'preparation_kind_mismatch',
          'This preparation was not created by generate_image.',
        ),
      );
    }
    return submitPreparation(
      toolCallId,
      {'preparation_id': id, 'confirmed': args['confirmed']},
      signal,
      onUpdate,
    );
  }

  Future<AgentToolResult> prepare(Map<String, dynamic> args) async {
    final operation = args['operation'] as String?;
    final kind = switch (operation) {
      'generate' => GenerationPreparationKind.generate,
      'queue' => GenerationPreparationKind.queue,
      _ => null,
    };
    if (kind == null) {
      return agentToolError(
        'invalid_operation',
        'Parameter "operation" must be "generate" or "queue".',
      );
    }
    return prepareForKind(kind, args);
  }

  Future<AgentToolResult> prepareForKind(
    GenerationPreparationKind kind,
    Map<String, dynamic> args, {
    ImageParams? baseOverride,
    ImageParams? characterSnapshotOverride,
  }) async {
    final prompt = (args['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) {
      return agentToolError(
        'invalid_prompt',
        'Parameter "prompt" is required.',
      );
    }
    final maximum = kind == GenerationPreparationKind.generate
        ? _maxGenerateCount
        : kMaxQueueCapacity;
    final countValue = args['count'];
    if (countValue != null && countValue is! int) {
      return agentToolError(
        'invalid_count',
        'Parameter "count" must be an integer.',
      );
    }
    final count = countValue as int? ?? 1;
    if (count < 1 || count > maximum) {
      return agentToolError(
        'invalid_count',
        'Parameter "count" must be between 1 and $maximum.',
      );
    }

    final ImageParams base =
        baseOverride ?? _ref.read(generationParamsNotifierProvider);
    final width = (args['width'] as num?)?.toInt() ?? base.width;
    final height = (args['height'] as num?)?.toInt() ?? base.height;
    final resolutionIssue = NaiResolutionAdapter.validateGenerationResolution(
      width,
      height,
    );
    if (resolutionIssue != null) {
      return agentToolError(
        'invalid_resolution',
        'Invalid generation resolution ${width}x$height. Width and height '
            'must be multiples of 64 and total pixels must not exceed '
            '${NaiResolutionAdapter.officialMaxPixels}.',
      );
    }

    final promptParts = <String>[prompt];
    final negativePromptParts = <String>[
      (args['negative_prompt'] as String?)?.trim() ?? base.negativePrompt,
    ];
    final promptRefError = await _appendTextReferences(
      args['prompt_refs'],
      promptParts,
      promptType: FixedTagPromptType.positive,
    );
    if (promptRefError != null) return promptRefError;
    final negativeRefError = await _appendTextReferences(
      args['negative_prompt_refs'],
      negativePromptParts,
      promptType: FixedTagPromptType.negative,
    );
    if (negativeRefError != null) return negativeRefError;

    Uint8List? sourceBytes;
    Uint8List? maskBytes;
    var action = kind == GenerationPreparationKind.generate
        ? ImageGenerationAction.generate
        : base.action;
    final sourcePath = (args['source_image'] as String?)?.trim() ?? '';
    if (args['source_ref'] != null) {
      try {
        final source = await _resourceResolver.resolve(
          _resourceResolver.decode(args['source_ref']),
        );
        sourceBytes = source?.bytes;
        if (sourceBytes == null) {
          return agentToolError(
            'resource_unavailable',
            'Source image resource is unavailable.',
          );
        }
        action = ImageGenerationAction.img2img;
        if (args['mask_ref'] != null) {
          final mask = await _resourceResolver.resolve(
            _resourceResolver.decode(args['mask_ref']),
          );
          maskBytes = mask?.bytes;
          if (maskBytes == null) {
            return agentToolError(
              'resource_unavailable',
              'Mask image resource is unavailable.',
            );
          }
          action = ImageGenerationAction.infill;
        }
      } on FormatException catch (error) {
        return agentToolError('invalid_resource_ref', '$error');
      }
    } else if (sourcePath.isNotEmpty) {
      if (kind == GenerationPreparationKind.queue) {
        return agentToolError(
          'unsupported_queue_source',
          'queue preparations do not support source_image.',
        );
      }
      try {
        final resolved = await _pathResolver.resolveLocalImagePath(sourcePath);
        final file = File(resolved);
        if (!file.existsSync()) {
          return agentToolError('source_not_found', 'Source image not found.');
        }
        sourceBytes = await file.readAsBytes();
        action = ImageGenerationAction.img2img;
        final maskPath = (args['mask_image'] as String?)?.trim() ?? '';
        if (maskPath.isNotEmpty) {
          final resolvedMask = await _pathResolver.resolveLocalImagePath(
            maskPath,
          );
          final maskFile = File(resolvedMask);
          if (!maskFile.existsSync()) {
            return agentToolError('mask_not_found', 'Mask image not found.');
          }
          maskBytes = await maskFile.readAsBytes();
          action = ImageGenerationAction.infill;
        }
      } on Object {
        return agentToolError(
          'image_path_not_permitted',
          'Image path is not permitted.',
        );
      }
    }

    double ratio(String key, double fallback) {
      final value = (args[key] as num?)?.toDouble();
      return value == null ? fallback : value.clamp(0.0, 0.99);
    }

    final vibeReferences = [...base.vibeReferencesV4];
    for (final value in args['vibe_refs'] as List? ?? const []) {
      try {
        final resolved = await _resourceResolver.resolve(
          _resourceResolver.decode(value),
        );
        final id = resolved?.vibeEntryId;
        final entry = id == null
            ? null
            : (await _ref
                      .read(vibeLibraryNotifierProvider.notifier)
                      .resolveEntriesByIds([id]))
                  .firstOrNull;
        if (entry == null) {
          return agentToolError(
            'resource_unavailable',
            'A Vibe library resource is unavailable.',
          );
        }
        vibeReferences.add(entry.toVibeReference());
      } on FormatException catch (error) {
        return agentToolError('invalid_resource_ref', '$error');
      }
    }
    final preciseReferences = [...base.preciseReferences];
    for (final value in args['precise_reference_refs'] as List? ?? const []) {
      try {
        final resolved = await _resourceResolver.resolve(
          _resourceResolver.decode(value),
        );
        final id = resolved?.preciseReferenceEntryId;
        final entry = id == null
            ? null
            : _ref
                  .read(preciseRefLibraryNotifierProvider)
                  .entries
                  .where((candidate) => candidate.id == id)
                  .firstOrNull;
        if (resolved?.bytes == null || entry == null) {
          return agentToolError(
            'resource_unavailable',
            'A precise-reference resource is unavailable.',
          );
        }
        preciseReferences.add(
          PreciseReference(
            image: resolved!.bytes!,
            type: entry.type,
            strength: entry.strength,
            fidelity: entry.fidelity,
          ),
        );
      } on FormatException catch (error) {
        return agentToolError('invalid_resource_ref', '$error');
      }
    }
    final hasExplicitCharacters = args.containsKey('characters');
    if (!hasExplicitCharacters && args.containsKey('character_layout_mode')) {
      return agentToolError(
        'character_layout_without_characters',
        'character_layout_mode requires an explicit characters snapshot.',
      );
    }

    late final List<CharacterPrompt> characters;
    late final bool useCoords;
    if (hasExplicitCharacters) {
      try {
        final snapshot = GenerationCharacterOrchestrator.normalizeExplicit(
          rawCharacters: args['characters'],
          rawLayoutMode: args['character_layout_mode'],
          model: base.model,
        );
        characters = snapshot.characters;
        useCoords = snapshot.useCoords;
      } on GenerationCharacterValidationException catch (error) {
        return agentToolError(error.code, error.message);
      }
    } else {
      final override = characterSnapshotOverride;
      if (override != null) {
        characters = override.characters;
        useCoords = override.useCoords;
      } else {
        final config = _ref.read(characterPromptNotifierProvider);
        final conversion = CharacterConversionService(
          aliasResolver: _ref
              .read(aliasResolverServiceProvider.notifier)
              .resolveAliases,
        ).convert(config);
        characters = conversion.characters;
        useCoords = conversion.useCoords;
      }
      final limit = ModelCapabilityRegistry.of(base.model).maxCharacters;
      if (characters.isNotEmpty && limit == 0) {
        return agentToolError(
          'model_character_unsupported',
          'Model ${base.model} does not support character prompts.',
        );
      }
      if (characters.length > limit) {
        return agentToolError(
          'model_character_limit',
          'Model ${base.model} supports at most $limit characters; '
              '${characters.length} enabled characters are configured.',
        );
      }
    }

    final params = base.copyWith(
      prompt: promptParts.where((value) => value.isNotEmpty).join(', '),
      negativePrompt: negativePromptParts
          .where((value) => value.isNotEmpty)
          .join(', '),
      width: width,
      height: height,
      seed: (args['seed'] as num?)?.toInt() ?? -1,
      nSamples: kind == GenerationPreparationKind.generate ? count : 1,
      action: action,
      sourceImage: sourceBytes,
      maskImage: maskBytes,
      strength: ratio('strength', base.strength),
      noise: ratio('noise', base.noise),
      inpaintStrength: ratio('inpaint_strength', base.inpaintStrength),
      vibeReferencesV4: vibeReferences,
      preciseReferences: preciseReferences,
      characters: characters,
      useCoords: useCoords,
    );
    final batchSize = _anlasEstimator.currentBatchSize;
    final estimate = _anlasEstimator.estimate(
      params,
      requestCount: kind == GenerationPreparationKind.queue ? count : 1,
      batchSize: batchSize,
    );
    if (estimate == AnlasCalculator.invalidCost) {
      return agentToolError(
        'invalid_cost',
        'Unable to estimate Anlas for these parameters.',
      );
    }
    final canonicalArgs = Map<String, dynamic>.from(args)
      ..remove('operation')
      ..remove('preparation_id')
      ..remove('confirmed');
    final preparation = _runtime.add(
      GenerationPreparation(
        kind: kind,
        baseParams: base,
        params: params,
        batchSize: batchSize,
        count: count,
        autoStart: args['auto_start'] as bool? ?? true,
        estimatedAnlas: estimate,
        arguments: canonicalArgs,
        sourceImage: sourceBytes,
        maskImage: maskBytes,
      ),
    );
    return agentToolJsonResult(preparation.toJson());
  }

  Future<AgentToolResult?> _appendTextReferences(
    dynamic rawReferences,
    List<String> target, {
    required FixedTagPromptType promptType,
  }) async {
    final appendedResources =
        <
          ({
            AgentChatResourceKind kind,
            String source,
            String id,
            String? media,
          })
        >{};
    for (final value in rawReferences as List? ?? const []) {
      try {
        final resolved = await _resourceResolver.resolve(
          _resourceResolver.decode(value),
        );
        final text = resolved?.text?.trim();
        if (resolved == null || text == null || text.isEmpty) {
          return agentToolError(
            'resource_unavailable',
            'A prompt resource is unavailable or has no text.',
          );
        }
        final reference = resolved.reference;
        final identity = (
          kind: reference.kind,
          source: reference.source,
          id: reference.resourceId,
          media: reference.mediaId,
        );
        if (!appendedResources.add(identity)) continue;

        if (reference.kind == AgentChatResourceKind.fixedTag &&
            _isEnabledFixedTag(reference.resourceId, promptType)) {
          continue;
        }
        target.add(text);
      } on FormatException catch (error) {
        return agentToolError('invalid_resource_ref', '$error');
      }
    }
    return null;
  }

  bool _isEnabledFixedTag(String id, FixedTagPromptType promptType) => _ref
      .read(fixedTagsNotifierProvider)
      .entries
      .any(
        (entry) =>
            entry.id == id && entry.enabled && entry.promptType == promptType,
      );

  Future<AgentToolResult> inspectPreparation(Map<String, dynamic> args) async {
    final preparation = _runtime.get(args['preparation_id'] as String? ?? '');
    return preparation == null
        ? agentToolError(
            'preparation_not_found',
            'Generation preparation not found.',
          )
        : agentToolJsonResult(preparation.toJson());
  }

  Future<AgentToolResult> updatePreparation(Map<String, dynamic> args) async {
    final id = args['preparation_id'] as String? ?? '';
    final current = _runtime.get(id);
    if (current == null ||
        current.status != GenerationPreparationStatus.prepared) {
      return agentToolError(
        'preparation_not_active',
        'Generation preparation is not active.',
      );
    }
    final merged = Map<String, dynamic>.from(current.arguments);
    for (final entry in args.entries) {
      if (entry.key != 'preparation_id') merged[entry.key] = entry.value;
    }
    final result = await prepareForKind(
      current.kind,
      merged,
      baseOverride: current.baseParams,
      characterSnapshotOverride: current.params,
    );
    if (!result.isError) _runtime.cancel(id);
    return result;
  }

  Future<AgentToolResult> cancelPreparation(Map<String, dynamic> args) async {
    final id = args['preparation_id'] as String? ?? '';
    if (!_runtime.cancel(id)) {
      return agentToolError(
        'preparation_not_active',
        'Generation preparation is not active.',
      );
    }
    return agentToolJsonResult({
      'ok': true,
      'preparation_id': id,
      'status': 'cancelled',
    });
  }

  Future<AgentToolResult> submitPreparation(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) async {
    final preparation = _runtime.get(args['preparation_id'] as String? ?? '');
    if (preparation == null ||
        preparation.status != GenerationPreparationStatus.prepared) {
      return agentToolError(
        'preparation_not_active',
        'Generation preparation is not active.',
      );
    }
    if (preparation.estimatedAnlas != 0 && args['confirmed'] != true) {
      return agentToolError(
        'confirmation_required',
        'A paid preparation requires confirmed=true and tool permission approval.',
      );
    }
    preparation.status = GenerationPreparationStatus.submitted;
    if (preparation.kind == GenerationPreparationKind.queue) {
      return _executeQueue(preparation.arguments, prepared: preparation);
    }
    final executionArgs = Map<String, dynamic>.from(preparation.arguments)
      ..remove('source_image')
      ..remove('mask_image')
      ..['_prepared_generation'] = preparation;
    return _executeGeneration(toolCallId, executionArgs, signal, onUpdate);
  }

  Future<AgentToolResult> queueLegacy(
    String toolCallId,
    Map<String, dynamic> args, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    final id = args['preparation_id'] as String?;
    if (id == null) {
      return prepareForKind(GenerationPreparationKind.queue, args);
    }
    if (_runtime.get(id)?.kind != GenerationPreparationKind.queue) {
      return Future.value(
        agentToolError(
          'preparation_kind_mismatch',
          'This preparation was not created by queue_image_task.',
        ),
      );
    }
    return submitPreparation(
      toolCallId,
      {'preparation_id': id, 'confirmed': args['confirmed']},
      signal,
      onUpdate,
    );
  }

  // -------------------------------------------------------------------------
  // generate_image
  // -------------------------------------------------------------------------
}
