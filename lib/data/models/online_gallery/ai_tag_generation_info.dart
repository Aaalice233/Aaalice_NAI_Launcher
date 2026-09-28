import 'dart:convert';

/// Structured generation info extracted from aitag.win `ai_json` / `prompt_text`.
///
/// Mirrors what the web site renders per-image (Model, LoRA, Sampler,
/// CFG, Steps, Seed, Size …) instead of dumping the raw JSON as one block.
class AiTagGenerationInfo {
  const AiTagGenerationInfo({
    this.software,
    this.model,
    this.modelHash,
    this.vae,
    this.clip,
    this.sampler,
    this.scheduler,
    this.scheduleType,
    this.steps,
    this.cfgScale,
    this.cfgRescale,
    this.shift,
    this.denoise,
    this.seed,
    this.width,
    this.height,
    this.smea,
    this.smeaDyn,
    this.loras = const [],
    this.loraStrengths = const [],
    this.extra = const {},
    this.prompt,
    this.negativePrompt,
    required this.prettyJson,
    required this.rawJson,
  });

  final String? software;
  final String? model;
  final String? modelHash;
  final String? vae;
  final String? clip;
  final String? sampler;
  final String? scheduler;
  final String? scheduleType;
  final int? steps;
  final double? cfgScale;
  final double? cfgRescale;
  final double? shift;
  final double? denoise;
  final int? seed;
  final int? width;
  final int? height;
  final bool? smea;
  final bool? smeaDyn;
  final List<String> loras;
  final List<double> loraStrengths;
  final Map<String, String> extra;
  final String? prompt;
  final String? negativePrompt;
  final String prettyJson;
  final String rawJson;

  bool get hasAnyParam =>
      model != null ||
      modelHash != null ||
      vae != null ||
      clip != null ||
      sampler != null ||
      steps != null ||
      cfgScale != null ||
      cfgRescale != null ||
      shift != null ||
      denoise != null ||
      seed != null ||
      scheduler != null ||
      scheduleType != null ||
      width != null ||
      height != null ||
      smea == true ||
      smeaDyn == true ||
      loras.isNotEmpty ||
      extra.isNotEmpty;

  bool get hasPrompt =>
      (prompt != null && prompt!.trim().isNotEmpty) ||
      (negativePrompt != null && negativePrompt!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
    if (software != null) 'software': software,
    if (model != null) 'model': model,
    if (modelHash != null) 'modelHash': modelHash,
    if (vae != null) 'vae': vae,
    if (clip != null) 'clip': clip,
    if (sampler != null) 'sampler': sampler,
    if (scheduler != null) 'scheduler': scheduler,
    if (scheduleType != null) 'scheduleType': scheduleType,
    if (steps != null) 'steps': steps,
    if (cfgScale != null) 'cfgScale': cfgScale,
    if (cfgRescale != null) 'cfgRescale': cfgRescale,
    if (shift != null) 'shift': shift,
    if (denoise != null) 'denoise': denoise,
    if (seed != null) 'seed': seed,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (smea != null) 'smea': smea,
    if (smeaDyn != null) 'smeaDyn': smeaDyn,
    'loras': loras,
    'loraStrengths': loraStrengths,
    'extra': extra,
    if (prompt != null) 'prompt': prompt,
    if (negativePrompt != null) 'negativePrompt': negativePrompt,
    'prettyJson': prettyJson,
    'rawJson': rawJson,
  };

  factory AiTagGenerationInfo.fromJson(Map<String, dynamic> json) {
    return AiTagGenerationInfo(
      software: json['software'] as String?,
      model: json['model'] as String?,
      modelHash: json['modelHash'] as String?,
      vae: json['vae'] as String?,
      clip: json['clip'] as String?,
      sampler: json['sampler'] as String?,
      scheduler: json['scheduler'] as String?,
      scheduleType: json['scheduleType'] as String?,
      steps: (json['steps'] as num?)?.toInt(),
      cfgScale: (json['cfgScale'] as num?)?.toDouble(),
      cfgRescale: (json['cfgRescale'] as num?)?.toDouble(),
      shift: (json['shift'] as num?)?.toDouble(),
      denoise: (json['denoise'] as num?)?.toDouble(),
      seed: (json['seed'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      smea: json['smea'] as bool?,
      smeaDyn: json['smeaDyn'] as bool?,
      loras: (json['loras'] as List?)?.cast<String>() ?? const [],
      loraStrengths:
          (json['loraStrengths'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      extra:
          (json['extra'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      prompt: json['prompt'] as String?,
      negativePrompt: json['negativePrompt'] as String?,
      prettyJson: json['prettyJson'] as String? ?? '',
      rawJson: json['rawJson'] as String? ?? '',
    );
  }

  /// Try to decode from GalleryMedia.metadata['aiTag'].
  static AiTagGenerationInfo? tryFromMediaMetadata(
    Map<String, dynamic> metadata,
  ) {
    final raw = metadata['aiTag'];
    if (raw is Map) {
      try {
        return AiTagGenerationInfo.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return AiTagGenerationInfo.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String get sizeString {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return '$width×$height';
    }
    return '';
  }

  /// Compact model label for gallery badges without rewriting raw metadata.
  String modelBadgeLabel({String? fallbackType}) {
    final descriptor = [
      fallbackType,
      software,
      model,
      extra['Model ID'],
    ].whereType<String>().join(' ');
    final normalized = descriptor.toLowerCase();

    if (normalized.contains('novelai') ||
        RegExp(r'\bnai\b').hasMatch(normalized)) {
      final versionMatch = RegExp(
        r'(?:novelai(?:\s+diffusion)?|nai(?:[-_\s]+diffusion)?)'
        r'[-_\s]*v?[-_\s]*(5|4(?:[._-]5)?|4|3)',
        caseSensitive: false,
      ).firstMatch(descriptor);
      final version = versionMatch?.group(1)?.replaceAll(RegExp(r'[_-]'), '.');
      final variant = normalized.contains('curated')
          ? 'Curated'
          : normalized.contains('full')
          ? 'Full'
          : null;
      return [
        'NAI',
        if (version != null) 'V$version',
        if (variant != null) variant,
      ].join(' ');
    }

    if (normalized.contains('stable diffusion xl') ||
        normalized.contains('sdxl')) {
      return 'SDXL';
    }
    final sdVersion = RegExp(
      r'(?:stable diffusion|\bsd)[-_\s]*v?[-_\s]*'
      r'(3(?:\.5)?|2(?:\.1)?|1\.5)',
      caseSensitive: false,
    ).firstMatch(descriptor)?.group(1);
    if (sdVersion != null) return 'SD $sdVersion';

    final fallback = fallbackType?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final fallbackSoftware = software?.trim();
    if (fallbackSoftware != null && fallbackSoftware.isNotEmpty) {
      return fallbackSoftware;
    }
    return model?.trim() ?? '';
  }

  /// Human-readable sampler label including scheduler when present.
  String get displaySampler {
    if (sampler == null || sampler!.isEmpty) return '';
    if (scheduler != null && scheduler!.isNotEmpty) {
      return '$sampler / $scheduler';
    }
    if (scheduleType != null && scheduleType!.isNotEmpty) {
      return '$sampler ($scheduleType)';
    }
    return sampler!;
  }
}
