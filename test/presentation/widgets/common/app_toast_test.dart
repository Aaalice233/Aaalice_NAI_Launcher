import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';

void main() {
  testWidgets('移动端 Toast 显示在顶部且不使用底部 SnackBar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  FilledButton(
                    onPressed: () => AppToast.info(context, '已保存服务商'),
                    child: const Text('显示 Toast'),
                  ),
                  const Spacer(),
                  const SizedBox(
                    key: ValueKey('generate-button'),
                    width: 180,
                    height: 56,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示 Toast'));
    await tester.pump(const Duration(milliseconds: 301));

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getTopLeft(find.text('已保存服务商')).dy, lessThan(100));
    expect(
      tester.getBottomLeft(find.text('已保存服务商')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('generate-button'))).dy,
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
    expect(tester.takeException(), isNull);
  });

  testWidgets('长文本 Toast 在 3x 字号下按实际高度堆叠', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                AppToast.info(context, '第一条很长的全局提示消息需要完整换行显示');
                AppToast.warning(context, '第二条提示不能和第一条提示重叠');
              },
              child: const Text('显示多个 Toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示多个 Toast'));
    await tester.pump(const Duration(milliseconds: 301));

    final first = find.text('第一条很长的全局提示消息需要完整换行显示');
    final second = find.text('第二条提示不能和第一条提示重叠');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getBottomLeft(first).dy),
    );
    for (final button in tester.widgetList<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close),
    )) {
      expect(button.style?.minimumSize?.resolve({})?.height, 48);
    }
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
  });

  testWidgets('进度 Toast 更新语义并只允许一次终态转换', (tester) async {
    final semantics = tester.ensureSemantics();
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final controller = AppToast.showProgress(hostContext, 'Downloading file');
    controller.updateProgress(0.5, subtitle: '5 / 10');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();

    final progressSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Downloading file. 5 / 10',
      ),
    );
    expect(progressSemantics.properties.liveRegion, isTrue);
    expect(progressSemantics.properties.value, '50%');
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    controller.complete(message: 'Download complete');
    controller.fail(message: 'Late failure must be ignored');
    controller.updateProgress(0.2, message: 'Late progress must be ignored');
    await tester.pump();
    expect(find.text('Download complete'), findsOneWidget);
    expect(find.text('Late failure must be ignored'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 301));
    expect(find.text('Download complete'), findsNothing);
    semantics.dispose();
  });

  testWidgets('旧进度控制器不能关闭替换后的 Toast', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    final oldController = AppToast.showProgress(hostContext, 'Old task');
    await tester.pump();
    final currentController = AppToast.showProgress(
      hostContext,
      'Current task',
    );
    await tester.pump();

    oldController.dismiss();
    await tester.pump(const Duration(milliseconds: 301));
    expect(find.text('Current task'), findsOneWidget);

    currentController.dismiss();
    await tester.pumpAndSettle();
    expect(find.text('Current task'), findsNothing);
  });

  testWidgets('Reduce Motion 下 Toast 与进度 Toast 入场直接处于终态', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Scaffold(
              body: FilledButton(
                onPressed: () => AppToast.info(context, 'Instant toast'),
                child: const Text('Show'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    final progress = AppToast.showProgress(hostContext, 'Instant progress');
    await tester.pump();

    expect(
      tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .map((transition) => transition.position.value),
      everyElement(Offset.zero),
    );
    expect(
      tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((transition) => transition.opacity.value),
      everyElement(1.0),
    );

    progress.dismiss();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  for (final brightness in Brightness.values) {
    testWidgets('Toast 状态颜色不被红色品牌覆盖且满足 AA $brightness', (tester) async {
      final scheme =
          ColorScheme.fromSeed(
            seedColor: const Color(0xFFB00020),
            brightness: brightness,
          ).copyWith(
            primaryContainer: const Color(0xFF4A1018),
            onPrimaryContainer: const Color(0xFFFFFFFF),
            errorContainer: const Color(0xFF4A1018),
            onErrorContainer: const Color(0xFFFFFFFF),
            tertiaryContainer: const Color(0xFF4A1018),
            onTertiaryContainer: const Color(0xFFFFFFFF),
            secondaryContainer: const Color(0xFF4A1018),
            onSecondaryContainer: const Color(0xFFFFFFFF),
          );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  AppToast.success(context, 'Success semantic toast');
                  AppToast.error(context, 'Error semantic toast');
                  AppToast.warning(context, 'Warning semantic toast');
                  AppToast.info(context, 'Info semantic toast');
                },
                child: const Text('Show semantic toasts'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show semantic toasts'));
      await tester.pump(const Duration(milliseconds: 301));

      final expectedHues = <String, (double, double)>{
        'Success semantic toast': (100, 160),
        'Warning semantic toast': (35, 60),
        'Info semantic toast': (190, 230),
        'Error semantic toast': (330, 360),
      };
      for (final entry in expectedHues.entries) {
        final text = tester.widget<Text>(find.text(entry.key));
        final surface = tester.widget<Container>(
          find
              .ancestor(
                of: find.text(entry.key),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                ),
              )
              .first,
        );
        final background = (surface.decoration! as BoxDecoration).color!;
        final foreground = text.style!.color!;
        expect(
          HSVColor.fromColor(background).hue,
          inInclusiveRange(entry.value.$1, entry.value.$2),
        );
        if (entry.key.startsWith('Error')) {
          expect(background, scheme.errorContainer);
          expect(foreground, scheme.onErrorContainer);
        }
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
        );
      }

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 301));
    });
  }

  testWidgets('Windows 触屏策略使用触控命中区并居中显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => AppToast.info(context, 'Windows touch'),
                child: const Text('Show Windows touch'),
              ),
            ),
          ),
        ),
      ),
    );

    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Show Windows touch'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));

    final closeButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    expect(closeButton.style?.minimumSize?.resolve({}), const Size.square(48));
    final surface = find
        .ancestor(
          of: find.text('Windows touch'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;
    expect(tester.getCenter(surface).dx, closeTo(400, 1));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
  });

  testWidgets('Android 鼠标策略使用精确指针命中区、hover 与右侧位置', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => AppToast.info(context, 'Android mouse'),
                child: const Text('Show Android mouse'),
              ),
            ),
          ),
        ),
      ),
    );

    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Show Android mouse'),
        )
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 301));

    final closeButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    expect(closeButton.style?.minimumSize?.resolve({}), const Size.square(40));
    final surface = find
        .ancestor(
          of: find.text('Android mouse'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;
    expect(tester.getTopRight(surface).dx, closeTo(784, 1));
    expect(
      tester
          .widgetList<MouseRegion>(find.byType(MouseRegion))
          .any((region) => region.onEnter != null && region.onExit != null),
      isTrue,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Android mouse'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 301));
    expect(find.text('Android mouse'), findsNothing);
    await mouse.removePointer();
  });

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
    expect(messageCenter.dx, greaterThan(500));
    expect(messageCenter.dy, lessThan(100));
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

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = foreground == lighter ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
