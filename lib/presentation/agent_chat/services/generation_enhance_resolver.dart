import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/utils/enhance_request_plan.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import '../../providers/generation/image_workflow_controller.dart';
import 'defined_agent_tool.dart';

enum GenerationEnhanceScale {
  one('1x', 1.0),
  oneAndHalf('1.5x', 1.5),
  two('2x', 2.0),
  max('max', null);

  const GenerationEnhanceScale(this.wireName, this.factor);

  final String wireName;

  /// max 档不按倍率放大，由服务端放到面积上限。
  final double? factor;

  static GenerationEnhanceScale? fromWire(Object? value) {
    for (final scale in values) {
      if (scale.wireName == value) return scale;
    }
    return null;
  }

  static GenerationEnhanceScale fromFactor(double factor) =>
      values.firstWhere((scale) => scale.factor == factor);
}

/// 准备阶段解析出的增强选择，随 preparation 回显给调用方核对。
final class GenerationEnhanceSelection {
  const GenerationEnhanceSelection({
    required this.level,
    required this.plan,
    required this.callerStrength,
  });

  final int level;
  final EnhanceRequestPlan plan;

  /// strength/noise 由调用方给出，而不是按档位换算。
  final bool callerStrength;

  GenerationEnhanceScale get scale => plan.maxScale
      ? GenerationEnhanceScale.max
      : GenerationEnhanceScale.fromFactor(plan.factor);

  Map<String, dynamic> toJson() {
    // max 档请求携带原图尺寸，服务端按放大到面积上限后的尺寸计费。
    final billed = plan.maxScale
        ? E2eUpscale.resolveMaxEnhanceTargetSize(plan.width, plan.height)
        : null;
    return {
      'level': level,
      'scale': scale.wireName,
      'strength': plan.strength,
      'noise': plan.noise,
      'strength_source': callerStrength ? 'caller' : 'level',
      if (billed != null)
        'billed_size': {'width': billed.width, 'height': billed.height},
    };
  }
}

/// 把 `enhance` 参数换算成与生成页增强面板一致的请求计划。
abstract final class GenerationEnhanceResolver {
  static const List<String> scaleWireNames = ['1x', '1.5x', '2x', 'max'];

  /// 尺寸只取底图自身的导入分辨率：沿用生成页尺寸会在页面停留于增强
  /// 结果时把倍率叠上去，同一张图在不同页面状态下得到不同输出。
  static Future<HarnessResult<GenerationEnhanceSelection, AgentToolResult>>
  resolve({
    required Object rawEnhance,
    required ImageParams base,
    required Uint8List source,
    required EnhanceWorkflowSettings pageDefaults,
    double? callerStrength,
    double? callerNoise,
  }) async {
    if (rawEnhance is! Map) {
      return err(
        agentToolError(
          'invalid_enhance',
          'Parameter "enhance" must be an object.',
        ),
      );
    }
    final rawLevel = rawEnhance['level'];
    if (rawLevel != null &&
        (rawLevel is! int ||
            rawLevel < EnhanceLevels.minLevel ||
            rawLevel > EnhanceLevels.maxLevel)) {
      return err(
        agentToolError(
          'invalid_enhance',
          'enhance.level must be an integer from ${EnhanceLevels.minLevel} '
              'to ${EnhanceLevels.maxLevel}.',
        ),
      );
    }
    final rawScale = rawEnhance['scale'];
    final requestedScale = GenerationEnhanceScale.fromWire(rawScale);
    if (rawScale != null && requestedScale == null) {
      return err(
        agentToolError(
          'invalid_enhance',
          'enhance.scale must be one of ${scaleWireNames.join(', ')}.',
        ),
      );
    }

    final imported = await NaiResolutionAdapter.describeImageForImportAsync(
      source,
      isStableDiffusionFamily: ImageModels.usesStableDiffusionImportBounds(
        base.model,
      ),
    );
    if (imported == null) {
      return err(
        agentToolError(
          'source_decode_failed',
          'The source image could not be decoded for Enhance.',
        ),
      );
    }

    if (requestedScale != null) {
      final available = availableScales(
        base.capabilities,
        sourceWidth: imported.width,
        sourceHeight: imported.height,
      );
      if (!available.contains(requestedScale)) {
        return err(
          agentToolError(
            'enhance_scale_unavailable',
            'enhance.scale ${requestedScale.wireName} is not available for a '
                '${imported.width}x${imported.height} source on ${base.model}. '
                'Available: ${available.map((scale) => scale.wireName).join(', ')}.',
          ),
        );
      }
    }

    final level = rawLevel as int? ?? pageDefaults.level;
    final preset = EnhanceLevels.resolve(level);
    final individual = callerStrength == null && callerNoise == null
        ? null
        : (
            strength: callerStrength ?? preset.strength,
            noise: callerNoise ?? preset.noise,
          );
    // 省略 scale 时沿用生成页偏好，不可用就按生成页同样的规则回落。
    final plan = EnhanceRequestPlan.resolve(
      capabilities: base.capabilities,
      sourceWidth: imported.width,
      sourceHeight: imported.height,
      level: level,
      factor: requestedScale?.factor ?? pageDefaults.upscaleFactor,
      maxScale: requestedScale == null
          ? pageDefaults.maxScale
          : requestedScale == GenerationEnhanceScale.max,
      individual: individual,
    );
    return ok(
      GenerationEnhanceSelection(
        level: level,
        plan: plan,
        callerStrength: individual != null,
      ),
    );
  }

  static List<GenerationEnhanceScale> availableScales(
    ModelCapabilities capabilities, {
    required int sourceWidth,
    required int sourceHeight,
  }) => [
    for (final factor in EnhanceScales.availableFactors(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ))
      GenerationEnhanceScale.fromFactor(factor),
    if (E2eUpscale.allowsMaxEnhance(
      capabilities,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    ))
      GenerationEnhanceScale.max,
  ];
}
