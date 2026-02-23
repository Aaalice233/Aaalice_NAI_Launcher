import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 生成大量带NAI元数据的测试图像用于性能测试
/// 每张图都有唯一的：颜色、尺寸、提示词元数据，确保哈希值不同
void main(List<String> args) async {
  final count = args.isNotEmpty ? int.tryParse(args[0]) ?? 5000 : 5000;

  // 获取图片存储路径
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final basePath = '$home\\Documents\\NAI_Launcher\\images';
  final testDir = Directory('$basePath\\test_batch');

  // 清空旧数据（如果失败则使用新目录）
  if (await testDir.exists()) {
    print('清空旧测试数据...');
    try {
      await testDir.delete(recursive: true);
    } catch (e) {
      print('警告: 无法清空旧目录，将直接生成到新目录');
    }
  }
  if (!await testDir.exists()) {
    await testDir.create(recursive: true);
  }

  print('生成 $count 张带NAI元数据的测试图像');
  print('输出目录: ${testDir.path}');
  print('每张图像包含: 唯一颜色 + 唯一尺寸 + 唯一提示词元数据');
  print('');

  final stopwatch = Stopwatch()..start();

  // 分批次处理避免内存问题
  const batchSize = 50;
  final batches = (count / batchSize).ceil();

  for (var batch = 0; batch < batches; batch++) {
    final start = batch * batchSize;
    final end = (start + batchSize) < count ? start + batchSize : count;

    await Future.wait(
      List.generate(end - start, (i) {
        final index = start + i;
        return _generateImage(
          index: index,
          total: count,
          directory: testDir,
        );
      }),
    );

    final progress = (end / count * 100).toStringAsFixed(1);
    print('进度: $progress% ($end/$count)');
  }

  stopwatch.stop();

  print('');
  print('========================================');
  print('完成!');
  print('总计: $count 张图像');
  print('耗时: ${stopwatch.elapsed}');
  print('平均: ${(stopwatch.elapsed.inMilliseconds / count).toStringAsFixed(1)}ms/张');
  print('存储位置: ${testDir.path}');
  print('========================================');
}

Future<void> _generateImage({
  required int index,
  required int total,
  required Directory directory,
}) async {
  // 使用索引作为种子确保可重复但唯一
  final random = Random(index * 1234567);

  // 文件名
  final fileName = 'test_${index.toString().padLeft(5, '0')}.png';
  final filePath = '${directory.path}\\$fileName';

  // 尺寸变化: 512-1024，每张不同
  final width = 512 + random.nextInt(513);
  final height = 512 + random.nextInt(513);

  // 基础色调基于索引
  final baseHue = (index / total * 360).toDouble();

  // 创建图像
  final image = img.Image(width: width, height: height);

  // 生成渐变背景
  for (var y = 0; y < height; y++) {
    final progressY = y / height;
    for (var x = 0; x < width; x++) {
      final progressX = x / width;
      final h = (baseHue + progressY * 30 + progressX * 20) % 360;
      final s = 0.5 + random.nextDouble() * 0.5;
      final l = 0.3 + progressY * 0.4;

      final rgb = _hslToRgb(h, s, l);
      image.setPixel(x, y, img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
    }
  }

  // 添加随机圆形图案
  final shapeCount = 3 + random.nextInt(5);
  for (var s = 0; s < shapeCount; s++) {
    final cx = random.nextInt(width);
    final cy = random.nextInt(height);
    final radius = 20 + random.nextInt(80);
    final shapeHue = (baseHue + 180 + random.nextInt(60)) % 360;
    final rgb = _hslToRgb(shapeHue, 0.8, 0.6);

    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        final x = cx + dx;
        final y = cy + dy;
        if (x >= 0 && x < width && y >= 0 && y < height) {
          if (dx * dx + dy * dy <= radius * radius) {
            image.setPixel(x, y, img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
          }
        }
      }
    }
  }

  // 添加文字标识
  img.drawString(
    image,
    'TEST-$index',
    font: img.arial24,
    x: 10,
    y: 10,
    color: img.ColorRgb8(255, 255, 255),
  );

  // 生成随机提示词元数据
  final metadata = _generateRandomMetadata(index, width, height, random);

  // 编码PNG并嵌入元数据
  final pngBytes = _encodePngWithMetadata(image, metadata);

  // 保存
  await File(filePath).writeAsBytes(pngBytes);
}

List<int> _hslToRgb(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;

  double r, g, b;

  if (h < 60) {
    r = c; g = x; b = 0;
  } else if (h < 120) {
    r = x; g = c; b = 0;
  } else if (h < 180) {
    r = 0; g = c; b = x;
  } else if (h < 240) {
    r = 0; g = x; b = c;
  } else if (h < 300) {
    r = x; g = 0; b = c;
  } else {
    r = c; g = 0; b = x;
  }

  return [
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((b + m) * 255).round(),
  ];
}

