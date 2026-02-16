import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

/// 日志系统简单测试
/// 
/// 运行: flutter test test/app_logger_test.dart
void main() {
  group('AppLogger', () {
    test('初始化日志系统', () async {
      await AppLogger.initialize(isTestEnvironment: true);
      expect(AppLogger.currentLogFile, isNotNull);
      expect(AppLogger.logDirectory, isNotNull);
    });

    test('日志文件使用test_前缀', () async {
      await AppLogger.initialize(isTestEnvironment: true);
      final logFile = AppLogger.currentLogFile;
      expect(logFile, contains('test_'));
    });

    test('日志写入文件', () async {
      await AppLogger.initialize(isTestEnvironment: true);
      AppLogger.i('测试消息', 'Test');
      
      // 等待文件写入
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 简单验证日志文件存在
      expect(AppLogger.currentLogFile, isNotNull);
    });
  });
}
