import 'package:flutter_test/flutter_test.dart';

/// 文件 IO 与图像解码只在真实事件循环里推进，pump 之间放行 runAsync，
/// 最多等待 50 轮，超时即失败而不是挂起。
Future<void> pumpUntilRealAsync(
  WidgetTester tester,
  bool Function() done, {
  String? reason,
}) async {
  for (var attempt = 0; attempt < 50 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: reason);
}
