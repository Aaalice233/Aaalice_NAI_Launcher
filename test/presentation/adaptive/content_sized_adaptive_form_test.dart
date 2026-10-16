import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_pinned_header_sliver.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/content_sized_adaptive_form.dart';

import '../../helpers/adaptive_panel_expectations.dart';

void main() {
  testWidgets('托管标题时标题栏与底部操作按同一条实测规则一起固定或一起随正文滚动，可用高度增减时只在阈值处切换', (
    tester,
  ) async {
    const headerHeight = 56.0;
    const footerHeight = 72.0;
    final header = find.byKey(const ValueKey('header'), skipOffstage: false);
    final footer = find.byKey(const ValueKey('footer'), skipOffstage: false);
    const threshold =
        headerHeight +
        footerHeight +
        AdaptivePinnedHeaderSliver.minContentExtent;

    Future<void> pumpAt(double height, {Key? formKey}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400, maxHeight: height),
              child: AdaptivePanelHeaderScope(
                header: const SizedBox(
                  key: ValueKey('header'),
                  height: headerHeight,
                ),
                child: ContentSizedAdaptiveForm(
                  key: formKey,
                  scrollController: null,
                  content: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 40, child: Text('Field $i')),
                  ],
                  footer: const SizedBox(
                    key: ValueKey('footer'),
                    height: footerHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 逐帧收放可用高度模拟软键盘动画，再在阈值两侧重新打开表单
    final heights = [
      for (var height = 200.0; height <= 480; height += 4) height,
      for (var height = 480.0; height >= 200; height -= 4) height,
    ];
    for (final (height, fresh) in [
      for (final height in heights) (height, false),
      for (final height in [threshold - 1, threshold]) (height, true),
    ]) {
      await pumpAt(height, formKey: fresh ? UniqueKey() : null);
      final reason = 'height=$height fresh=$fresh';
      final headerPinned = pinnedHeaderSliverOf(tester, header).isPinned;
      final footerFixed = find
          .ancestor(of: footer, matching: find.byType(Scrollable))
          .evaluate()
          .isEmpty;
      expect(footerFixed, headerPinned, reason: reason);
      expect(headerPinned, height >= threshold, reason: reason);
      expect(tester.takeException(), isNull, reason: reason);
    }
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      for (final fixedFooter in [false, true]) {
        testWidgets(
          '$width / ${scale}x / footer=$fixedFooter resizes with content',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 1000);
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            addTearDown(tester.view.reset);
            final count = ValueNotifier(1);
            addTearDown(count.dispose);
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => AdaptivePresenter.showForm<void>(
                        context: context,
                        title: 'Form',
                        builder: (context, controller) =>
                            ValueListenableBuilder<int>(
                              valueListenable: count,
                              builder: (context, value, _) {
                                final action = TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Done'),
                                );
                                return ContentSizedAdaptiveForm(
                                  scrollController: controller,
                                  content: [
                                    for (var i = 0; i < value; i++)
                                      Text('Field $i'),
                                    if (!fixedFooter) action,
                                  ],
                                  footer: fixedFooter ? action : null,
                                );
                              },
                            ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            final surface = find.byKey(
              ValueKey(
                width < 600
                    ? 'adaptive-bottom-sheet'
                    : 'adaptive-centered-form',
              ),
            );
            final shortHeight = tester.getSize(surface).height;
            expect(shortHeight, lessThan(500));
            expect(find.byType(Scrollable), findsOneWidget);

            count.value = 60;
            await tester.pumpAndSettle();
            expect(tester.getSize(surface).height, greaterThan(shortHeight));
            expect(tester.getRect(surface).top, greaterThanOrEqualTo(24));
            expect(tester.getRect(surface).bottom, lessThanOrEqualTo(1000));

            // IME and a short landscape viewport must keep the same scroll owner.
            tester.view.physicalSize = Size(width, 480);
            tester.view.viewInsets = const FakeViewPadding(bottom: 120);
            await tester.pumpAndSettle();
            expect(tester.getRect(surface).bottom, lessThanOrEqualTo(360));
            if (fixedFooter) {
              expect(find.text('Done').hitTestable(), findsOneWidget);
            }
            final scrollable = tester.state<ScrollableState>(
              find.byType(Scrollable),
            );
            scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            await tester.pumpAndSettle();
            await Scrollable.ensureVisible(
              tester.element(find.text('Field 59')),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(find.text('Field 59').hitTestable(), findsOneWidget);
            scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(find.text('Done').hitTestable(), findsOneWidget);

            tester.view.physicalSize = Size(width, 1000);
            tester.view.viewInsets = const FakeViewPadding();
            count.value = 1;
            await tester.pumpAndSettle();
            expect(tester.getSize(surface).height, closeTo(shortHeight, 0.01));
            await tester.tap(find.text('Done'));
            await tester.pumpAndSettle();
            expect(surface, findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
