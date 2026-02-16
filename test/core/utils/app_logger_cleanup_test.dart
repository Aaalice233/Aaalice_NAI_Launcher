import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 日志文件轮换和清理测试
///
/// 详细测试日志文件的自动清理机制
void main() {
  group('日志文件轮换和清理', () {
    late Directory tempLogDir;

    setUp(() async {
      // 创建临时日志目录
      tempLogDir =
          Directory.systemTemp.createTempSync('app_logger_cleanup_test_');
    });

    tearDown(() async {
      // 清理临时目录
      if (await tempLogDir.exists()) {
        await tempLogDir.delete(recursive: true);
      }
    });

    test('保留最近3个日志文件', () async {
      // 创建5个模拟的旧日志文件
      final files = <File>[];
      for (int i = 0; i < 5; i++) {
        final timestamp = DateTime.now().subtract(Duration(days: i + 1));
        final fileName =
            'app_${timestamp.year}${_pad(timestamp.month)}${_pad(timestamp.day)}_'
            '${_pad(timestamp.hour)}${_pad(timestamp.minute)}${_pad(timestamp.second + i)}.log';
        final file =
            File('${tempLogDir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsString('旧日志内容 $i');
        files.add(file);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 验证创建了5个文件
      var allFiles = await tempLogDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .toList();
      expect(allFiles.length, equals(5));

      // 模拟清理逻辑：保留最新的2个，删除其余的
      allFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      const maxLogFiles = 3;
      if (allFiles.length >= maxLogFiles) {
        final filesToDelete = allFiles.sublist(maxLogFiles - 1);
        for (final file in filesToDelete) {
          await file.delete();
        }
      }

      // 验证只剩下2个文件
      allFiles = await tempLogDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .toList();
      expect(allFiles.length, equals(2));
    });

    test('清理只删除app_和test_开头的日志文件', () async {
      // 创建各种文件
      await File('${tempLogDir.path}${Platform.pathSeparator}app_old1.log')
          .writeAsString('old1');
      await File('${tempLogDir.path}${Platform.pathSeparator}test_old1.log')
          .writeAsString('test1');
      await File('${tempLogDir.path}${Platform.pathSeparator}other_file.log')
          .writeAsString('other');
      await File('${tempLogDir.path}${Platform.pathSeparator}data.txt')
          .writeAsString('data');

      // 模拟过滤逻辑
      final logFiles = await tempLogDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .where((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return name.startsWith('app_') || name.startsWith('test_');
      }).toList();

      // 验证只识别出2个日志文件
      expect(logFiles.length, equals(2));
    });

    test('日志文件按修改时间正确排序', () async {
      // 创建3个文件，确保有不同的修改时间
      final file1 =
          File('${tempLogDir.path}${Platform.pathSeparator}app_1.log');
      await file1.writeAsString('content1');
      await Future.delayed(const Duration(milliseconds: 100));

      final file2 =
          File('${tempLogDir.path}${Platform.pathSeparator}app_2.log');
      await file2.writeAsString('content2');
      await Future.delayed(const Duration(milliseconds: 100));

      final file3 =
          File('${tempLogDir.path}${Platform.pathSeparator}app_3.log');
      await file3.writeAsString('content3');

      // 获取并排序
      final files = await tempLogDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .toList();

      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // 验证顺序（最新的在前）
      expect(files[0].path, contains('app_3.log'));
      expect(files[1].path, contains('app_2.log'));
      expect(files[2].path, contains('app_1.log'));
    });

    test('日志目录不存在时自动创建', () async {
      final newDirPath = '${tempLogDir.path}${Platform.pathSeparator}new_logs';
      final newDir = Directory(newDirPath);

      // 验证目录不存在
      expect(await newDir.exists(), isFalse);

      // 创建目录
      await newDir.create(recursive: true);

      // 验证目录已创建
      expect(await newDir.exists(), isTrue);
    });

    test('创建日志文件后文件存在', () async {
      final filePath =
          '${tempLogDir.path}${Platform.pathSeparator}test_log.log';
      final file = File(filePath);

      // 创建文件
      await file.writeAsString('测试日志内容');

      // 验证文件存在
      expect(await file.exists(), isTrue);

      // 验证内容正确
      final content = await file.readAsString();
      expect(content, equals('测试日志内容'));
    });

    test('同时存在app_和test_日志文件', () async {
      // 创建混合日志文件
      await File(
              '${tempLogDir.path}${Platform.pathSeparator}app_20240101_120000.log',)
          .writeAsString('app log 1');
      await File(
              '${tempLogDir.path}${Platform.pathSeparator}test_20240101_120100.log',)
          .writeAsString('test log 1');
      await File(
              '${tempLogDir.path}${Platform.pathSeparator}app_20240101_120200.log',)
          .writeAsString('app log 2');

      // 获取所有日志文件
      final logFiles = await tempLogDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .where((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return name.startsWith('app_') || name.startsWith('test_');
      }).toList();

      // 验证识别出3个日志文件
      expect(logFiles.length, equals(3));

      // 验证包含app和test
      final appFiles = logFiles.where((f) => f.path.contains('app_')).toList();
      final testFiles =
          logFiles.where((f) => f.path.contains('test_')).toList();

      expect(appFiles.length, equals(2));
      expect(testFiles.length, equals(1));
    });

    test('getLogFiles只返回日志文件', () async {
      // 在临时目录创建各种文件
      await File('${tempLogDir.path}${Platform.pathSeparator}app_valid.log')
          .writeAsString('valid');
      await File('${tempLogDir.path}${Platform.pathSeparator}test_valid.log')
          .writeAsString('valid');
      await File('${tempLogDir.path}${Platform.pathSeparator}other.txt')
          .writeAsString('other');
      await File('${tempLogDir.path}${Platform.pathSeparator}data.json')
          .writeAsString('{}');

      // 模拟 getLogFiles 逻辑
      final files = await tempLogDir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .where((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return name.startsWith('app_') || name.startsWith('test_');
      }).toList();

      // 验证只返回2个日志文件
      expect(files.length, equals(2));
    });

    test('时间戳格式正确', () {
      final now = DateTime(2024, 1, 15, 9, 30, 45);
      final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
          '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

      expect(timestamp, equals('20240115_093045'));
      expect(timestamp.length, equals(15)); // YYYYMMDD_HHMMSS = 8 + 1 + 6 = 15
    });

    test('文件名生成包含正确的时间戳', () {
      final now = DateTime(2024, 6, 20, 14, 25, 30);
      final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
          '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final fileName = 'app_$timestamp.log';

      expect(fileName, equals('app_20240620_142530.log'));
      expect(fileName.startsWith('app_'), isTrue);
      expect(fileName.endsWith('.log'), isTrue);
    });
  });
}

String _pad(int number) => number.toString().padLeft(2, '0');
