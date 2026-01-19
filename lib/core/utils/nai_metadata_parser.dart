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
      AppLogger.d('Extracting metadata from ${bytes.length} bytes', 'NaiMetadataParser');
      
      // 解码 PNG 图片
      final image = img.decodePng(bytes);
      if (image == null) {
        AppLogger.w('Failed to decode PNG image', 'NaiMetadataParser');
        return null;
      }
      
      AppLogger.d('PNG decoded: ${image.width}x${image.height}', 'NaiMetadataParser');

      // 提取隐写数据
      final jsonString = await _extractStealthData(image);
      if (jsonString == null || jsonString.isEmpty) {
        AppLogger.d('No stealth data found in image', 'NaiMetadataParser');
        return null;
      }
      
      AppLogger.d('Stealth data extracted: ${jsonString.length} chars', 'NaiMetadataParser');

      // 解析 JSON
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final metadata = NaiImageMetadata.fromNaiComment(json, rawJson: jsonString);
      AppLogger.d('Metadata parsed: prompt=${metadata.prompt.length} chars, seed=${metadata.seed}', 'NaiMetadataParser');
      return metadata;
    } catch (e, stack) {
      if (kDebugMode) {
        AppLogger.e('Failed to extract NAI metadata', e, stack, 'NaiMetadataParser');
      }
      return null;
    }
  }

  /// 从 Image 对象提取隐写数据
  ///
  /// 实现 stealth_pngcomp 解码算法：
  /// 1. 从每个像素的 alpha 通道最低有效位读取数据
  /// 2. 前 15 字节为魔法标识 "stealth_pngcomp"
  /// 3. 接下来 4 字节为数据长度（位数）
  /// 4. 剩余为 gzip 压缩的 JSON 数据
  static Future<String?> _extractStealthData(img.Image image) async {
    final magicBytes = utf8.encode(_magic);
    final List<int> extractedBytes = [];
    int bitIndex = 0;
    int byteValue = 0;

    // 按列优先顺序读取所有像素的 alpha 通道 LSB
    for (var x = 0; x < image.width; x++) {
      for (var y = 0; y < image.height; y++) {
        final pixel = image.getPixel(x, y);
        final alpha = pixel.a.toInt();
        final bit = alpha & 1;

        byteValue = (byteValue << 1) | bit;

        if (++bitIndex % 8 == 0) {
          extractedBytes.add(byteValue);
          byteValue = 0;
        }
      }
    }

    // 检查魔法字节
    final magicLength = magicBytes.length;
    if (extractedBytes.length < magicLength + 4) {
      return null;
    }

    final extractedMagic = extractedBytes.take(magicLength).toList();
    if (!listEquals(extractedMagic, magicBytes)) {
      // 不是 stealth_pngcomp 格式
      return null;
    }

    // 读取数据长度（位数）
    final bitLengthBytes = extractedBytes.sublist(magicLength, magicLength + 4);
    final bitLength = ByteData.sublistView(Uint8List.fromList(bitLengthBytes)).getInt32(0);
    final dataLength = (bitLength / 8).ceil();

    // 检查数据长度是否有效
    if (magicLength + 4 + dataLength > extractedBytes.length) {
      AppLogger.w(
        'Invalid stealth data length: $dataLength (available: ${extractedBytes.length - magicLength - 4})',
        'NaiMetadataParser',
      );
      return null;
    }

    // 读取并解压 gzip 数据
    final compressedData = extractedBytes.sublist(
      magicLength + 4,
      magicLength + 4 + dataLength,
    );

    try {
      final codec = GZipCodec();
      final decodedData = codec.decode(Uint8List.fromList(compressedData));
      return utf8.decode(decodedData);
    } catch (e) {
      AppLogger.w('Failed to decompress stealth data: $e', 'NaiMetadataParser');
      return null;
    }
  }

  /// 在 Isolate 中解析元数据（避免阻塞 UI）
  ///
  /// [data] 包含 'bytes' 键的 Map
  /// 返回解析后的元数据
  static Future<NaiImageMetadata?> parseInIsolate(Map<String, dynamic> data) async {
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
