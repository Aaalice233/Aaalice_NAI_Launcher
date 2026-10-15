import 'binary_mask.dart';

/// 蒙版按 latent 网格最近邻采样后一个重绘单元都不剩，发出请求只会原样返回底图。
class EmptyInpaintMaskException implements Exception {
  const EmptyInpaintMaskException();

  static const errorCode = 'GENERATION_ERROR_EMPTY_INPAINT_MASK';

  String get encodedMessage =>
      '$errorCode|Inpaint mask is empty after sampling to the '
      '${novelAiLatentGridSize}px latent grid; '
      'make the masked area thicker or larger.';

  // 流式通道和生成状态只保留字符串，需要从消息里识别。
  static bool matches(Object? error) =>
      error is EmptyInpaintMaskException ||
      (error != null && error.toString().contains(errorCode));

  @override
  String toString() => encodedMessage;
}
