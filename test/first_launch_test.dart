import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

/// 首次启动流程验证
/// 
/// 验证点：
/// 1. 日志系统初始化
/// 2. 日志文件创建（test_前缀）
/// 3. 日志目录结构
/// 
/// 运行：flutter test test/first_launch_test.dart
void main() {
  group('首次启动流程验证', () {
    
    setUpAll(() async {
      // 测试开始前初始化日志
      await AppLogger.initialize(isTestEnvironment: true);
    });

    test('1. 日志系统成功初始化', () async {
      // 验证日志文件已创建
      expect(AppLogger.currentLogFile, isNotNull);
      expect(AppLogger.logDirectory, isNotNull);
      
      // 验证文件存在
      final logFile = File(AppLogger.currentLogFile!);
      expect(await logFile.exists(), isTrue);
      
      AppLogger.i('✅ 日志系统初始化验证通过', 'FirstLaunch');
    });

    test('2. 日志文件使用正确前缀', () async {
      final logFile = AppLogger.currentLogFile;
      final fileName = logFile!.split(Platform.pathSeparator).last;
      
      // 验证测试环境使用 test_ 前缀
      expect(fileName, startsWith('test_'));
      expect(fileName, endsWith('.log'));
      expect(fileName.length, greaterThan(20));
      
      AppLogger.i('✅ 日志文件前缀验证通过: $fileName', 'FirstLaunch');
    });

    test('3. 日志目录结构正确', () async {
      final logDir = AppLogger.logDirectory;
      expect(logDir, isNotNull);
      
      // 验证目录存在
      final dir = Directory(logDir!);
      expect(await dir.exists(), isTrue);
      
      AppLogger.i('✅ 日志目录验证通过: $logDir', 'FirstLaunch');
    });

    test('4. 日志内容正确写入', () async {
      // 写入测试日志
      AppLogger.i('首次启动测试日志', 'FirstLaunch');
      AppLogger.d('调试信息');
      AppLogger.w('警告信息');
      
      // 等待写入
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证文件非空
      final logFile = File(AppLogger.currentLogFile!);
      final content = await logFile.readAsString();
      
      expect(content.length, greaterThan(0));
      expect(content, contains('首次启动测试日志'));
      expect(content, contains('[FirstLaunch]'));
      
      AppLogger.i('✅ 日志内容写入验证通过', 'FirstLaunch');
    });

    test('5. 获取日志文件列表', () async {
      final files = await AppLogger.getLogFiles();
      
      // 验证返回列表
      expect(files, isList);
      expect(files.length, greaterThanOrEqualTo(1));
      
      AppLogger.i('✅ 日志文件列表获取成功: ${files.length} 个文件', 'FirstLaunch');
    });

    test('6. 验证首次启动关键日志', () async {
      // 模拟首次启动的关键日志记录
      AppLogger.i('应用启动', 'Main');
      AppLogger.i('日志系统初始化完成', 'AppLogger');
      AppLogger.i('初始化数据库', 'Warmup');
      AppLogger.i('初始化共现数据', 'Warmup');
      AppLogger.i('Danbooru标签数据加载', 'Warmup');
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 验证日志文件
      final logFile = File(AppLogger.currentLogFile!);
      final content = await logFile.readAsString();
      
      // 验证包含关键日志
      expect(content, contains('应用启动'));
      expect(content, contains('日志系统初始化完成'));
      expect(content, contains('[Main]'));
      expect(content, contains('[Warmup]'));
      
      AppLogger.i('✅ 首次启动关键日志验证通过', 'FirstLaunch');
    });
  });
}