String _generateRandomMetadata(int index, int width, int height, Random random) {
  // 大量提示词变体确保唯一性
  final subjects = [
    '1girl', '1boy', '2girls', '2boys', '1girl, 1boy',
    'landscape', 'cityscape', 'portrait', 'full body',
    'chibi', 'anime style character', 'furry', 'mecha',
    'dragon', 'cat', 'dog', 'wolf', 'fox', 'bird',
    'magic', 'sci-fi', 'fantasy', 'horror', 'comedy',
  ];

  final qualities = [
    'masterpiece', 'best quality', 'highly detailed', 'ultra detailed',
    'intricate details', 'professional', 'award winning',
  ];

  final styles = [
    'anime style', 'manga style', 'digital art', 'watercolor',
    'oil painting', 'sketch', 'line art', 'pixel art',
    '3d render', 'photorealistic', 'cartoon', 'minimalist',
  ];

  final backgrounds = [
    'detailed background', 'simple background', 'white background',
    'outdoor', 'indoor', 'nature', 'city', 'space',
    'school', 'home', 'forest', 'beach', 'mountain',
  ];

  final colors = [
    'vibrant colors', 'pastel colors', 'monochrome', 'colorful',
    'dark', 'bright', 'warm colors', 'cool colors',
  ];

  final samplers = ['k_euler', 'k_euler_a', 'k_dpmpp_2m', 'k_dpmpp_sde', 'ddim', 'k_dpm_2'];
  final models = ['nai-diffusion-3', 'nai-diffusion-4', 'nai-diffusion-4-full'];

  // 随机组合提示词
  final promptParts = <String>[
    qualities[random.nextInt(qualities.length)],
    qualities[random.nextInt(qualities.length)],
    subjects[random.nextInt(subjects.length)],
    styles[random.nextInt(styles.length)],
    backgrounds[random.nextInt(backgrounds.length)],
    colors[random.nextInt(colors.length)],
  ];

  // 添加随机额外标签
  final extraTags = random.nextInt(10) + 5;
  for (var i = 0; i < extraTags; i++) {
    final tagPool = [...subjects, ...styles, ...backgrounds, ...colors];
    promptParts.add(tagPool[random.nextInt(tagPool.length)]);
  }

  // 确保唯一性
  final prompt = '${promptParts.join(", ")}, unique_id_$index, seed_${random.nextInt(100000)}';

  final negativePrompts = [
    'low quality', 'bad anatomy', 'worst quality', 'blurry',
    'jpeg artifacts', 'signature', 'watermark', 'username',
    'error', 'missing fingers', 'extra digit', 'fewer digits',
    'cropped', 'normal quality', 'mutation', 'deformed',
  ];

  // 随机选择负面提示词
  final selectedNegative = <String>[];
  final negativeCount = 5 + random.nextInt(5);
  for (var i = 0; i < negativeCount; i++) {
    selectedNegative.add(negativePrompts[random.nextInt(negativePrompts.length)]);
  }

  final metadata = {
    'prompt': prompt,
    'negative_prompt': selectedNegative.join(', '),
    'seed': random.nextInt(1000000000),
    'sampler': samplers[random.nextInt(samplers.length)],
    'steps': 20 + random.nextInt(20),
    'cfg_scale': 5.0 + random.nextDouble() * 10,
    'width': width,
    'height': height,
    'model': models[random.nextInt(models.length)],
    'comment': 'Test image $index generated for performance testing',
    'software': 'NAI Launcher Test Generator',
  };

  return jsonEncode(metadata);
}

Uint8List _encodePngWithMetadata(img.Image image, String metadata) {
  final basePng = img.encodePng(image);
  final textChunk = _createTextChunk('parameters', metadata);
  return _insertTextChunk(basePng, textChunk);
}

Uint8List _createTextChunk(String keyword, String text) {
  final keywordBytes = utf8.encode(keyword);
  final textBytes = utf8.encode(text);

  final data = Uint8List(keywordBytes.length + 1 + textBytes.length);
  data.setAll(0, keywordBytes);
  data[keywordBytes.length] = 0;
  data.setAll(keywordBytes.length + 1, textBytes);

  final typeAndData = Uint8List(4 + data.length);
  typeAndData.setAll(0, 'tEXt'.codeUnits);
  typeAndData.setAll(4, data);

  final crc = _calculateCrc(typeAndData);

  final chunk = BytesBuilder();
  chunk.add(_uint32ToBytes(data.length));
  chunk.add(typeAndData);
  chunk.add(_uint32ToBytes(crc));

  return chunk.toBytes();
}

Uint8List _insertTextChunk(Uint8List png, Uint8List textChunk) {
  final result = BytesBuilder();
  result.add(png.sublist(0, 8));

  var pos = 8;
  while (pos < png.length - 12) {
    final length = _bytesToUint32(png.sublist(pos, pos + 4));
    final type = String.fromCharCodes(png.sublist(pos + 4, pos + 8));

    result.add(png.sublist(pos, pos + 12 + length));
    pos += 12 + length;

    if (type == 'IHDR') {
      result.add(textChunk);
      break;
    }
  }

  result.add(png.sublist(pos));
  return result.toBytes();
}

Uint8List _uint32ToBytes(int value) {
  return Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;
}

int _bytesToUint32(Uint8List bytes) {
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}

int _calculateCrc(Uint8List data) {
  final table = List<int>.generate(256, (i) {
    var c = i;
    for (var j = 0; j < 8; j++) {
      c = (c & 1) == 1 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    return c;
  });

  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = table[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
