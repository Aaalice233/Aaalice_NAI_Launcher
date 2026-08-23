import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';

void main() {
  testWidgets('桌面 Toast 的图标、文本和关闭按钮垂直居中', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => AppToast.success(context, '已加入队列'),
                child: const Text('显示 Toast'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示 Toast'));
    await tester.pump(const Duration(milliseconds: 301));

    final messageCenter = tester.getCenter(find.text('已加入队列'));
    final statusIconCenter = tester.getCenter(
      find.byIcon(Icons.check_circle_rounded),
    );
    final closeIconCenter = tester.getCenter(find.byIcon(Icons.close));

    expect(messageCenter.dy, closeTo(statusIconCenter.dy, 0.5));
    expect(messageCenter.dy, closeTo(closeIconCenter.dy, 0.5));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
    expect(tester.takeException(), isNull);
  });
}
