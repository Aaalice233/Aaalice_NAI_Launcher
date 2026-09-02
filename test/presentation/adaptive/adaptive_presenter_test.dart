import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    Size size, {
    String title = 'Panel title',
    TextScaler textScaler = TextScaler.noScaling,
    bool longForm = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                Widget builder(
                  BuildContext context,
                  ScrollController scrollController,
                ) => ListView(
                  key: const Key('panel-content'),
                  controller: scrollController,
                  children: const [Text('Panel body')],
                );
                unawaited(
                  longForm
                      ? AdaptivePresenter.showForm<void>(
                          context: context,
                          title: title,
                          builder: builder,
                        )
                      : AdaptivePresenter.showPanel<void>(
                          context: context,
                          title: title,
                          builder: builder,
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

  testWidgets('compact panel keeps content above the system navigation bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(bottom: 32);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showPanel<void>(
                    context: context,
                    title: 'Safe panel',
                    builder: (context, scrollController) => ListView(
                      key: const Key('safe-panel-content'),
                      controller: scrollController,
                      children: const [Text('Safe panel body')],
                    ),
                  ),
                );
              },
              child: const Text('Open safe panel'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open safe panel'));
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const Key('safe-panel-content')),
    );
    expect(contentRect.bottom, lessThanOrEqualTo(768));
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

  testWidgets('dismiss policy can require the explicit close action', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
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
                    title: 'Required panel',
                    barrierDismissible: false,
                    allowDragDismissal: false,
                    builder: (context, scrollController) => ListView(
                      controller: scrollController,
                      children: const [Text('Required content')],
                    ),
                  ),
                );
              },
              child: const Text('Open required'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open required'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Required content'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Required content'), findsNothing);
  });

  testWidgets('restores focus to the invoking control after close', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final triggerFocus = FocusNode();
    addTearDown(triggerFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              focusNode: triggerFocus,
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showPanel<void>(
                    context: context,
                    title: 'Focus panel',
                    builder: (context, scrollController) => ListView(
                      controller: scrollController,
                      children: const [Text('Focus content')],
                    ),
                  ),
                );
              },
              child: const Text('Open focus'),
            ),
          ),
        ),
      ),
    );

    triggerFocus.requestFocus();
    await tester.pump();
    expect(triggerFocus.hasFocus, isTrue);

    await tester.tap(find.text('Open focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(triggerFocus.hasFocus, isTrue);
  });

  testWidgets('compact long forms use the shared full-screen presentation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(599.9, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showForm<void>(
                    context: context,
                    title: 'Long form',
                    builder: (context, scrollController) => ListView(
                      controller: scrollController,
                      children: const [Text('Form content')],
                    ),
                  ),
                );
              },
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Form content'), findsOneWidget);
  });

  testWidgets('medium long forms use a bounded centered form', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(839.9, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showForm<void>(
                    context: context,
                    title: 'Medium form',
                    builder: (context, scrollController) => ListView(
                      controller: scrollController,
                      children: const [Text('Medium form content')],
                    ),
                  ),
                );
              },
              child: const Text('Open medium form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open medium form'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Medium form content'), findsOneWidget);
  });

  testWidgets('medium short forms fill the safe area with IME and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(839.9, 600);
    tester.view.padding = const FakeViewPadding(top: 12, bottom: 16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showForm<void>(
                    context: context,
                    title: 'Short medium form',
                    builder: (context, scrollController) => Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            children: const [Text('Scrollable content')],
                          ),
                        ),
                        FilledButton(
                          key: const Key('bottom-action'),
                          onPressed: () {},
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open short form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open short form'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(surface, findsOneWidget);
    expect(find.byKey(const Key('adaptive-centered-form')), findsNothing);
    expect(tester.getRect(surface), const Rect.fromLTWH(0, 12, 839.9, 392));
    expect(find.byKey(const Key('bottom-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded boundary uses the shared side-sheet width', (
    tester,
  ) async {
    await pumpHost(tester, const Size(840, 800));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Panel title'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('panel-content'))).width, 520);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('wide windows grow the side sheet within the shared contract', (
    tester,
  ) async {
    await pumpHost(tester, const Size(1600, 900), longForm: true);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('panel-content'))).width, 608);
  });

  testWidgets(
    'custom-header form omits the shared header without nesting a dialog',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () {
                  unawaited(
                    AdaptivePresenter.showForm<void>(
                      context: context,
                      showHeader: false,
                      builder: (context, _) => Column(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Custom close'),
                          ),
                          const Text('Custom detail'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open custom detail'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open custom detail'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Custom detail'), findsOneWidget);
    },
  );

  testWidgets('expanded side sheet supports large text without overflow', (
    tester,
  ) async {
    await pumpHost(
      tester,
      const Size(840, 800),
      title: 'Panel settings and options',
      textScaler: const TextScaler.linear(3),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('panel-content'))).width, 520);
    expect(tester.takeException(), isNull);
  });
}
