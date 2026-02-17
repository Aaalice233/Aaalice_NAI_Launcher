import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../data/models/gallery/nai_image_metadata.dart';
import 'app_logger.dart';

/// NAI 元数据解析器
///
/// 从 NovelAI 生成的 PNG 图片中提取隐写元数据
/// 使用 stealth_pngcomp 格式：元数据被 gzip 压缩后嵌入 alpha 通道的 LSB
class NaiMetadataParser {
  /// 魔法字节标识
  static const String _magic = 'stealth_pngcomp';

  /// 从 PNG 文件字节提取元数据
  ///
  /// [bytes] PNG 图片的原始字节
  /// 返回解析后的元数据，如果解析失败返回 null
  static Future<NaiImageMetadata?> extractFromBytes(Uint8List bytes) async {
    try {
      // 解码 PNG 图片
      final image = img.decodePng(bytes);
      if (image == null) {
        return null;
      }

      // 提取隐写数据
      final jsonString = await _extractStealthData(image);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      // 解析 JSON
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return NaiImageMetadata.fromNaiComment(json, rawJson: jsonString);
    } catch (e, stack) {
      if (kDebugMode) {
        AppLogger.e(
          'Failed to extract NAI metadata',
          e,
          stack,
          'NaiMetadataParser',
        );
      }
      return null;
    }
  }

  /// 从 Image 对象提取隐写数据
  ///
  /// 实现 stealth_pngcomp 解码算法（优化版）：
  /// 1. 从每个像素的 alpha 通道最低有效位读取数据
  /// 2. 前 15 字节为魔法标识 "stealth_pngcomp"
  /// 3. 接下来 4 字节为数据长度（位数）
  /// 4. 剩余为 gzip 压缩的 JSON 数据
  ///
  /// 优化：使用早期退出策略，一旦读取到足够数据就停止遍历
  static Future<String?> _extractStealthData(img.Image image) async {
    final magicBytes = utf8.encode(_magic);
    final List<int> extractedBytes = [];
    int bitIndex = 0;
    int byteValue = 0;

    // header 字节数 = magic(15) + length(4) = 19
    final headerLength = magicBytes.length + 4;
    int? dataLength; // 实际数据长度，待解析 header 后确定

    // 按列优先顺序读取像素的 alpha 通道 LSB
    outerLoop:
    for (var x = 0; x < image.width; x++) {
      for (var y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        final alpha = pixel.a.toInt();
        final bit = alpha & 1;

        byteValue = (byteValue << 1) | bit;

        if (++bitIndex % 8 == 0) {
          extractedBytes.add(byteValue);
          byteValue = 0;

          // 检查是否已读取完 header
          if (extractedBytes.length == headerLength) {
            // 验证 magic 字节
            final extractedMagic =
                extractedBytes.take(magicBytes.length).toList();
            if (!listEquals(extractedMagic, magicBytes)) {
              // 早期退出：不是 stealth_pngcomp 格式
              return null;
            }

            // 解析数据长度
            final bitLengthBytes = extractedBytes.sublist(
              magicBytes.length,
              magicBytes.length + 4,
            );
            final bitLength = ByteData.sublistView(
              Uint8List.fromList(bitLengthBytes),
            ).getInt32(0);
            dataLength = (bitLength / 8).ceil();

            // 安全检查：数据长度必须合理
            if (dataLength <= 0 || dataLength > 10 * 1024 * 1024) {
              // 数据长度超出合理范围（>10MB）
              return null;
            }
          }

          // 检查是否已读取足够数据（早期退出）
          if (dataLength != null &&
              extractedBytes.length >= headerLength + dataLength) {
            break outerLoop;
          }
        }
      }
    }

    // 验证数据完整性
    if (dataLength == null ||
        extractedBytes.length < headerLength + dataLength) {
      return null;
    }

    // 读取并解压 gzip 数据
    final compressedData = extractedBytes.sublist(
      headerLength,
      headerLength + dataLength,
    );

    try {
      final codec = GZipCodec();
      final decodedData = codec.decode(Uint8List.fromList(compressedData));
      return utf8.decode(decodedData);
    } catch (e) {
      return null;
    }
  }

  /// 在 Isolate 中解析元数据（避免阻塞 UI）
  ///
  /// [data] 包含 'bytes' 键的 Map
  /// 返回解析后的元数据
  static Future<NaiImageMetadata?> parseInIsolate(
    Map<String, dynamic> data,
  ) async {
    try {
      final bytes = data['bytes'] as Uint8List;
      return await extractFromBytes(bytes);
    } catch (e) {
      return null;
    }
  }

  /// 将元数据嵌入 PNG 图片
  ///
  /// [imageBytes] 原始 PNG 图片字节
  /// [metadata] 要嵌入的元数据（JSON 字符串）
  /// 返回嵌入元数据后的新 PNG 字节
  static Future<Uint8List> embedMetadata(
    Uint8List imageBytes,
    String metadataJson,
  ) async {
    final image = img.decodePng(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode PNG image for embedding metadata');
    }

    final codec = GZipCodec();
    final magicBytes = utf8.encode(_magic);
    final encodedData = codec.encode(utf8.encode(metadataJson));
    final bitLength = encodedData.length * 8;

    final bitLengthBytes = ByteData(4);
    bitLengthBytes.setInt32(0, bitLength);

    final dataToEmbed = [
      ...magicBytes,
      ...bitLengthBytes.buffer.asUint8List(),
      ...encodedData,
    ];

    var bitIndex = 0;
    for (var x = 0; x < image.width; x++) {
      for (var y = 0; y < image.height; y++) {
        final byteIndex = bitIndex ~/ 8;
        if (byteIndex >= dataToEmbed.length) break;

        final bit = (dataToEmbed[byteIndex] >> (7 - bitIndex % 8)) & 1;
        final pixel = image.getPixel(x, y);

        // 设置 alpha 通道的 LSB
        final newAlpha = (pixel.a.toInt() & 0xFE) | bit;
        pixel.a = newAlpha;
        image.setPixel(x, y, pixel);

        bitIndex++;
      }
    }

    return img.encodePng(image);
  }
}
