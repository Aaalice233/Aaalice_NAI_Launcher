/// 蒙版按 latent 网格最近邻采样后一个重绘单元都不剩，发出请求只会原样返回底图。
class EmptyInpaintMaskException implements Exception {
  const EmptyInpaintMaskException({required this.latentGridSize});

  static const errorCode = 'GENERATION_ERROR_EMPTY_INPAINT_MASK';

  final int latentGridSize;

  String get encodedMessage =>
      '$errorCode|$latentGridSize|Inpaint mask is empty after sampling to the '
      '${latentGridSize}px latent grid; make the masked area thicker or larger.';

  // 流式通道和生成状态只保留字符串，需要从消息里还原。
  static EmptyInpaintMaskException? tryParse(Object? error) {
    if (error is EmptyInpaintMaskException) return error;
    if (error == null) return null;
    final text = error.toString();
    final start = text.indexOf(errorCode);
    if (start < 0) return null;
    final fields = text.substring(start).split('|');
    final gridSize = fields.length > 1 ? int.tryParse(fields[1]) : null;
    if (gridSize == null || gridSize <= 0) return null;
    return EmptyInpaintMaskException(latentGridSize: gridSize);
  }

  @override
  String toString() => encodedMessage;
}
