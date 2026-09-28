import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/content_sized_adaptive_form.dart';

void main() {
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
