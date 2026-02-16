import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

/// 简单测试示例
///
/// 运行: flutter test test/data_source_test.dart
void main() {
  group('日志功能测试', () {
    test('不同级别的日志', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      AppLogger.d('调试日志');
      AppLogger.i('信息日志');
      AppLogger.w('警告日志');
      AppLogger.e('错误日志');

      // 验证日志文件已创建
      expect(AppLogger.currentLogFile, isNotNull);
    });

    test('网络日志格式', () async {
      await AppLogger.initialize(isTestEnvironment: true);

      AppLogger.network('GET', 'https://api.example.com/test');

      expect(AppLogger.currentLogFile, isNotNull);
    });
  });
}
