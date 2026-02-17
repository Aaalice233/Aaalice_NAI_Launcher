import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// 文件哈希工具类
class FileHashUtils {
  /// 计算文件的 SHA256 哈希（流式，适合大文件）
  static Future<String> calculateFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final hash = await sha256.bind(file.openRead()).first;
    return base64Encode(hash.bytes);
  }

  /// 计算 Asset 文件的 SHA256 哈希
  static Future<String> calculateAssetHash(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final buffer = bytes.buffer.asUint8List();
    final hash = sha256.convert(buffer);
    return base64Encode(hash.bytes);
  }

  /// 计算字符串的 SHA256 哈希
  static String calculateStringHash(String content) {
    final bytes = utf8.encode(content);
    final hash = sha256.convert(bytes);
    return base64Encode(hash.bytes);
  }
}
