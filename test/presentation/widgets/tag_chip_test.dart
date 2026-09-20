import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/tag_chip.dart';

/// SimpleTagChip 的上下文菜单在上游只有 onSecondaryTapUp（右键），
/// 触屏上没有右键，这里锁住长按这条等价入口。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpChip(
    WidgetTester tester, {
    void Function(TapUpDetails details)? onSecondaryTapUp,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SimpleTagChip(
                tag: 'long_hair',
                autoTranslate: false,
                onTap: onTap,
                onSecondaryTapUp: onSecondaryTapUp,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('长按标签复用右键的上下文菜单回调', (tester) async {
    TapUpDetails? received;
    await pumpChip(tester, onSecondaryTapUp: (details) => received = details);

    await tester.longPress(find.text('long hair'));
    await tester.pump();

    expect(received, isNotNull);
    expect(received!.kind, PointerDeviceKind.touch);
  });

  testWidgets('接上长按后普通点击仍然生效', (tester) async {
    var tapped = 0;
    var menuOpened = 0;
    await pumpChip(
      tester,
      onTap: () => tapped++,
      onSecondaryTapUp: (_) => menuOpened++,
    );

    await tester.tap(find.text('long hair'));
    await tester.pump();

    expect(tapped, 1);
    expect(menuOpened, 0);
  });
}
