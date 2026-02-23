import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  final dir = Directory('C:\\Users\\Administrator\\Documents\\NAI_Launcher\\images\\test_batch');
  final files = dir.listSync().where((f) => f.path.endsWith('.png')).take(5).toList();

  print('验证生成的测试图像:');
  print('=' * 60);

  for (final file in files) {
    print('文件: ${file.path.split('\\').last}');
    final bytes = File(file.path).readAsBytesSync();
    final image = img.decodePng(bytes);
    print('  尺寸: ${image?.width}x${image?.height}');
    print('  文件大小: ${(bytes.length / 1024).toStringAsFixed(1)} KB');

    // 查找tEXt块
    final metadata = _extractMetadata(bytes);
    if (metadata != null) {
      print('  元数据: 有');
      try {
        final json = jsonDecode(metadata);
        print('  提示词: ${json['prompt']?.toString().substring(0, 80)}...');
        print('  模型: ${json['model']}');
        print('  Seed: ${json['seed']}');
      } catch (e) {
        print('  原始元数据: ${metadata.substring(0, 100)}...');
      }
    } else {
      print('  元数据: 无');
    }
    print('');
  }

  // 统计总文件数
  final allFiles = dir.listSync().where((f) => f.path.endsWith('.png')).toList();
  print('=' * 60);
  print('总文件数: ${allFiles.length}');
}

String? _extractMetadata(Uint8List bytes) {
  var pos = 8;
  while (pos < bytes.length - 12) {
    final len = (bytes[pos] << 24) | (bytes[pos+1] << 16) | (bytes[pos+2] << 8) | bytes[pos+3];
    final type = String.fromCharCodes(bytes.sublist(pos+4, pos+8));

    if (type == 'tEXt') {
      final data = bytes.sublist(pos+8, pos+8+len);
      final nullIdx = data.indexOf(0);
      if (nullIdx > 0) {
        final keyword = String.fromCharCodes(data.sublist(0, nullIdx));
        final text = String.fromCharCodes(data.sublist(nullIdx+1));
        if (keyword == 'parameters') {
          return text;
        }
      }
    }

    if (type == 'IDAT') break;
    pos += 12 + len;
  }
  return null;
}
