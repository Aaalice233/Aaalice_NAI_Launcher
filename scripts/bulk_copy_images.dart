import 'dart:io';
import 'dart:math';

/// 快速复制现有图像来模拟大量图片
/// 每张图都有唯一文件名，避免缓存冲突
void main(List<String> args) async {
  final count = args.isNotEmpty ? int.tryParse(args[0]) ?? 5000 : 5000;

  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final basePath = '$home\\Documents\\NAI_Launcher\\images';
  final sourceDir = Directory(basePath);
  final testDir = Directory('$basePath\\test_bulk_${count}');

  if (!await sourceDir.exists()) {
    print('错误: 源目录不存在: $basePath');
    print('请确保已经生成过至少一张图片');
    exit(1);
  }

  // 查找源图片
  final sourceFiles = sourceDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList();

  if (sourceFiles.isEmpty) {
    print('错误: 没有找到 PNG 图片作为源文件');
    print('请先在应用中生成至少一张图片');
    exit(1);
  }

  print('找到 ${sourceFiles.length} 张源图片');
  print('目标: 生成 $count 张测试图片');
  print('存储位置: ${testDir.path}');

  if (!await testDir.exists()) {
    await testDir.create(recursive: true);
  }

  final random = Random();
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < count; i++) {
    // 轮询使用源图片
    final sourceFile = sourceFiles[i % sourceFiles.length];

    // 生成唯一文件名（包含序号、随机数、时间戳）
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = random.nextInt(999999);
    final fileName = 'bulk_${i.toString().padLeft(5, '0')}_${timestamp}_$randomId.png';
    final destPath = '${testDir.path}\\$fileName';

    // 复制文件
    await sourceFile.copy(destPath);

    // 修改文件的修改时间，让它分散在不同时间（测试时间排序）
    final modifiedTime = DateTime.now().subtract(
      Duration(minutes: random.nextInt(10000)),
    );
    await File(destPath).setLastModified(modifiedTime);

    // 进度报告
    if ((i + 1) % 500 == 0) {
      final progress = ((i + 1) / count * 100).toStringAsFixed(1);
      print('进度: $progress% (${i + 1}/$count)');
    }
  }

  stopwatch.stop();
  print('\n✅ 完成！');
  print('生成 $count 张图像，耗时: ${stopwatch.elapsed}');
  print('存储位置: ${testDir.path}');
  print('\n现在重启应用，进入本地画廊即可测试性能');
}
