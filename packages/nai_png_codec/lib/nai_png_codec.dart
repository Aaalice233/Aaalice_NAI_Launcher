import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

@Native<
  Int Function(Pointer<Uint8>, Size, Pointer<Pointer<Void>>, Pointer<Size>)
>(symbol: 'nai_png_sanitize')
external int _sanitize(
  Pointer<Uint8> input,
  int inputSize,
  Pointer<Pointer<Void>> output,
  Pointer<Size> outputSize,
);

@Native<Void Function(Pointer<Void>)>(symbol: 'nai_png_free')
external void _free(Pointer<Void> memory);

@Native<Pointer<Char> Function(Int)>(symbol: 'nai_png_error')
external Pointer<Char> _error(int code);

@Native<
  Int Function(
    Pointer<Uint8>,
    Size,
    Uint32,
    Uint32,
    Pointer<Pointer<Void>>,
    Pointer<Size>,
  )
>(symbol: 'nai_png_encode_rgba')
external int _encodeRgba(
  Pointer<Uint8> pixels,
  int length,
  int width,
  int height,
  Pointer<Pointer<Void>> output,
  Pointer<Size> outputSize,
);

Uint8List encodePngRgba(Uint8List pixels, int width, int height) {
  if (width <= 0 || height <= 0 || pixels.length != width * height * 4) {
    throw ArgumentError('RGBA buffer does not match its dimensions');
  }
  return _withNativeBuffer(
    pixels,
    (input, output, outputSize) =>
        _encodeRgba(input, pixels.length, width, height, output, outputSize),
  );
}

/// Input must have its ancillary metadata and trailing data removed first.
/// Native errors are never converted into unprotected image bytes.
Uint8List sanitizePngPixels(Uint8List bytes) {
  return _withNativeBuffer(
    bytes,
    (input, output, outputSize) =>
        _sanitize(input, bytes.length, output, outputSize),
  );
}

Uint8List _withNativeBuffer(
  Uint8List bytes,
  int Function(Pointer<Uint8>, Pointer<Pointer<Void>>, Pointer<Size>) process,
) {
  final input = calloc<Uint8>(bytes.length);
  final output = calloc<Pointer<Void>>();
  final outputSize = calloc<Size>();
  try {
    input.asTypedList(bytes.length).setAll(0, bytes);
    final result = process(input, output, outputSize);
    if (result == 1) return bytes;
    if (result != 0) {
      final message = _error(result).cast<Utf8>().toDartString();
      throw FormatException('PNG sanitization failed ($result): $message');
    }
    return Uint8List.fromList(
      output.value.cast<Uint8>().asTypedList(outputSize.value),
    );
  } finally {
    _free(output.value);
    calloc.free(input);
    calloc.free(output);
    calloc.free(outputSize);
  }
}
