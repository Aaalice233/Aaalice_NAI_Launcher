import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../utils/isolate_pool.dart';

class KritaOutboundImage {
  const KritaOutboundImage({
    required this.bytes,
    required this.name,
  });

  final Uint8List bytes;
  final String name;

  static KritaOutboundImage prepare(
    Uint8List imageBytes, {
    required String name,
  }) {
    if (_isPng(imageBytes)) {
      return KritaOutboundImage(bytes: imageBytes, name: _pngName(name));
    }

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } on Object {
      throw const FormatException('Unsupported image format for Krita send');
    }
    if (decoded == null) {
      throw const FormatException('Unsupported image format for Krita send');
    }

    return KritaOutboundImage(
      bytes: Uint8List.fromList(img.encodePng(decoded)),
      name: _pngName(name),
    );
  }

  /// 与 [prepare] 结果一致；非 PNG 的整图解码与重编码放到后台 isolate。
  static Future<KritaOutboundImage> prepareInBackground(
    Uint8List imageBytes, {
    required String name,
    ComputeGate? gate,
  }) async {
    if (_isPng(imageBytes)) {
      return prepare(imageBytes, name: name);
    }
    return (gate ?? ComputeGate()).runIsolate(
      () => prepare(imageBytes, name: name),
    );
  }

  static String _pngName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'launcher_image.png';
    }
    if (p.extension(trimmed).toLowerCase() == '.png') {
      return trimmed;
    }
    return p.setExtension(trimmed, '.png');
  }

  static bool _isPng(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i += 1) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }
    return true;
  }
}
