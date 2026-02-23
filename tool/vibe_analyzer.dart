import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Vibe 文件分析工具
/// 支持解析 PNG、.naiv4vibe、.naiv4vibebundle 文件
///
/// 使用方法:
///   dart run vibe_analyzer.dart <文件路径>
///
/// 示例:
///   dart run vibe_analyzer.dart "E:\\Download\\test.png"
///   dart run vibe_analyzer.dart "E:\\Download\\test.naiv4vibe"
///   dart run vibe_analyzer.dart "E:\\Download\\test.naiv4vibebundle"

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run vibe_analyzer.dart <file_path>');
    print('');
    print('Supported formats:');
    print('  - PNG files with NAI vibe metadata');
    print('  - .naiv4vibe single vibe files');
    print('  - .naiv4vibebundle multi-vibe files');
    exit(1);
  }

  final filePath = args[0];

  print('=' * 60);
  print('Vibe Analyzer');
  print('=' * 60);
  print('File: $filePath');
  print('');

  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ File not found: $filePath');
      exit(1);
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last;
    final extension = fileName.split('.').last.toLowerCase();

    print('File size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');
    print('Extension: .$extension');
    print('');

    // 根据文件类型选择解析方法
    if (extension == 'png' || _isPngFile(bytes)) {
      await analyzePngFile(bytes);
    } else if (extension == 'naiv4vibe') {
      await analyzeNaiv4VibeFile(bytes);
    } else if (extension == 'naiv4vibebundle') {
      await analyzeNaiv4VibeBundleFile(bytes);
    } else {
      print('❌ Unknown file format');
      print('Attempting to detect format...');
      if (_isPngFile(bytes)) {
        print('Detected as PNG');
        await analyzePngFile(bytes);
      } else {
        try {
          final jsonStr = utf8.decode(bytes);
          final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
          final identifier = jsonData['identifier'] as String?;
          if (identifier?.contains('bundle') ?? false) {
            print('Detected as naiv4vibebundle');
            await analyzeNaiv4VibeBundleFile(bytes);
          } else {
            print('Detected as naiv4vibe');
            await analyzeNaiv4VibeFile(bytes);
          }
        } catch (e) {
          print('❌ Unable to detect file format: $e');
        }
      }
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    if (args.contains('--verbose')) {
      print(stackTrace);
    }
  }

  print('');
  print('=' * 60);
  print('Analysis complete');
  print('=' * 60);
}

bool _isPngFile(Uint8List bytes) {
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < pngSignature.length) return false;
  for (var i = 0; i < pngSignature.length; i++) {
    if (bytes[i] != pngSignature[i]) return false;
  }
  return true;
}

Future<void> analyzePngFile(Uint8List bytes) async {
  print('-' * 60);
  print('PNG File Analysis');
  print('-' * 60);

  final chunks = parsePngChunks(bytes);
  print('Total chunks: ${chunks.length}');

  // 查找 iTXt chunks
  var itxtCount = 0;
  for (final chunk in chunks) {
    if (chunk['type'] == 'iTXt') {
      itxtCount++;
      print('');
      print('iTXt Chunk #$itxtCount:');

      final data = chunk['data'] as Uint8List;
      final result = parseITxtChunk(data);

      if (result != null) {
        print('  Keyword: ${result['keyword']}');

        if (result['keyword'] == 'naidata') {
          final naiData = result['data'];
          if (naiData is Map<String, dynamic>) {
            printNaiData(naiData, indent: '  ');
          }
        } else if (result['keyword'] == 'NovelAI_Vibe_Encoding_Base64') {
          final data = result['data'] as String;
          print('  Base64 length: ${data.length} chars');
        } else {
          final dataStr = result['data'].toString();
          print(
            '  Data: ${dataStr.substring(0, dataStr.length > 100 ? 100 : dataStr.length)}...',
          );
        }
      }
    }
  }

  if (itxtCount == 0) {
    print('⚠️  No iTXt chunks found');
  }
}

