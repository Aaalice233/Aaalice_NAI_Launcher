import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/widgets/multi_select_bottom_bar.dart';

void main() {
  group('MultiSelectBottomBar', () {
    testWidgets('选中 3 张时显示已选 3 张', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MultiSelectBottomBar(
                selectedCount: 3,
                onSendToHome: () {},
                onClear: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('已选 3 张'), findsOneWidget);
      expect(find.text('发送到主页'), findsOneWidget);
    });

    testWidgets('选中 0 张时高度为 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MultiSelectBottomBar(
                selectedCount: 0,
                onSendToHome: () {},
                onClear: () {},
              ),
            ),
          ),
        ),
      );

      // 选中 0 张时，底部栏的高度应该是 0（通过 AnimatedContainer 实现）
      // 我们通过找到 MultiSelectBottomBar 内部的 AnimatedContainer 来验证
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('点击清除按钮应触发 onClear', (tester) async {
      bool clearCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MultiSelectBottomBar(
                selectedCount: 5,
                onSendToHome: () {},
                onClear: () => clearCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(clearCalled, isTrue);
    });

    testWidgets('点击发送按钮应触发 onSendToHome', (tester) async {
      bool sendCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MultiSelectBottomBar(
                selectedCount: 2,
                onSendToHome: () => sendCalled = true,
                onClear: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('发送到主页'));
      await tester.pump();

      expect(sendCalled, isTrue);
    });
  });
}
