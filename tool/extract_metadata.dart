// 独立的 NAI 元数据提取脚本 (纯 Dart，不依赖 Flutter)
// 用法: dart run tool/extract_metadata.dart <image_path>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const String _magic = 'stealth_pngcomp';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('用法: dart run tool/extract_metadata.dart <image_path>');
    exit(1);
  }

  final imagePath = args[0];
  final file = File(imagePath);
  
  if (!file.existsSync()) {
    print('错误: 文件不存在 - $imagePath');
    exit(1);
  }

  print('正在读取图像: $imagePath');
  final bytes = await file.readAsBytes();
  print('图像大小: ${bytes.length} 字节');

  final metadata = await extractMetadata(bytes);
  
  if (metadata == null) {
    print('\n未找到 NAI 隐写元数据');
    exit(0);
  }

  print('\n=== NAI 官网元数据完整 JSON ===\n');
  
  // 格式化输出 JSON
  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(metadata));
  
  print('\n=== 字段列表 ===\n');
  metadata.forEach((key, value) {
    final valueStr = value is String && value.length > 100 
        ? '${value.substring(0, 100)}...' 
        : value.toString();
    print('  $key: $valueStr');
  });
}

Future<Map<String, dynamic>?> extractMetadata(Uint8List bytes) async {
  try {
    final image = img.decodePng(bytes);
    if (image == null) {
      print('错误: 无法解码 PNG 图像');
      return null;
    }
    
    print('PNG 解码成功: ${image.width}x${image.height}');

    final jsonString = await _extractStealthData(image);
    if (jsonString == null || jsonString.isEmpty) {
      print('未找到隐写数据');
      return null;
    }
    
    print('提取到隐写数据: ${jsonString.length} 字符');
    
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e, stack) {
    print('提取元数据失败: $e');
    print(stack);
    return null;
  }
}

Future<String?> _extractStealthData(img.Image image) async {
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
  bool magicMatch = true;
  for (int i = 0; i < magicLength; i++) {
    if (extractedMagic[i] != magicBytes[i]) {
      magicMatch = false;
      break;
    }
  }
  
  if (!magicMatch) {
    print('不是 stealth_pngcomp 格式');
    return null;
  }
  
  print('检测到 stealth_pngcomp 格式');

  // 读取数据长度（位数）
  final bitLengthBytes = extractedBytes.sublist(magicLength, magicLength + 4);
  final bitLength = ByteData.sublistView(Uint8List.fromList(bitLengthBytes)).getInt32(0);
  final dataLength = (bitLength / 8).ceil();

  print('数据长度: $dataLength 字节 ($bitLength 位)');

  // 检查数据长度是否有效
  if (magicLength + 4 + dataLength > extractedBytes.length) {
    print('数据长度无效');
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
    print('解压失败: $e');
    return null;
  }
}
