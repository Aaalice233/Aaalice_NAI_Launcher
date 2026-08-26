import 'dart:convert';
import 'dart:typed_data';


const List<int> _pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

String? detectSupportedImageMimeType(Uint8List buffer) {
  if (_startsWith(buffer, [0xff, 0xd8, 0xff])) {
    return buffer.length > 3 && buffer[3] == 0xf7 ? null : 'image/jpeg';
  }
  if (_startsWith(buffer, _pngSignature)) {
    return _isPng(buffer) && !_isAnimatedPng(buffer) ? 'image/png' : null;
  }
  if (_startsWithAscii(buffer, 0, 'GIF')) {
    return 'image/gif';
  }
  if (_startsWithAscii(buffer, 0, 'RIFF') && _startsWithAscii(buffer, 8, 'WEBP')) {
    return 'image/webp';
  }
  if (_startsWithAscii(buffer, 0, 'BM') && _isBmp(buffer)) {
    return 'image/bmp';
  }
  return null;
}

String encodeBase64ImageBytes(Uint8List bytes) {
  return base64Encode(bytes);
}

bool _isPng(Uint8List buffer) {
  return buffer.length >= 16 &&
      _readUint32BE(buffer, _pngSignature.length) == 13 &&
      _startsWithAscii(buffer, 12, 'IHDR');
}

bool _isAnimatedPng(Uint8List buffer) {
  var offset = _pngSignature.length;
  while (offset + 8 <= buffer.length) {
    final chunkLength = _readUint32BE(buffer, offset);
    final chunkTypeOffset = offset + 4;
    if (_startsWithAscii(buffer, chunkTypeOffset, 'acTL')) {
      return true;
    }
    if (_startsWithAscii(buffer, chunkTypeOffset, 'IDAT')) {
      return false;
    }
    final nextOffset = offset + 8 + chunkLength + 4;
    if (nextOffset <= offset || nextOffset > buffer.length) {
      return false;
    }
    offset = nextOffset;
  }
  return false;
}

bool _isBmp(Uint8List buffer) {
  if (buffer.length < 26) {
    return false;
  }
  final declaredFileSize = _readUint32LE(buffer, 2);
  final pixelDataOffset = _readUint32LE(buffer, 10);
  final dibHeaderSize = _readUint32LE(buffer, 14);
  if (declaredFileSize != 0 && declaredFileSize < 26) {
    return false;
  }
  if (pixelDataOffset < 14 + dibHeaderSize) {
    return false;
  }
  if (declaredFileSize != 0 && pixelDataOffset >= declaredFileSize) {
    return false;
  }

  int colorPlanes;
  int bitsPerPixel;
  if (dibHeaderSize == 12) {
    colorPlanes = _readUint16LE(buffer, 22);
    bitsPerPixel = _readUint16LE(buffer, 24);
  } else if (dibHeaderSize >= 40 && dibHeaderSize <= 124) {
    if (buffer.length < 30) {
      return false;
    }
    colorPlanes = _readUint16LE(buffer, 26);
    bitsPerPixel = _readUint16LE(buffer, 28);
  } else {
    return false;
  }
  return colorPlanes == 1 && [1, 4, 8, 16, 24, 32].contains(bitsPerPixel);
}

int _readUint16LE(Uint8List buffer, int offset) {
  return (offset < buffer.length ? buffer[offset] : 0) +
      (((offset + 1) < buffer.length ? buffer[offset + 1] : 0) << 8);
}

int _readUint32BE(Uint8List buffer, int offset) {
  return (offset < buffer.length ? buffer[offset] : 0) * 0x1000000 +
      (((offset + 1) < buffer.length ? buffer[offset + 1] : 0) << 16) +
      (((offset + 2) < buffer.length ? buffer[offset + 2] : 0) << 8) +
      ((offset + 3) < buffer.length ? buffer[offset + 3] : 0);
}

int _readUint32LE(Uint8List buffer, int offset) {
  return (offset < buffer.length ? buffer[offset] : 0) +
      (((offset + 1) < buffer.length ? buffer[offset + 1] : 0) << 8) +
      (((offset + 2) < buffer.length ? buffer[offset + 2] : 0) << 16) +
      ((offset + 3) < buffer.length ? buffer[offset + 3] : 0) * 0x1000000;
}

bool _startsWith(Uint8List buffer, List<int> bytes) {
  if (buffer.length < bytes.length) {
    return false;
  }
  for (var index = 0; index < bytes.length; index++) {
    if (buffer[index] != bytes[index]) {
      return false;
    }
  }
  return true;
}

bool _startsWithAscii(Uint8List buffer, int offset, String text) {
  if (buffer.length < offset + text.length) {
    return false;
  }
  for (var index = 0; index < text.length; index++) {
    if (buffer[offset + index] != text.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}
