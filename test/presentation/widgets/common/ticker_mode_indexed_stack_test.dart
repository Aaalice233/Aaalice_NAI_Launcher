import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/ticker_mode_indexed_stack.dart';

void main() {
  testWidgets('只启用当前子项的 Ticker，切换后保留子项状态并翻转模式', (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, value, _) => TickerModeIndexedStack(
            index: value,
            children: const [
              SizedBox(key: ValueKey('first')),
              SizedBox(key: ValueKey('second')),
            ],
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('first'), skipOffstage: false);
    final second = find.byKey(const ValueKey('second'), skipOffstage: false);
    final firstElement = tester.element(first);
    final secondElement = tester.element(second);
    expect(TickerMode.valuesOf(firstElement).enabled, isTrue);
    expect(TickerMode.valuesOf(secondElement).enabled, isFalse);

    index.value = 1;
    await tester.pump();

    expect(tester.element(first), same(firstElement));
    expect(tester.element(second), same(secondElement));
    expect(TickerMode.valuesOf(firstElement).enabled, isFalse);
    expect(TickerMode.valuesOf(secondElement).enabled, isTrue);
  });
}
