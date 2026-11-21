enum FocusedInpaintInput { source, mask }

class FocusedInpaintInputException implements Exception {
  const FocusedInpaintInputException.invalidCrop()
    : code = invalidCropCode,
      input = null;

  const FocusedInpaintInputException.decodeFailed(
    FocusedInpaintInput this.input,
  ) : code = decodeFailedCode;

  static const invalidCropCode = 'GENERATION_ERROR_INVALID_INPAINT_FRAME';
  static const decodeFailedCode = 'GENERATION_ERROR_UNREADABLE_INPAINT_IMAGE';
  final String code;
  final FocusedInpaintInput? input;

  String get logMessage => switch (input) {
    final label? => '$code input=${label.name}',
    null => code,
  };

  @override
  String toString() => code;
}
