import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/constants/api_constants.dart';
import '../../providers/image_generation_provider.dart';
import 'generation_tool_results.dart';

class GenerationSettingsService {
  GenerationSettingsService(this._ref);
  final Ref _ref;
  String settingsJson() {
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

  Future<AgentToolResult> updateSettings(Map<String, dynamic> args) async {
    if (args.isEmpty) {
      return generationErrorResult('Provide at least one setting to change.');
    }
    final notifier = _ref.read(generationParamsNotifierProvider.notifier);
    final applied = <String, dynamic>{};

    // model 先应用（切换模型可能联动 steps/scale 默认值），随后显式字段覆盖。
    // 支持友好别名（v5 / v4.5 curated / v3 等），解析失败时列出可选模型。
    final model = (args['model'] as String?)?.trim();
    if (model != null && model.isNotEmpty) {
      final resolved = _resolveModelId(model);
      if (resolved == null) {
        return generationErrorResult(
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
      return generationErrorResult(
        'No recognized settings found in arguments. Call '
        'get_generation_settings for valid field names.',
      );
    }
    // updateXxx 经 Future.microtask 写入 state，冲刷后再回读生效值。
    await Future<void>.delayed(Duration.zero);
    return generationTextResult(
      jsonEncode({'ok': true, 'applied': applied, 'current': settingsJson()}),
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
}
