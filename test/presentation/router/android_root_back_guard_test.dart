import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/router/android_root_back_guard.dart';

void main() {
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  int exitCallCount() => platformCalls
      .where((call) => call.method == 'SystemNavigator.pop')
      .length;

  testWidgets('首次返回提示且同一批重复回调不会退出', (tester) async {
    var hintCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidRootBackGuard(
          enabled: true,
          resetKey: 0,
          onExitHint: () => hintCount++,
          child: const Scaffold(body: Text('首页')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();

    expect(find.text('首页'), findsOneWidget);
    expect(hintCount, 1);
    expect(exitCallCount(), 0);
  });

  testWidgets('重新构建后第二次独立返回才退出', (tester) async {
    var hintCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidRootBackGuard(
          enabled: true,
          resetKey: 0,
          onExitHint: () => hintCount++,
          child: const Scaffold(body: Text('首页')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exitCallCount(), 0);

    await tester.binding.handlePopRoute();

    expect(hintCount, 1);
    expect(exitCallCount(), 1);
  });

  testWidgets('超时后恢复为首次返回', (tester) async {
    var hintCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidRootBackGuard(
          enabled: true,
          resetKey: 0,
          exitWindow: const Duration(seconds: 2),
          onExitHint: () => hintCount++,
          child: const Scaffold(body: Text('首页')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.handlePopRoute();

    expect(hintCount, 2);
    expect(exitCallCount(), 0);
  });

  testWidgets('切换模块或进入内部返回状态会重置保护', (tester) async {
    final resetKey = ValueNotifier<int>(0);
    final enabled = ValueNotifier<bool>(true);
    var hintCount = 0;
    addTearDown(resetKey.dispose);
    addTearDown(enabled.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: resetKey,
          builder: (context, key, _) => ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, isEnabled, _) => AndroidRootBackGuard(
              enabled: isEnabled,
              resetKey: key,
              onExitHint: () => hintCount++,
              child: const Scaffold(body: Text('首页')),
            ),
          ),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    resetKey.value = 1;
    await tester.pump();
    await tester.binding.handlePopRoute();
    expect(hintCount, 2);
    expect(exitCallCount(), 0);
    await tester.pump();

    enabled.value = false;
    await tester.pump();
    enabled.value = true;
    await tester.pump();
    await tester.binding.handlePopRoute();

    expect(hintCount, 3);
    expect(exitCallCount(), 0);
  });

  testWidgets('非根页面正常返回且不触发退出提示', (tester) async {
    var hintCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AndroidRootBackGuard(
          enabled: true,
          resetKey: 0,
          onExitHint: () => hintCount++,
          child: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('详情')),
                  ),
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('详情'), findsNothing);
    expect(find.text('打开详情'), findsOneWidget);
    expect(hintCount, 0);
    expect(exitCallCount(), 0);
  });
}
