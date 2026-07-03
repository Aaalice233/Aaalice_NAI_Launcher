part of 'image_editor_screen.dart';

enum ImageEditorMode { edit, inpaint }

class ImageEditorFocusedInpaintCostConfig {
  const ImageEditorFocusedInpaintCostConfig({
    required this.model,
    required this.steps,
    required this.batchCount,
    required this.batchSize,
    required this.smea,
    required this.smeaDyn,
    required this.subscriptionTier,
    this.extraPerSampleCost = 0,
  });

  final String model;
  final int steps;
  final int batchCount;
  final int batchSize;
  final bool smea;
  final bool smeaDyn;
  final int subscriptionTier;
  final int extraPerSampleCost;

  int estimate({required int width, required int height}) {
    return AnlasCalculator.calculateRequestCost(
      width: width,
      height: height,
      steps: steps,
      batchCount: batchCount,
      batchSize: batchSize,
      smea: smea,
      smeaDyn: smeaDyn,
      model: model,
      subscriptionTier: subscriptionTier,
      strength: 1.0,
      extraPerSampleCost: extraPerSampleCost,
    );
  }
}

class _FocusedInpaintCostEstimate {
  const _FocusedInpaintCostEstimate({
    required this.width,
    required this.height,
    required this.cost,
  });

  final int width;
  final int height;
  final int cost;
}

/// 图像编辑器返回结果
class ImageEditorResult {
  /// 修改后的图像（涂鸦合并）
  final Uint8List? modifiedImage;

  /// Inpainting蒙版图像
  final Uint8List? maskImage;

  /// 是否有图像修改
  final bool hasImageChanges;

  /// 是否有蒙版修改
  final bool hasMaskChanges;

  /// Focused Inpaint 选区范围
  final Rect? focusAreaRect;

  /// Focused Inpaint 上下文带宽
  final double minimumContextMegaPixels;

  /// 是否启用 Focused Inpaint
  final bool focusedInpaintEnabled;

  /// Outpaint 扩展后的源图像
  final Uint8List? outpaintSourceImage;

  /// Outpaint 扩展后的源图像宽度
  final int? outpaintSourceWidth;

  /// Outpaint 扩展后的源图像高度
  final int? outpaintSourceHeight;

  /// 是否有 Outpaint 源图像修改
  final bool hasOutpaintChanges;

  const ImageEditorResult({
    this.modifiedImage,
    this.maskImage,
    this.hasImageChanges = false,
    this.hasMaskChanges = false,
    this.focusAreaRect,
    this.minimumContextMegaPixels = 88.0,
    this.focusedInpaintEnabled = false,
    this.outpaintSourceImage,
    this.outpaintSourceWidth,
    this.outpaintSourceHeight,
    this.hasOutpaintChanges = false,
  });
}
