import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/ink_host.dart';

import '../../../helpers/ink_expectations.dart';

const _surfaceKey = ValueKey('opaque-surface');

void main() {
  testWidgets('不透明表面内的悬停与按压反馈画在底色之上', (tester) async {
    await _pumpSurface(tester, withHost: true);
    final theme = Theme.of(tester.element(find.byType(InkWell)));
    final surface = theme.colorScheme.surfaceContainerHigh;

    await hoverOver(tester, find.byType(InkWell));
    expectInkOnTop(
      tester,
      find.byKey(_surfaceKey),
      ink: theme.hoverColor,
      below: surface,
    );

    final press = await pressAndHold(tester, find.byType(InkWell));
    expectInkOnTop(
      tester,
      find.byKey(_surfaceKey),
      ink: theme.highlightColor,
      below: surface,
    );
    await press.up();
  });

  testWidgets('没有宿主时墨水落在表面底下，不属于表面的绘制', (tester) async {
    await _pumpSurface(tester, withHost: false);
    final theme = Theme.of(tester.element(find.byType(InkWell)));

    await hoverOver(tester, find.byType(InkWell));
    expect(
      tester.renderObject(find.byKey(_surfaceKey)),
      isNot(inkOnTop(ink: theme.hoverColor)),
    );
  });

  testWidgets(
    'Tab 聚焦的焦点高亮画在底色之上',
    (tester) async {
      await _pumpSurface(tester, withHost: true);
      final theme = Theme.of(tester.element(find.byType(InkWell)));

      await tabUntilFocused(tester, find.byType(InkWell));
      expectInkOnTop(
        tester,
        find.byKey(_surfaceKey),
        ink: theme.focusColor,
        below: theme.colorScheme.surfaceContainerHigh,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('外层文字样式原样转交给子树', (tester) async {
    late TextStyle outer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              outer = Theme.of(context).textTheme.titleLarge!;
              return DefaultTextStyle(
                style: outer,
                textAlign: TextAlign.end,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                child: const InkHost(child: Text('inherited')),
              );
            },
          ),
        ),
      ),
    );

    final inherited = DefaultTextStyle.of(
      tester.element(find.text('inherited')),
    );
    expect(inherited.style, outer);
    expect(inherited.textAlign, TextAlign.end);
    expect(inherited.softWrap, isFalse);
    expect(inherited.overflow, TextOverflow.ellipsis);
    expect(inherited.maxLines, 1);
  });
}

Future<void> _pumpSurface(WidgetTester tester, {required bool withHost}) {
  final inkWell = InkWell(
    onTap: () {},
    child: const SizedBox(width: 160, height: 48),
  );
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ColoredBox(
              key: _surfaceKey,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: withHost ? InkHost(child: inkWell) : inkWell,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
