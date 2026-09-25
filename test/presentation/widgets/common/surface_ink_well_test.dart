import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';

import '../../../helpers/ink_expectations.dart';

final _surface = find.byType(SurfaceInkWell);

void main() {
  testWidgets('底色在墨水之下，选中描边在墨水之上', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      (colors) => SurfaceInkWell(
        borderRadius: BorderRadius.circular(8),
        color: colors.surfaceContainer,
        side: BorderSide(color: colors.primary),
        onTap: () => taps++,
        child: const SizedBox(width: 120, height: 48),
      ),
    );
    final theme = Theme.of(tester.element(_surface));
    final colors = theme.colorScheme;

    await hoverOver(tester, _surface);
    expectInkOnTop(
      tester,
      _surface,
      ink: theme.hoverColor,
      below: colors.surfaceContainer,
    );
    expect(
      tester.renderObject(_surface),
      paints
        ..something(
          (method, arguments) => isInkCall(method, arguments, theme.hoverColor),
        )
        ..drrect(color: colors.primary),
    );

    final press = await pressAndHold(tester, _surface);
    expectInkOnTop(
      tester,
      _surface,
      ink: theme.highlightColor,
      below: colors.surfaceContainer,
    );
    await press.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets(
    'Tab 聚焦显示焦点高亮',
    (tester) async {
      await _pump(
        tester,
        (colors) => SurfaceInkWell(
          borderRadius: BorderRadius.circular(8),
          color: colors.primaryContainer,
          onTap: () {},
          child: const SizedBox(width: 120, height: 48),
        ),
      );
      final theme = Theme.of(tester.element(_surface));

      await tabUntilFocused(tester, find.byType(InkWell));
      expectInkOnTop(
        tester,
        _surface,
        ink: theme.focusColor,
        below: theme.colorScheme.primaryContainer,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('描边不参与布局，选中切换不改变尺寸', (tester) async {
    final selected = ValueNotifier(false);
    addTearDown(selected.dispose);
    await _pump(
      tester,
      (colors) => ValueListenableBuilder<bool>(
        valueListenable: selected,
        builder: (context, isSelected, _) => SurfaceInkWell(
          borderRadius: BorderRadius.circular(12),
          color: colors.surfaceContainerLow,
          side: isSelected
              ? BorderSide(color: colors.primary, width: 2.5)
              : BorderSide.none,
          onTap: () {},
          child: const SizedBox(width: 96, height: 64),
        ),
      ),
    );

    expect(tester.getSize(_surface), const Size(96, 64));
    selected.value = true;
    await tester.pumpAndSettle();
    expect(tester.getSize(_surface), const Size(96, 64));
  });

  testWidgets('渐变与阴影画在墨水之下', (tester) async {
    await _pump(
      tester,
      (colors) => SurfaceInkWell(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: [colors.primary, colors.tertiary]),
        shadows: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        onTap: () {},
        child: const SizedBox(width: 120, height: 48),
      ),
    );
    final theme = Theme.of(tester.element(_surface));
    final shadow = theme.colorScheme.shadow.withValues(alpha: 0.3);

    await hoverOver(tester, _surface);
    // 测试环境关闭阴影模糊，阴影只能按颜色认出
    expect(
      tester.renderObject(_surface),
      paints
        ..something(
          (method, arguments) =>
              method == #drawRRect &&
              (arguments.last as Paint).color.toARGB32() == shadow.toARGB32(),
        )
        ..something(
          (method, arguments) =>
              method == #drawRRect && (arguments.last as Paint).shader != null,
        )
        ..something(
          (method, arguments) => isInkCall(method, arguments, theme.hoverColor),
        ),
    );
  });

  testWidgets('inkAboveChild 让墨水叠在不透明内容之上，点击仍可达', (tester) async {
    var taps = 0;
    Widget build(ColorScheme colors, {required bool inkAboveChild}) =>
        SurfaceInkWell(
          borderRadius: BorderRadius.circular(8),
          inkAboveChild: inkAboveChild,
          clipBehavior: Clip.antiAlias,
          onTap: () => taps++,
          child: ColoredBox(
            color: colors.surfaceContainerHighest,
            child: const SizedBox(width: 72, height: 72),
          ),
        );

    await _pump(tester, (colors) => build(colors, inkAboveChild: false));
    final theme = Theme.of(tester.element(_surface));
    await hoverOver(tester, _surface);
    expect(
      tester.renderObject(_surface),
      isNot(inkOnTop(ink: theme.hoverColor)),
      reason: '内容盖住墨水层',
    );

    await _pump(tester, (colors) => build(colors, inkAboveChild: true));
    await tester.pumpAndSettle();
    expectInkOnTop(
      tester,
      _surface,
      ink: theme.hoverColor,
      below: theme.colorScheme.surfaceContainerHighest,
    );

    await tester.tap(_surface);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('两种墨水层位置的语义一致：名称来自内容，点击动作可用', (tester) async {
    final handle = tester.ensureSemantics();
    for (final inkAboveChild in const [false, true]) {
      await _pump(
        tester,
        (colors) => Semantics(
          container: true,
          child: SurfaceInkWell(
            borderRadius: BorderRadius.circular(8),
            color: colors.surfaceContainer,
            inkAboveChild: inkAboveChild,
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('tile name'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(_surface),
        isSemantics(label: 'tile name', hasTapAction: true),
        reason: 'inkAboveChild: $inkAboveChild',
      );
    }
    handle.dispose();
  });

  testWidgets('颜色按给定时长过渡，Reduce Motion 下立即到位', (tester) async {
    final selected = ValueNotifier(false);
    addTearDown(selected.dispose);
    late ColorScheme colors;
    Widget tile() => ValueListenableBuilder<bool>(
      valueListenable: selected,
      builder: (context, isSelected, _) => SurfaceInkWell(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? colors.primary : colors.surfaceContainer,
        duration: const Duration(milliseconds: 200),
        onTap: () {},
        child: const SizedBox(width: 48, height: 48),
      ),
    );

    await _pump(tester, (scheme) {
      colors = scheme;
      return tile();
    });
    selected.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = _backgroundColor(tester);
    expect(midway, isNot(colors.surfaceContainer));
    expect(midway, isNot(colors.primary));
    await tester.pumpAndSettle();
    expect(_backgroundColor(tester), colors.primary);

    selected.value = false;
    await _pump(tester, (_) => tile(), disableAnimations: true);
    await tester.pump();
    expect(_backgroundColor(tester), colors.surfaceContainer);
  });

  testWidgets('禁用时没有悬停墨水，点击不触发', (tester) async {
    await _pump(
      tester,
      (colors) => SurfaceInkWell(
        borderRadius: BorderRadius.circular(8),
        color: colors.surfaceContainer,
        onTap: null,
        child: const SizedBox(width: 120, height: 48),
      ),
    );
    final theme = Theme.of(tester.element(_surface));

    await hoverOver(tester, _surface);
    expect(
      tester.renderObject(_surface),
      isNot(inkOnTop(ink: theme.hoverColor)),
    );
    await tester.tap(_surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hoverColor 可交给自绘悬停：透明时不叠加默认悬停色', (tester) async {
    await _pump(
      tester,
      (colors) => SurfaceInkWell(
        borderRadius: BorderRadius.circular(8),
        color: colors.surfaceContainer,
        hoverColor: Colors.transparent,
        onTap: () {},
        child: const SizedBox(width: 120, height: 48),
      ),
    );
    final theme = Theme.of(tester.element(_surface));

    await hoverOver(tester, _surface);
    expect(
      tester.renderObject(_surface),
      isNot(inkOnTop(ink: theme.hoverColor)),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function(ColorScheme colors) build, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => build(Theme.of(context).colorScheme),
          ),
        ),
      ),
    ),
  );
}

Color? _backgroundColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: _surface,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.background,
          ),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}
