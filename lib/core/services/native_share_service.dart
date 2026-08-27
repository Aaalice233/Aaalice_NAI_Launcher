import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../utils/media_mime_type.dart';

/// Shares in-memory images through the operating system share sheet.
class NativeShareService {
  NativeShareService._();

  static Future<ShareResult> shareImage({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    Rect? sharePositionOrigin,
  }) {
    final resolvedMimeType =
        mimeType ??
        mediaMimeTypeForExtension(p.extension(fileName), fallback: 'image/*');
    return Share.shareXFiles([
      XFile.fromData(bytes, mimeType: resolvedMimeType, name: fileName),
    ], sharePositionOrigin: sharePositionOrigin);
  }
}