Future<void> analyzeNaiv4VibeFile(Uint8List bytes) async {
  print('-' * 60);
  print('.naiv4vibe File Analysis');
  print('-' * 60);

  try {
    final jsonStr = utf8.decode(bytes);
    final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;

    print('Identifier: ${jsonData['identifier']}');
    print('Version: ${jsonData['version']}');
    print('Name: ${jsonData['name']}');
    print('Type: ${jsonData['type']}');
    print('Has thumbnail: ${jsonData['thumbnail'] != null}');
    print('Has image: ${jsonData['image'] != null}');

    if (jsonData['thumbnail'] != null) {
      final thumb = jsonData['thumbnail'] as String;
      print('Thumbnail length: ${thumb.length} chars');
      print('Thumbnail format: ${_detectDataFormat(thumb)}');

      // 尝试提取并保存缩略图
      final base64Data = extractBase64FromDataUri(thumb);
      if (base64Data != null) {
        try {
          final thumbBytes = base64Decode(base64Data);
          print('Thumbnail decoded: ${thumbBytes.length} bytes');
          await saveDebugFile('thumbnail_naiv4vibe.jpg', thumbBytes);
        } catch (e) {
          print('❌ Failed to decode thumbnail: $e');
        }
      }
    }

    if (jsonData['image'] != null) {
      final img = jsonData['image'] as String;
      print('Image length: ${img.length} chars');
      print('Image format: ${_detectDataFormat(img)}');
    }

    // 检查 encodings
    final encodings = jsonData['encodings'] as Map<String, dynamic>?;
    if (encodings != null) {
      print('Encodings models: ${encodings.keys.toList()}');
    }

    // 检查 importInfo
    final importInfo = jsonData['importInfo'] as Map<String, dynamic>?;
    if (importInfo != null) {
      print('Import info: ${importInfo.keys.toList()}');
    }
  } catch (e) {
    print('❌ Failed to parse .naiv4vibe file: $e');
  }
}

Future<void> analyzeNaiv4VibeBundleFile(Uint8List bytes) async {
  print('-' * 60);
  print('.naiv4vibebundle File Analysis');
  print('-' * 60);

  try {
    final jsonStr = utf8.decode(bytes);
    final bundleData = jsonDecode(jsonStr) as Map<String, dynamic>;

    print('Identifier: ${bundleData['identifier']}');
    print('Version: ${bundleData['version']}');

    final vibes = bundleData['vibes'] as List<dynamic>?;
    if (vibes == null || vibes.isEmpty) {
      print('❌ No vibes found in bundle');
      return;
    }

    print('Number of vibes: ${vibes.length}');
    print('');

    for (var i = 0; i < vibes.length; i++) {
      final vibe = vibes[i] as Map<String, dynamic>;
      print('Vibe #$i:');
      print('  Name: ${vibe['name']}');
      print('  Type: ${vibe['type']}');
      print('  Has thumbnail: ${vibe['thumbnail'] != null}');
      print('  Has image: ${vibe['image'] != null}');

      if (vibe['thumbnail'] != null) {
        final thumb = vibe['thumbnail'] as String;
        print('  Thumbnail length: ${thumb.length} chars');
        print('  Thumbnail format: ${_detectDataFormat(thumb)}');

        // 尝试提取并保存缩略图
        final base64Data = extractBase64FromDataUri(thumb);
        if (base64Data != null) {
          try {
            final thumbBytes = base64Decode(base64Data);
            print('  Thumbnail decoded: ${thumbBytes.length} bytes');
            await saveDebugFile('thumbnail_bundle_$i.jpg', thumbBytes);
          } catch (e) {
            print('  ❌ Failed to decode thumbnail: $e');
          }
        }
      }

      if (vibe['image'] != null) {
        final img = vibe['image'] as String;
        print('  Image length: ${img.length} chars');
        print('  Image format: ${_detectDataFormat(img)}');
      }

      // 检查 encodings
      final encodings = vibe['encodings'] as Map<String, dynamic>?;
      if (encodings != null) {
        print('  Encodings models: ${encodings.keys.toList()}');
      }

      print('');
    }
  } catch (e) {
    print('❌ Failed to parse .naiv4vibebundle file: $e');
  }
}

String _detectDataFormat(String data) {
  if (data.startsWith('data:')) {
    final commaIndex = data.indexOf(',');
    if (commaIndex > 0) {
      return data.substring(0, commaIndex);
    }
  }
  return 'Raw data (no Data URI prefix)';
}

