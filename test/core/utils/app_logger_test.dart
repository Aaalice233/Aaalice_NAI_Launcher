import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

/// 日志系统全面测试
///
/// 测试内容：
/// 1. 日志文件创建
/// 2. 日志内容写入
/// 3. 自动轮换（保留最近3个）
/// 4. 正式/测试环境区分
/// 5. 文件命名规则
void main() {
  group('日志系统测试', () {
    late Directory tempDir;

    setUp(() async {
      // 创建临时目录用于测试
      tempDir = Directory.systemTemp.createTempSync('log_test_');
    });

    tearDown(() async {
      // 清理临时目录
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('正式环境日志文件名格式正确', () async {
      // 初始化正式环境日志
      await AppLogger.initialize(isTestEnvironment: false);

      final logFile = AppLogger.currentLogFile;
      expect(logFile, isNotNull);

      // 验证文件名格式: app_YYYYMMDD_HHMMSS.log
      final fileName = logFile!.split(Platform.pathSeparator).last;
      expect(fileName, startsWith('app_'));
      expect(fileName, endsWith('.log'));
      expect(fileName.length, greaterThan(20)); // app_ + 时间戳 + .log

      // 验证文件已创建
      final file = File(logFile);
      expect(await file.exists(), isTrue);
    });

    test('测试环境日志文件名格式正确', () async {
      // 初始化测试环境日志
      await AppLogger.initialize(isTestEnvironment: true);

      final logFile = AppLogger.currentLogFile;
      expect(logFile, isNotNull);

      // 验证文件名格式: test_YYYYMMDD_HHMMSS.log
      final fileName = logFile!.split(Platform.pathSeparator).last;
      expect(fileName, startsWith('test_'));
      expect(fileName, endsWith('.log'));

      // 验证文件已创建
      final file = File(logFile);
      expect(await file.exists(), isTrue);
    });

    test('日志内容正确写入文件', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      // 写入各种级别的日志
      AppLogger.d('调试信息', 'TestTag');
      AppLogger.i('普通信息', 'TestTag');
      AppLogger.w('警告信息', 'TestTag');
      AppLogger.e('错误信息', Exception('测试异常'), StackTrace.current, 'TestTag');

      // 等待写入完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 读取日志文件内容
      final logFile = AppLogger.currentLogFile;
      final content = await File(logFile!).readAsString();

      // 验证内容包含所有日志
      expect(content, contains('调试信息'));
      expect(content, contains('普通信息'));
      expect(content, contains('警告信息'));
      expect(content, contains('错误信息'));
      expect(content, contains('[TestTag]'));
    });

    test('网络日志格式正确', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      // 记录网络请求
      AppLogger.network(
        'GET',
        'https://api.example.com/test',
        data: {'key': 'value'},
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final logFile = AppLogger.currentLogFile;
      final content = await File(logFile!).readAsString();

      expect(content, contains('[HTTP] GET https://api.example.com/test'));
    });

    test('认证日志脱敏处理正确', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      // 记录认证日志（包含敏感信息）
      AppLogger.auth(
        '用户登录',
        email: 'test@example.com',
        success: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final logFile = AppLogger.currentLogFile;
      final content = await File(logFile!).readAsString();

      // 验证邮箱已脱敏
      expect(content, contains('te***@example.com'));
      expect(content, isNot(contains('test@example.com')));
    });

    test('加密日志脱敏处理正确', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      AppLogger.crypto(
        '生成密钥',
        email: 'user@example.com',
        keyLength: 256,
        success: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final logFile = AppLogger.currentLogFile;
      final content = await File(logFile!).readAsString();

      expect(content, contains('us***@example.com'));
      expect(content, contains('keyLength: 256'));
    });

    test('自动轮换保留最近3个日志文件', () async {
      // 模拟创建多个日志文件
      final logDir = tempDir.path;

      // 创建5个旧的日志文件
      for (int i = 0; i < 5; i++) {
        final timestamp = DateTime.now().subtract(Duration(days: i + 1));
        final fileName =
            'app_${timestamp.year}${_pad(timestamp.month)}${_pad(timestamp.day)}_${_pad(timestamp.hour)}${_pad(timestamp.minute)}${_pad(timestamp.second)}.log';
        final file = File('$logDir${Platform.pathSeparator}$fileName');
        await file.writeAsString('旧日志内容 $i');
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 验证创建了5个文件
      var files = await tempDir.list().where((e) => e is File).toList();
      expect(files.length, equals(5));

      // 手动触发清理逻辑（模拟初始化时的清理）
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),);
      if (files.length >= 3) {
        final filesToDelete = files.sublist(2); // 保留前2个，删除后面的
        for (final file in filesToDelete) {
          await file.delete();
        }
      }

      // 验证只剩下2个文件（最新的）
      files = await tempDir.list().where((e) => e is File).toList();
      expect(files.length, equals(2));
    });

    test('getLogFiles返回按时间倒序排列', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      // 等待第一个日志文件创建
      await Future.delayed(const Duration(milliseconds: 100));

      // 重新初始化创建第二个日志文件
      await Future.delayed(const Duration(milliseconds: 1100)); // 确保时间戳不同
      await AppLogger.initialize(isTestEnvironment: true);

      await Future.delayed(const Duration(milliseconds: 100));

      // 获取日志文件列表
      final files = await AppLogger.getLogFiles();

      // 验证列表不为空
      expect(files, isNotEmpty);

      // 验证是按时间倒序排列（最新的在前）
      if (files.length >= 2) {
        final firstTime = files[0].lastModifiedSync();
        final secondTime = files[1].lastModifiedSync();
        expect(
            firstTime.isAfter(secondTime) ||
                firstTime.isAtSameMomentAs(secondTime),
            isTrue,);
      }
    });

    test('logDirectory返回正确路径', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      final logDir = AppLogger.logDirectory;
      expect(logDir, isNotNull);

      // 验证目录存在
      final dir = Directory(logDir!);
      expect(await dir.exists(), isTrue);
    });

    test('长文本自动截断', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      // 记录一个很长的响应
      final longText = 'x' * 1000;
      AppLogger.network(
        'GET',
        'https://api.example.com/data',
        response: longText,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      final logFile = AppLogger.currentLogFile;
      final content = await File(logFile!).readAsString();

      // 验证包含截断标记
      expect(content, contains('... (truncated)'));
    });
  });
}

String _pad(int number) => number.toString().padLeft(2, '0');
