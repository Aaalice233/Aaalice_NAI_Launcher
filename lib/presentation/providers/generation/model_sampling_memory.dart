import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/image/image_params.dart';

/// 某个模型上次使用的采样参数。
@immutable
class ModelSamplingParams {
  const ModelSamplingParams({
    required this.steps,
    required this.scale,
    required this.cfgRescale,
    required this.sampler,
    required this.noiseSchedule,
    required this.varietyPlus,
  });

  factory ModelSamplingParams.of(ImageParams params) => ModelSamplingParams(
    steps: params.steps,
    scale: params.scale,
    cfgRescale: params.cfgRescale,
    sampler: params.sampler,
    noiseSchedule: params.noiseSchedule,
    varietyPlus: params.varietyPlus,
  );

  final int steps;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final bool varietyPlus;

  /// 噪声调度与 Variety+ 仍按目标模型能力纠正，否则界面与实际请求不一致。
  ImageParams applyTo(ImageParams params) {
    final capabilities = params.capabilities;
    return params.copyWith(
      steps: steps,
      scale: scale,
      cfgRescale: cfgRescale,
      sampler: sampler,
      noiseSchedule: NoiseSchedules.resolve(
        noiseSchedule,
        allowNative: capabilities.allowsNativeNoiseSchedule,
      ),
      varietyPlus: varietyPlus && capabilities.retainsVarietyPlus,
    );
  }

  Map<String, Object> toJson() => {
    'steps': steps,
    'scale': scale,
    'cfgRescale': cfgRescale,
    'sampler': sampler,
    'noiseSchedule': noiseSchedule,
    'varietyPlus': varietyPlus,
  };

  /// 字段缺失或类型不符时返回 null，由调用方退回出厂默认值规则。
  static ModelSamplingParams? tryParse(Object? json) {
    if (json is! Map) return null;
    final steps = json['steps'];
    final scale = json['scale'];
    final cfgRescale = json['cfgRescale'];
    final sampler = json['sampler'];
    final noiseSchedule = json['noiseSchedule'];
    final varietyPlus = json['varietyPlus'];
    if (steps is! int ||
        scale is! num ||
        cfgRescale is! num ||
        sampler is! String ||
        noiseSchedule is! String ||
        varietyPlus is! bool) {
      return null;
    }
    return ModelSamplingParams(
      steps: steps,
      scale: scale.toDouble(),
      cfgRescale: cfgRescale.toDouble(),
      sampler: sampler,
      noiseSchedule: noiseSchedule,
      varietyPlus: varietyPlus,
    );
  }
}

/// 只存本机：旧版本的同步预检会整批拒收不认识的设置键。
class ModelSamplingMemory {
  const ModelSamplingMemory(this._storage);

  final LocalStorageService _storage;

  /// 重绘变体与 Effort 档位共用下拉框条目的槽位。
  static String slotOf(String model) =>
      ImageModels.selectorModel(ImageModels.resolveBaseModel(model));

  ModelSamplingParams? recall(String model) =>
      ModelSamplingParams.tryParse(_readAll()[slotOf(model)]);

  void remember(ImageParams params) {
    final entries = _readAll()
      ..[slotOf(params.model)] = ModelSamplingParams.of(params).toJson();
    unawaited(
      _storage.setSetting(StorageKeys.modelSamplingParams, jsonEncode(entries)),
    );
  }

  Map<String, Object?> _readAll() {
    final raw = _storage.getSetting<Object?>(StorageKeys.modelSamplingParams);
    if (raw is! String || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return Map.of(decoded);
    } on FormatException {
      // 统一在下方告警，不带原文。
    }
    AppLogger.w('按模型保存的采样参数无法解析，已忽略', 'GenerationParams');
    return {};
  }
}
