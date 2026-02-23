import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 生成测试图像用于性能测试
/// 每张图都是唯一的（不同颜色、不同尺寸变化），避免缓存命中问题
void main(List<String> args) async {
  final count = args.isNotEmpty ? int.tryParse(args[0]) ?? 5000 : 5000;

  // 获取图片存储路径
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final basePath = '$home\\Documents\\NAI_Launcher\\images';
  final testDir = Directory('$basePath\\test_batch');

  if (!await testDir.exists()) {
    await testDir.create(recursive: true);
  }

  print('生成 $count 张测试图像到: ${testDir.path}');
  print('开始生成...');

  final random = Random();
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < count; i++) {
    // 生成唯一文件名（包含序号确保唯一）
    final fileName = 'test_${i.toString().padLeft(5, '0')}_${random.nextInt(99999)}.png';
    final filePath = '${testDir.path}\\$fileName';

    // 每张图略有不同：尺寸在 512-1024 之间变化
    final width = 512 + random.nextInt(512);
    final height = 512 + random.nextInt(512);

    // 生成随机渐变色
    final image = img.Image(width: width, height: height);
    final baseR = random.nextInt(256);
    final baseG = random.nextInt(256);
    final baseB = random.nextInt(256);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // 简单的渐变效果，确保每张图不同
        final r = ((baseR + x * 0.5 + i) % 256).toInt();
        final g = ((baseG + y * 0.3 + i * 2) % 256).toInt();
        final b = ((baseB + (x + y) * 0.2) % 256).toInt();
        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    // 添加一些文字标识确保唯一性
    img.drawString(
      image,
      'TEST-$i',
      font: img.arial24,
      x: 10,
      y: 10,
      color: img.ColorRgb8(255, 255, 255),
    );

    // 保存
    final encoded = img.encodePng(image);
    await File(filePath).writeAsBytes(encoded);

    // 进度报告
    if ((i + 1) % 100 == 0) {
      final progress = ((i + 1) / count * 100).toStringAsFixed(1);
      print('进度: $progress% (${i + 1}/$count)');
    }
  }

  stopwatch.stop();
  print('\n完成！');
  print('生成 $count 张图像，耗时: ${stopwatch.elapsed}');
  print('存储位置: ${testDir.path}');
}
