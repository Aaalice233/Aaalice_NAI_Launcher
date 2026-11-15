import '../../../core/constants/api_constants.dart';
import '../../../core/utils/enhance_request_plan.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_params_notifier.dart';
import 'image_workflow_models.dart';

final class ImageWorkflowParamsSyncService {
  const ImageWorkflowParamsSyncService({
    required GenerationParamsNotifier Function() paramsNotifier,
    required ImageParams Function() readParams,
  }) : _paramsNotifier = paramsNotifier,
       _readParams = readParams;

  final GenerationParamsNotifier Function() _paramsNotifier;
  final ImageParams Function() _readParams;

  GenerationParamsNotifier get _notifier => _paramsNotifier();
  ImageParams get _params => _readParams();

  /// 返回是否消费了进入增强前拍摄的 strength / noise 快照。
  bool restoreBaseParams(ImageWorkflowState state) {
    // 增强专属的一次性标记只属于增强请求，离开增强模式必须清掉，
    // 否则后续普通生成会带着 max 档参数或自动补的降权词发出去。
    _notifier.updateUpscaledEnhance(false);
    _notifier.updateIsEnhanceRequest(false);
    if (state.baseWidth != null && state.baseHeight != null) {
      _notifier.updateSize(state.baseWidth!, state.baseHeight!, persist: false);
    }
    final entryStrength = state.enhanceEntryStrength;
    final entryNoise = state.enhanceEntryNoise;
    if (entryStrength != null) {
      _notifier.updateStrength(entryStrength);
    }
    if (entryNoise != null) {
      _notifier.updateNoise(entryNoise);
    }
    return entryStrength != null || entryNoise != null;
  }

  void applyEnhanceToParams(ImageWorkflowState state) {
    final params = _params;
    if (params.sourceImage == null) {
      return;
    }

    final settings = state.enhance;
    final plan = EnhanceRequestPlan.resolve(
      capabilities: params.capabilities,
      sourceWidth: state.sourceWidth ?? state.baseWidth ?? params.width,
      sourceHeight: state.sourceHeight ?? state.baseHeight ?? params.height,
      level: settings.level,
      factor: settings.upscaleFactor,
      maxScale: settings.maxScale,
      individual: settings.showIndividualSettings
          ? (strength: settings.strength, noise: settings.noise)
          : null,
    );

    _notifier.updateSize(plan.width, plan.height, persist: false);
    _notifier.updateStrength(plan.strength);
    _notifier.updateNoise(plan.noise);
    _notifier.updateUpscaledEnhance(plan.maxScale);
    _notifier.updateIsEnhanceRequest(true);
    _notifier.updateAction(ImageGenerationAction.img2img);
  }

  void applySourceSizeToParams(ImageWorkflowState state) {
    final width = state.sourceWidth;
    final height = state.sourceHeight;
    if (width == null || height == null) {
      return;
    }

    _notifier.updateSize(width, height, persist: false);
  }

  void syncInpaintRequestState(ImageWorkflowState state) {
    if (state.mode != ImageWorkflowMode.inpaint) {
      return;
    }

    if (_params.maskImage != null) {
      _notifier.updateIsOutpaint(state.isOutpaint);
      _notifier.updateAction(ImageGenerationAction.infill);
      return;
    }

    _notifier.updateIsOutpaint(false);
    _notifier.updateAction(ImageGenerationAction.img2img);
  }

  void clearSourceParams(
    ImageWorkflowState state, {
    required void Function() restoreBaseParams,
  }) {
    if (state.baseWidth != null || state.baseHeight != null) {
      restoreBaseParams();
    } else if (ImageModels.isInpaintingModel(_params.model)) {
      _notifier.updateModel(
        ImageModels.resolveBaseModel(_params.model),
        persist: false,
        followDefaults: false,
      );
    }

    _notifier.clearImg2Img();
    _notifier.setMaskImage(null);
  }
}
