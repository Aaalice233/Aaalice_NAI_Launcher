import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../../models/online_gallery/ai_tag_generation_info.dart';

/// Parses aitag.win per-image metadata into [AiTagGenerationInfo].
///
/// Handles two dominant shapes observed on the site:
/// * SD WebUI `parameters` string embedded as `{"parameters":"...Steps: ..."}`
/// * ComfyUI workflow JSON keyed by node ids (`"1":{"class_type":"UNETLoader"...}`).
class AiTagGenerationParser {
  static AiTagGenerationInfo parse({
    required String? rawAiJson,
    required String? promptText,
    required String imageType,
  }) {
    final raw = rawAiJson?.trim() ?? '';
    final fallbackPrompt = promptText?.trim() ?? '';
    final pretty = _prettyJson(raw.isNotEmpty ? raw : fallbackPrompt);
    final effectiveRaw = raw.isNotEmpty ? raw : fallbackPrompt;

    // Try structured JSON first.
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          // NAI path: contains Software/Source + Comment
          final naiInfo = _parseNaiJson(
            decoded,
            prettyJson: pretty,
            rawJson: effectiveRaw,
            imageType: imageType,
          );
          if (naiInfo != null) return naiInfo;
          // SD path: {"parameters": "prompt\nSteps: ..."}
          if (decoded.containsKey('parameters') &&
              decoded['parameters'] is String) {
            final info = _parseSdParameters(
              decoded['parameters'] as String,
              prettyJson: pretty,
              rawJson: effectiveRaw,
            );
            if (info != null) return info;
          }
          // Comfy workflow path: keys are node ids, values contain class_type
          if (_looksLikeComfyWorkflow(decoded)) {
            final info = _parseComfyWorkflow(
              decoded,
              prettyJson: pretty,
              rawJson: effectiveRaw,
            );
            if (info != null) return info;
          }
          // Generic JSON with direct keys (fallback)
          final generic = _parseGenericJson(
            decoded,
            prettyJson: pretty,
            rawJson: effectiveRaw,
            imageType: imageType,
          );
          if (generic != null && generic.hasAnyParam) return generic;
        }
      } catch (_) {
        // Not JSON — fall through to plain parameters.
      }

      // Raw may itself be a plain WebUI parameters string (not wrapped).
      if (_looksLikeSdParameters(raw)) {
        final info = _parseSdParameters(
          raw,
          prettyJson: pretty,
          rawJson: effectiveRaw,
        );
        if (info != null) return info;
      }
    }

    if (fallbackPrompt.isNotEmpty && _looksLikeSdParameters(fallbackPrompt)) {
      final prettyFallback = _prettyJson(fallbackPrompt);
      final info = _parseSdParameters(
        fallbackPrompt,
        prettyJson: prettyFallback,
        rawJson: fallbackPrompt,
      );
      if (info != null) return info;
    }

    // Fallback: at least expose pretty JSON + software hint from imageType.
    return AiTagGenerationInfo(
      software: _softwareFromImageType(imageType),
      prettyJson: pretty,
      rawJson: effectiveRaw,
      prompt: fallbackPrompt.isNotEmpty ? fallbackPrompt : null,
    );
  }

  static bool _looksLikeComfyWorkflow(Map<String, dynamic> map) {
    return map.values.any(
      (v) => v is Map && (v)['class_type'] is String && (v)['inputs'] is Map,
    );
  }

  static bool _looksLikeSdParameters(String text) {
    return text.contains('Steps:') ||
        text.contains('Sampler:') ||
        text.contains('CFG scale:') ||
        text.contains('CFG Scale:') ||
        text.contains('Seed:');
  }

  static AiTagGenerationInfo? _parseSdParameters(
    String text, {
    required String prettyJson,
    required String rawJson,
  }) {
    final promptParts = _splitSdPrompt(text);
    final map = _parseSdParameterMap(promptParts.parameters);
    String? str(String key) => map[key];
    int? intVal(String key) =>
        map[key] == null ? null : int.tryParse(map[key]!);
    double? doubleVal(String key) =>
        map[key] == null ? null : double.tryParse(map[key]!);
    final size = _parseSdSize(str('Size') ?? str('size'));
    final model = str('Model');
    final modelHash = str('Model hash') ?? str('Model Hash');
    final sampler = str('Sampler');
    final scheduleType = str('Schedule type') ?? str('Schedule Type');
    final cfgScale = doubleVal('CFG scale') ?? doubleVal('CFG Scale');
    final shift = doubleVal('Shift');
    final denoise = doubleVal('Denoising strength');
    final seed = intVal('Seed');
    final steps = intVal('Steps');
    final vae = str('Module 1') ?? str('VAE');
    final clip = str('Module 2') ?? str('Clip');
    final version = str('Version');
    final rng = str('RNG');
    final extra = _sdExtraParameters(map);
    if (version != null) extra['Version'] = version;
    if (rng != null) extra['RNG'] = rng;

    if (steps == null &&
        sampler == null &&
        model == null &&
        seed == null &&
        cfgScale == null &&
        promptParts.prompt == null) {
      return null;
    }

    return AiTagGenerationInfo(
      software: 'Stable Diffusion WebUI',
      model: model,
      modelHash: modelHash,
      vae: vae,
      clip: clip,
      sampler: sampler,
      scheduler: null,
      scheduleType: scheduleType,
      steps: steps,
      cfgScale: cfgScale,
      shift: shift,
      denoise: denoise,
      seed: seed,
      width: size?.$1,
      height: size?.$2,
      extra: extra,
      prompt: promptParts.prompt,
      negativePrompt: promptParts.negativePrompt,
      prettyJson: prettyJson,
      rawJson: rawJson,
    );
  }

  static ({String? prompt, String? negativePrompt, String parameters})
  _splitSdPrompt(String text) {
    final stepsIndex = text.indexOf('Steps:');
    if (stepsIndex == -1) {
      return (prompt: null, negativePrompt: null, parameters: text);
    }

    final promptBlock = text.substring(0, stepsIndex).trim();
    final parameters = text.substring(stepsIndex).trim();
    final negativeIndex = promptBlock.indexOf('Negative prompt:');
    if (negativeIndex == -1) {
      return (
        prompt: promptBlock.isEmpty ? null : promptBlock,
        negativePrompt: null,
        parameters: parameters,
      );
    }

    final prompt = promptBlock.substring(0, negativeIndex).trim();
    final negativePrompt = promptBlock
        .substring(negativeIndex + 'Negative prompt:'.length)
        .trim();
    return (
      prompt: prompt.isEmpty ? null : prompt,
      negativePrompt: negativePrompt.isEmpty ? null : negativePrompt,
      parameters: parameters,
    );
  }

  static Map<String, String> _parseSdParameterMap(String parameters) {
    final result = <String, String>{};
    for (final segment in parameters.replaceAll('\n', ', ').split(',')) {
      final value = segment.trim();
      final separator = value.indexOf(':');
      if (separator <= 0) continue;
      final key = value.substring(0, separator).trim();
      final content = value.substring(separator + 1).trim();
      if (key.isNotEmpty && content.isNotEmpty) result[key] = content;
    }
    return result;
  }

  static (int, int)? _parseSdSize(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d+)\s*[x×]\s*(\d+)').firstMatch(value);
    if (match == null) return null;
    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    return width == null || height == null ? null : (width, height);
  }

  static Map<String, String> _sdExtraParameters(Map<String, String> values) {
    const knownKeys = {
      'Model',
      'Model hash',
      'Model Hash',
      'Sampler',
      'Schedule type',
      'Schedule Type',
      'CFG scale',
      'CFG Scale',
      'Shift',
      'Denoising strength',
      'Seed',
      'Steps',
      'Size',
      'size',
      'Module 1',
      'Module 2',
      'VAE',
      'Clip',
      'Version',
      'RNG',
    };
    return {
      for (final entry in values.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };
  }

  static AiTagGenerationInfo? _parseComfyWorkflow(
    Map<String, dynamic> workflow, {
    required String prettyJson,
    required String rawJson,
  }) {
    final fields = _ComfyWorkflowFields();
    for (final entry in workflow.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final node = Map<String, dynamic>.from(value);
      _readComfyNode(entry.key, node, fields);
    }

    final prompts = _resolveComfyPrompts(fields);
    if (fields.unetName == null &&
        fields.sampler == null &&
        fields.steps == null &&
        prompts.positive == null) {
      return null;
    }

    return AiTagGenerationInfo(
      software: 'ComfyUI',
      model: fields.unetName,
      vae: fields.vaeName,
      clip: fields.clipName,
      sampler: fields.sampler,
      scheduler: fields.scheduler,
      steps: fields.steps,
      cfgScale: fields.cfg,
      seed: fields.seed,
      denoise: fields.denoise,
      width: fields.width,
      height: fields.height,
      loras: fields.loras,
      loraStrengths: fields.loraStrengths,
      extra: {if (fields.unetName != null) 'UNET': fields.unetName!},
      prompt: prompts.positive,
      negativePrompt: prompts.negative,
      prettyJson: prettyJson,
      rawJson: rawJson,
    );
  }

  static void _readComfyNode(
    String nodeId,
    Map<String, dynamic> node,
    _ComfyWorkflowFields fields,
  ) {
    final classType = node['class_type']?.toString();
    final rawInputs = node['inputs'];
    if (classType == null || rawInputs is! Map) return;
    final inputs = Map<String, dynamic>.from(rawInputs);

    switch (classType) {
      case 'UNETLoader':
        fields.unetName ??= inputs['unet_name']?.toString();
        break;
      case 'CLIPLoader':
        fields.clipName ??= inputs['clip_name']?.toString();
        break;
      case 'VAELoader':
        fields.vaeName ??= inputs['vae_name']?.toString();
        break;
      case 'EmptyLatentImage':
        fields.width ??= _toInt(inputs['width']);
        fields.height ??= _toInt(inputs['height']);
        break;
      case 'KSampler' || 'KSamplerAdvanced':
        fields.sampler ??= inputs['sampler_name']?.toString();
        fields.scheduler ??= inputs['scheduler']?.toString();
        fields.steps ??= _toInt(inputs['steps']);
        fields.cfg ??= _toDouble(inputs['cfg']);
        fields.seed ??= _toInt(inputs['seed']) ?? _toInt(inputs['noise_seed']);
        fields.denoise ??= _toDouble(inputs['denoise']);
        fields.positiveNodeId ??= _comfyNodeReference(inputs['positive']);
        fields.negativeNodeId ??= _comfyNodeReference(inputs['negative']);
        break;
      default:
        if (classType.contains('Lora Loader') ||
            classType.contains('LoraLoader')) {
          _readComfyLoras(inputs, fields);
        }
        break;
    }

    if (!classType.contains('CLIPTextEncode')) return;
    final text = inputs['text']?.toString().trim();
    if (text == null || text.isEmpty) return;
    fields.promptsByNodeId[nodeId] = text;
    final rawMeta = node['_meta'];
    final title = rawMeta is Map
        ? rawMeta['title']?.toString().toLowerCase()
        : '';
    if (title?.contains('negative') == true) {
      fields.negativeCandidates.add(text);
    } else {
      fields.positiveCandidates.add(text);
    }
  }

  static void _readComfyLoras(
    Map<String, dynamic> inputs,
    _ComfyWorkflowFields fields,
  ) {
    for (final value in inputs.values.whereType<Map>()) {
      final item = Map<String, dynamic>.from(value);
      final name = item['lora']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      fields.loras.add(name);
      fields.loraStrengths.add(_toDouble(item['strength']) ?? 1);
    }
    final directName = inputs['lora_name']?.toString().trim();
    if (directName == null || directName.isEmpty) return;
    fields.loras.add(directName);
    fields.loraStrengths.add(_toDouble(inputs['strength_model']) ?? 1);
  }

  static ({String? positive, String? negative}) _resolveComfyPrompts(
    _ComfyWorkflowFields fields,
  ) {
    var positive = fields.promptsByNodeId[fields.positiveNodeId];
    var negative = fields.promptsByNodeId[fields.negativeNodeId];
    positive ??= fields.positiveCandidates.firstOrNull;
    negative ??= fields.negativeCandidates.firstOrNull;
    if (negative == null && fields.positiveCandidates.length > 1) {
      negative = fields.positiveCandidates[1];
    }
    return (
      positive: positive == null ? null : _stripComfyBoilerplate(positive),
      negative: negative,
    );
  }

  static String? _comfyNodeReference(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value is String || value is num ? value.toString() : null;
  }

  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static AiTagGenerationInfo? _parseNaiJson(
    Map<String, dynamic> decoded, {
    required String prettyJson,
    required String rawJson,
    required String imageType,
  }) {
    final software =
        decoded['Software']?.toString() ?? decoded['software']?.toString();
    final source =
        decoded['Source']?.toString() ?? decoded['source']?.toString();
    final comment = _decodeJsonMap(decoded['Comment'] ?? decoded['comment']);
    final normalizedSoftware = software?.toLowerCase();
    final normalizedSource = source?.toLowerCase();
    final isNaiHint =
        normalizedSoftware?.contains('novelai') == true ||
        normalizedSource?.contains('novelai') == true ||
        comment != null ||
        _softwareFromImageType(imageType) == 'NovelAI';
    if (!isNaiHint) return null;
    // Direct Comment may be missing but top-level already looks like NAI payload
    // (e.g. {"prompt": "...", "steps": 28}) — treat decoded itself as comment.
    final effectiveComment =
        comment ?? (decoded.containsKey('prompt') ? decoded : null);
    if (effectiveComment == null) return null;
    // Must contain at least one NAI-specific key to avoid misclassifying SD/Comfy.
    final hasNaiKeys =
        effectiveComment.containsKey('prompt') ||
        effectiveComment.containsKey('steps') ||
        effectiveComment.containsKey('sampler') ||
        effectiveComment.containsKey('scale') ||
        effectiveComment.containsKey('width');
    if (!hasNaiKeys) return null;
    try {
      final commentStr = jsonEncode(effectiveComment);
      final meta = NaiImageMetadata.fromNaiComment({
        'Comment': commentStr,
        'Software': software,
        'Source': source,
      }, rawJson: rawJson);
      // If parsing produced no sampler/steps/seed, likely not NAI.
      if (meta.sampler == null &&
          meta.steps == null &&
          meta.seed == null &&
          meta.prompt.isEmpty) {
        return null;
      }
      return _buildNaiInfo(
        decoded: decoded,
        comment: effectiveComment,
        metadata: meta,
        software: software,
        source: source,
        prettyJson: prettyJson,
        rawJson: rawJson,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeJsonMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static AiTagGenerationInfo _buildNaiInfo({
    required Map<String, dynamic> decoded,
    required Map<String, dynamic> comment,
    required NaiImageMetadata metadata,
    required String? software,
    required String? source,
    required String prettyJson,
    required String rawJson,
  }) {
    final modelId = metadata.effectiveModel;
    final displayName = modelId == null
        ? null
        : ImageModels.modelDisplayNames[modelId];
    final model = source?.trim().isNotEmpty == true
        ? source!.trim()
        : (displayName ?? modelId);
    final sourceHash = source == null
        ? null
        : RegExp(r'([A-Fa-f0-9]{8})\s*$').firstMatch(source.trim())?.group(1);
    final modelHash =
        sourceHash?.toUpperCase() ??
        decoded['model_hash']?.toString() ??
        decoded['modelHash']?.toString() ??
        comment['model_hash']?.toString();

    return AiTagGenerationInfo(
      software: software ?? 'NovelAI',
      model: model,
      modelHash: modelHash,
      sampler: metadata.sampler,
      scheduler: metadata.noiseSchedule,
      steps: metadata.steps,
      cfgScale: metadata.scale,
      cfgRescale: metadata.cfgRescale,
      seed: metadata.seed,
      width: metadata.width,
      height: metadata.height,
      smea: metadata.smea,
      smeaDyn: metadata.smeaDyn,
      extra: {
        if (metadata.noiseSchedule != null) 'Noise': metadata.noiseSchedule!,
        if (metadata.smea == true) 'SMEA': 'ON',
        if (metadata.smeaDyn == true) 'SMEA DYN': 'ON',
        if (metadata.qualityTier != null) 'Quality': metadata.qualityTier!,
        if (modelId != null && displayName != null && model != displayName)
          'Model ID': modelId,
        if (metadata.varietyPlus == true) 'Variety+': 'ON',
        if (metadata.characterPrompts.isNotEmpty)
          'Characters': '${metadata.characterPrompts.length}',
        if (source == null && displayName != null) 'Model ID': modelId!,
      },
      prompt: metadata.prompt.isNotEmpty
          ? metadata.prompt
          : comment['prompt']?.toString(),
      negativePrompt: metadata.negativePrompt.isNotEmpty
          ? metadata.negativePrompt
          : comment['uc']?.toString(),
      prettyJson: prettyJson,
      rawJson: rawJson,
    );
  }

  static AiTagGenerationInfo? _parseGenericJson(
    Map<String, dynamic> map, {
    required String prettyJson,
    required String rawJson,
    required String imageType,
  }) {
    // Last resort: shallow keys like model, sampler, steps etc.
    String? str(String k) => map[k]?.toString();
    int? intVal(String k) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? doubleVal(String k) {
      final v = map[k];
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final model = str('model') ?? str('model_name');
    final sampler = str('sampler') ?? str('sampler_name');
    final scheduler = str('scheduler') ?? str('schedule_type');
    final steps = intVal('steps');
    final cfg =
        doubleVal('cfg') ??
        doubleVal('cfg_scale') ??
        doubleVal('scale') ??
        doubleVal('guidance_scale');
    final seed = intVal('seed');
    final width = intVal('width');
    final height = intVal('height');
    final prompt = str('prompt') ?? str('positive_prompt');
    final negativePrompt = str('negative_prompt') ?? str('uc');

    if (model == null && sampler == null && steps == null && prompt == null) {
      return null;
    }

    return AiTagGenerationInfo(
      software: _softwareFromImageType(imageType),
      model: model,
      sampler: sampler,
      scheduler: scheduler,
      steps: steps,
      cfgScale: cfg,
      seed: seed,
      width: width,
      height: height,
      prompt: prompt,
      negativePrompt: negativePrompt,
      prettyJson: prettyJson,
      rawJson: rawJson,
    );
  }

  static String _stripComfyBoilerplate(String text) {
    // Example prefix: "You are an assistant designed to ... <Prompt Start>\n"
    const marker = '<Prompt Start>';
    final idx = text.indexOf(marker);
    if (idx != -1) {
      return text.substring(idx + marker.length).trim();
    }
    return text.trim();
  }

  static String _prettyJson(String raw) {
    if (raw.isEmpty) return raw;
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  static String _softwareFromImageType(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('comfy')) return 'ComfyUI';
    if (lower.contains('sdxl')) return 'Stable Diffusion XL';
    if (lower.contains('sd')) return 'Stable Diffusion WebUI';
    if (lower.contains('nai')) return 'NovelAI';
    return t.isEmpty ? 'Unknown' : t;
  }
}

class _ComfyWorkflowFields {
  String? unetName;
  String? vaeName;
  String? clipName;
  String? sampler;
  String? scheduler;
  int? steps;
  double? cfg;
  int? seed;
  double? denoise;
  int? width;
  int? height;
  String? positiveNodeId;
  String? negativeNodeId;
  final Map<String, String> promptsByNodeId = {};
  final List<String> positiveCandidates = [];
  final List<String> negativeCandidates = [];
  final List<String> loras = [];
  final List<double> loraStrengths = [];
}
