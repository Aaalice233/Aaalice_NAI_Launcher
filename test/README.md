# Flutter 官方测试

简洁的 Flutter 官方测试框架。

## 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试
flutter test test/app_logger_test.dart
flutter test test/app_test.dart
flutter test test/data_source_test.dart
```

## 添加新测试

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('测试描述', () {
    expect(actual, expected);
  });
}
```

或 Widget 测试：

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('测试描述', (tester) async {
    await tester.pumpWidget(MyWidget());
    expect(find.text('Hello'), findsOneWidget);
  });
}
```
