// 把生图请求体的键序对齐官网前端：官网的顺序来自状态对象与提交流程的赋值
// 先后，请求体可逐字节比对。这里只重排已有键，不增删任何字段。

import 'package:flutter/foundation.dart';

import '../../constants/api_constants.dart';
import '../../utils/app_logger.dart';

const List<String> _topLevelOrder = [
  'input',
  'model',
  'action',
  'parameters',
  'use_new_shared_trial',
];

/// 模型默认参数对象自带的键，顺序即官网预设字面量的书写顺序。
const List<String> _presetKeys = [
  'params_version',
  'width',
  'height',
  'scale',
  'sampler',
  'steps',
  'seed',
  'n_samples',
  'strength',
  'noise',
  'ucPresetId',
  'qualityPresetId',
  'tag_hint_transparent_background',
  'autoSmea',
  'sm',
  'sm_dyn',
  'dynamic_thresholding',
  'controlnet_strength',
  'legacy',
  'add_original_image',
  'cfg_rescale',
];

/// 预设块里 `noise_schedule` 之后的剩余键。
const List<String> _presetTailKeys = [
  'legacy_v3_extend',
  'skip_cfg_above_sigma',
  'use_coords',
  'normalize_reference_strength_multiple',
  'inpaintImg2ImgStrength',
];

/// 用户操作过程中追加到状态对象上的键。
const List<String> _stateKeys = [
  'v4_prompt',
  'v4_negative_prompt',
  'uc',
  'legacy_uc',
  'characterPrompts',
  'upscale',
  'upscaled_enhance',
  'image',
  'mask',
];

/// 提交阶段按顺序追加的键（Vibe 与精准参考除外）。
const List<String> _submissionKeys = [
  'straight_alpha',
  'tag_hint_qt',
  'tag_hint_uc_preset',
  'extra_noise_seed',
  'color_correct',
  'img2img',
];

/// V4 起的 Vibe 走编码结果，信息提取量已含在编码里，官网只写这两个键。
const List<String> _encodedVibeKeys = [
  'reference_image_multiple',
  'reference_strength_multiple',
];

/// V3 系 Vibe 直接上传原图，信息提取量在强度之前写入。
const List<String> _rawVibeKeys = [
  'reference_image_multiple',
  'reference_information_extracted_multiple',
  'reference_strength_multiple',
];

const List<String> _directorKeys = [
  'director_reference_images',
  'director_reference_descriptions',
  'director_reference_information_extracted',
  'director_reference_strength_values',
  'director_reference_secondary_strength_values',
];

/// 归一化阶段追加的键，`image_format` 与 `stream` 永远在最后。
const List<String> _normalizationKeys = [
  'negative_prompt',
  'deliberate_euler_ancestral_bug',
  'prefer_brownian',
];

const String _noiseSchedule = 'noise_schedule';

/// 返回按官网顺序重排后的请求体。
Map<String, dynamic> orderOfficialRequest(Map<String, dynamic> requestData) {
  final ordered = _reorder(requestData, _topLevelOrder, 'request');
  final parameters = ordered['parameters'];
  if (parameters is Map<String, dynamic>) {
    ordered['parameters'] = _reorder(
      parameters,
      officialParameterOrder(ordered['model']),
      'parameters',
    );
  }
  return ordered;
}

/// 指定请求模型下 `parameters` 的官网键序。
@visibleForTesting
List<String> officialParameterOrder(Object? model) {
  final resolved = model is String ? ImageModels.migrateLegacyModel(model) : '';
  // V5 的噪声调度先被删除再重设，因而落到归一化阶段的末尾。
  final isV5 = ImageModels.isV5Model(resolved);
  return [
    ..._presetKeys,
    if (!isV5) _noiseSchedule,
    ..._presetTailKeys,
    ..._stateKeys,
    ..._submissionKeys,
    if (ImageModels.isV4Model(resolved))
      ..._encodedVibeKeys
    else
      ..._rawVibeKeys,
    ..._directorKeys,
    ..._normalizationKeys,
    if (isV5) _noiseSchedule,
    'image_format',
    'stream',
  ];
}

/// 请求体中未登记顺序的键，按容器名分组。
@visibleForTesting
Map<String, List<String>> unregisteredRequestKeys(
  Map<String, dynamic> requestData,
) {
  final parameters = requestData['parameters'];
  return {
    'request': _unregisteredKeys(requestData, _topLevelOrder),
    if (parameters is Map<String, dynamic>)
      'parameters': _unregisteredKeys(
        parameters,
        officialParameterOrder(requestData['model']),
      ),
  }..removeWhere((_, keys) => keys.isEmpty);
}

Map<String, dynamic> _reorder(
  Map<String, dynamic> source,
  List<String> order,
  String container,
) {
  final ordered = <String, dynamic>{};
  for (final key in order) {
    if (source.containsKey(key)) ordered[key] = source[key];
  }
  final unregistered = _unregisteredKeys(source, order);
  if (unregistered.isNotEmpty && kDebugMode) {
    AppLogger.w(
      'Request keys without an official position in $container: '
          '${unregistered.join(', ')}',
      'ImgGen',
    );
  }
  for (final key in unregistered) {
    ordered[key] = source[key];
  }
  return ordered;
}

List<String> _unregisteredKeys(
  Map<String, dynamic> source,
  List<String> order,
) {
  final registered = order.toSet();
  return source.keys
      .where((key) => !registered.contains(key))
      .toList(growable: false);
}
