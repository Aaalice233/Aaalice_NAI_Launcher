// 独立的 NAI 元数据提取脚本 (纯 Dart，不依赖 Flutter)
// 用法: dart run tool/extract_metadata.dart <image_path>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

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
  print('');

  // 首先尝试从 PNG chunks 提取
  print('=== 尝试从 PNG chunks 提取 ===');
  final chunkMetadata = await _extractFromChunks(bytes);
  if (chunkMetadata != null) {
    print('✓ 从 PNG chunks 提取成功!\n');
    _printMetadata(chunkMetadata);
    return;
  }
  print('✗ PNG chunks 中未找到 NAI 元数据\n');

  // 然后尝试从 stealth_pngcomp 提取
  print('=== 尝试从 stealth_pngcomp 提取 ===');
  final stealthMetadata = await _extractFromStealth(bytes);
  if (stealthMetadata != null) {
    print('✓ 从 stealth_pngcomp 提取成功!\n');
    _printMetadata(stealthMetadata);
    return;
  }
  print('✗ 未找到 stealth_pngcomp 元数据\n');

  print('未能提取到 NAI 元数据');
}

void _printMetadata(Map<String, dynamic> metadata) {
  print('=== 完整 JSON ===\n');
  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(metadata));

  print('\n=== 关键字段 ===\n');

  // 提取 comment 数据（NAI 实际存储参数的地方）
  Map<String, dynamic> commentData = {};
  if (metadata.containsKey('Comment') && metadata['Comment'] is String) {
    try {
      commentData = jsonDecode(metadata['Comment'] as String) as Map<String, dynamic>;
      print('从 Comment 字段解析的参数:');
    } catch (e) {
      print('Comment 字段解析失败: $e');
    }
  } else {
    commentData = metadata;
    print('顶层参数:');
  }

  print('');

  // 关键参数
  final keyFields = [
    'prompt',
    'uc',
    'seed',
    'steps',
    'scale',
    'cfg_scale',
    'cfg',
    'guidance',
    'sampler',
    'width',
    'height',
    'model',
    'noise_schedule',
    'cfg_rescale',
    'sm',
    'sm_dyn',
    'version',
  ];

  for (final key in keyFields) {
    final value = commentData[key];
    if (value != null) {
      final valueStr = value is String && value.length > 80
          ? '${value.substring(0, 80)}...'
          : value.toString();
      print('  $key: $valueStr');
    } else {
      // 对于 scale 相关字段，特别标注
      if (['scale', 'cfg_scale', 'cfg', 'guidance'].contains(key)) {
        print('  $key: (null) ❌');
      }
    }
  }

  print('');
  print('=== Scale 检查 ===');
  print('');
  final scaleKeys = ['scale', 'cfg_scale', 'cfg', 'guidance', 'prompt_guidance', 'cfgScale'];
  bool foundScale = false;
  for (final key in scaleKeys) {
    final value = commentData[key];
    if (value != null) {
      print('✓ Found $key: $value');
      foundScale = true;
    }
  }
  if (!foundScale) {
    print('❌ 未找到任何 scale/cfg 相关字段');
    print('   可用字段: ${commentData.keys.toList()}');
  }
}

/// 从 PNG chunks 提取元数据
Future<Map<String, dynamic>?> _extractFromChunks(Uint8List bytes) async {
  try {
    final chunks = png_extract.extractChunks(bytes);
    print('找到 ${chunks.length} 个 PNG chunks');

    for (final chunk in chunks) {
      final name = chunk['name'] as String?;
      if (name == null) continue;

      if (name == 'tEXt' || name == 'zTXt' || name == 'iTXt') {
        final data = chunk['data'] as Uint8List?;
        if (data == null) continue;

        final textData = _parseTextChunk(data, name);
        if (textData != null) {
          print('  $name chunk: ${textData.length} 字符');
          try {
            final json = jsonDecode(textData) as Map<String, dynamic>;
            // 检查是否是 NAI 元数据
            if (json.containsKey('prompt') ||
                json.containsKey('comment') ||
                json.containsKey('Comment')) {
              print('  ✓ 找到 NAI 元数据');
              return json;
            }
          } catch (e) {
            // 不是 JSON，忽略
          }
        }
      }
    }
    return null;
  } catch (e) {
    print('Chunks 提取错误: $e');
    return null;
  }
}

/// 解析 PNG text chunk
String? _parseTextChunk(Uint8List data, String chunkType) {
  try {
    if (chunkType == 'tEXt') {
      final nullIndex = data.indexOf(0);
      if (nullIndex < 0) return null;
      return latin1.decode(data.sublist(nullIndex + 1));
    } else if (chunkType == 'zTXt') {
      final firstNull = data.indexOf(0);
      if (firstNull < 0 || firstNull + 1 >= data.length) return null;
      final compressionMethod = data[firstNull + 1];
      if (compressionMethod != 0) return null;
      final compressedData = data.sublist(firstNull + 2);
      return _inflateZlib(compressedData);
    } else if (chunkType == 'iTXt') {
      return _parseITXtChunk(data);
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// 解析 iTXt chunk
String? _parseITXtChunk(Uint8List data) {
  try {
    var offset = 0;
    final keywordEnd = data.indexOf(0, offset);
    if (keywordEnd < 0) return null;
    offset = keywordEnd + 1;

    if (offset >= data.length) return null;
    final compressed = data[offset++];
    if (offset >= data.length) return null;
    final method = data[offset++];

    final langEnd = data.indexOf(0, offset);
    if (langEnd < 0) return null;
    offset = langEnd + 1;

    final transEnd = data.indexOf(0, offset);
    if (transEnd < 0) return null;
    offset = transEnd + 1;

    if (offset >= data.length) return null;
    final textData = data.sublist(offset);

    if (compressed == 1) {
      if (method != 0) return null;
      return _inflateZlib(textData);
    } else {
      return utf8.decode(textData);
    }
  } catch (e) {
    return null;
  }
}

/// 解压 zlib 数据
String? _inflateZlib(Uint8List data) {
  try {
    final codec = ZLibCodec();
    final inflated = codec.decode(data);
    return utf8.decode(inflated);
  } catch (e) {
    return null;
  }
}

/// 从 stealth_pngcomp 提取元数据
Future<Map<String, dynamic>?> _extractFromStealth(Uint8List bytes) async {
  try {
    final image = img.decodePng(bytes);
    if (image == null) {
      print('错误: 无法解码 PNG 图像');
      return null;
    }

    print('PNG 解码成功: ${image.width}x${image.height}');

    final jsonString = await _extractStealthData(image);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    print('提取到隐写数据: ${jsonString.length} 字符');
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e, stack) {
    print('提取失败: $e');
    return null;
  }
}

Future<String?> _extractStealthData(img.Image image) async {
  final magicBytes = utf8.encode(_magic);
  final List<int> extractedBytes = [];
  int bitIndex = 0;
  int byteValue = 0;

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

  final bitLengthBytes = extractedBytes.sublist(magicLength, magicLength + 4);
  final bitLength =
      ByteData.sublistView(Uint8List.fromList(bitLengthBytes)).getInt32(0);
  final dataLength = (bitLength / 8).ceil();

  print('数据长度: $dataLength 字节 ($bitLength 位)');

  if (magicLength + 4 + dataLength > extractedBytes.length) {
    print('数据长度无效');
    return null;
  }

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