Future<void> saveDebugFile(String fileName, Uint8List bytes) async {
  try {
    final tempDir = Directory(r'E:\Aaalice_NAI_Launcher\tool\debug_output');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final file = File('${tempDir.path}\$fileName');
    await file.writeAsBytes(bytes);
    print('  💾 Saved to: ${file.path}');
  } catch (e) {
    print('  ⚠️  Failed to save file: $e');
  }
}

// PNG 解析函数
List<Map<String, dynamic>> parsePngChunks(Uint8List bytes) {
  final chunks = <Map<String, dynamic>>[];
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  for (var i = 0; i < pngSignature.length; i++) {
    if (bytes[i] != pngSignature[i]) {
      throw Exception('Invalid PNG signature');
    }
  }

  var offset = pngSignature.length;

  while (offset + 12 <= bytes.length) {
    final dataLength = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];

    final typeBytes = bytes.sublist(offset + 4, offset + 8);
    final type = ascii.decode(typeBytes);

    final data = bytes.sublist(offset + 8, offset + 8 + dataLength);

    chunks.add({
      'type': type,
      'data': data,
      'length': dataLength,
    });

    if (type == 'IEND') break;
    offset += 12 + dataLength;
  }

  return chunks;
}

Map<String, dynamic>? parseITxtChunk(Uint8List data) {
  try {
    var offset = 0;
    while (offset < data.length && data[offset] != 0) {
      offset++;
    }
    if (offset >= data.length) return null;

    final keyword = utf8.decode(data.sublist(0, offset));
    offset++;

    if (offset >= data.length) return null;
    final compressionFlag = data[offset];
    offset += 2;

    for (var i = 0; i < 2; i++) {
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      if (offset >= data.length) return null;
      offset++;
    }

    final textBytes = data.sublist(offset);
    final text = compressionFlag == 1
        ? utf8.decode(const ZLibDecoder().decodeBytes(textBytes))
        : utf8.decode(textBytes);

    if (keyword == 'naidata') {
      final decoded = base64Decode(text);
      final jsonData = jsonDecode(utf8.decode(decoded));
      return {'keyword': keyword, 'data': jsonData};
    } else {
      return {'keyword': keyword, 'data': text};
    }
  } catch (e) {
    print('Error parsing iTXt: $e');
    return null;
  }
}

String? extractBase64FromDataUri(String dataUri) {
  if (dataUri.startsWith('data:')) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex != -1 && commaIndex < dataUri.length - 1) {
      return dataUri.substring(commaIndex + 1);
    }
  }
  return dataUri;
}

void printNaiData(Map<String, dynamic> naiData, {String indent = ''}) {
  final identifier = naiData['identifier'] as String?;
  print('${indent}Identifier: $identifier');
  print('${indent}Version: ${naiData['version']}');

  if (identifier == 'novelai-vibe-transfer-bundle') {
    final vibes = naiData['vibes'] as List<dynamic>?;
    print('${indent}Bundle vibes count: ${vibes?.length ?? 0}');

    if (vibes != null) {
      for (var i = 0; i < vibes.length; i++) {
        final vibe = vibes[i] as Map<String, dynamic>;
        print('$indent  Vibe #$i:');
        print('$indent    Name: ${vibe['name']}');
        print('$indent    Type: ${vibe['type']}');
        print('$indent    Has thumbnail: ${vibe['thumbnail'] != null}');
        print('$indent    Has image: ${vibe['image'] != null}');

        if (vibe['thumbnail'] != null) {
          final thumb = vibe['thumbnail'] as String;
          print('$indent    Thumbnail length: ${thumb.length} chars');
        }

        final encodings = vibe['encodings'] as Map<String, dynamic>?;
        if (encodings != null) {
          print('$indent    Encodings: ${encodings.keys.toList()}');
        }
      }
    }
  } else if (identifier == 'novelai-vibe-transfer') {
    print('${indent}Single vibe:');
    print('$indent  Name: ${naiData['name']}');
    print('$indent  Type: ${naiData['type']}');
    print('$indent  Has thumbnail: ${naiData['thumbnail'] != null}');
    print('$indent  Has image: ${naiData['image'] != null}');
  }
}
