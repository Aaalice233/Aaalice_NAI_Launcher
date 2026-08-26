import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showPanel<void>(
                    context: context,
                    title: 'Panel title',
                    builder: (context, scrollController) => ListView(
                      key: const Key('panel-content'),
                      controller: scrollController,
                      children: const [Text('Panel body')],
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('compact windows use a draggable bottom sheet', (tester) async {
    await pumpHost(tester, const Size(400, 800));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Panel title'), findsOneWidget);
    expect(find.text('Panel body'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('compact panel uses root navigator and blocks shell navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var shellTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed: () {
                            unawaited(
                              AdaptivePresenter.showPanel<void>(
                                context: context,
                                title: 'Nested panel',
                                builder: (context, scrollController) =>
                                    ListView(
                                      controller: scrollController,
                                      children: const [
                                        Text('Nested panel body'),
                                      ],
                                    ),
                              ),
                            );
                          },
                          child: const Text('Open nested'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                key: const Key('shell-navigation'),
                height: 80,
                width: double.infinity,
                child: InkWell(
                  onTap: () => shellTapCount++,
                  child: const Center(child: Text('Shell navigation')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();
    expect(find.text('Nested panel body'), findsOneWidget);

    await tester.tapAt(const Offset(200, 760));
    await tester.pump();

    expect(shellTapCount, 0);
    expect(find.text('Nested panel body'), findsOneWidget);
  });

  testWidgets('expanded windows use a bounded side sheet', (tester) async {
    await pumpHost(tester, const Size(1200, 800));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Panel title'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('panel-content'))).width, 440);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });
}
