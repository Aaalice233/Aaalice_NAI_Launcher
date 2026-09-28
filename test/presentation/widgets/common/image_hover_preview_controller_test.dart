import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/image_hover_preview_controller.dart';

void main() {
  testWidgets('hover intent starts after delay and is cancelled on dismiss', (
    tester,
  ) async {
    final controller = ImageHoverPreviewController();
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    var intents = 0;
    var dismissals = 0;
    controller.schedule(
      context: context,
      stableKey: 'post:1',
      layerLink: LayerLink(),
      targetRect: const Rect.fromLTWH(0, 0, 100, 100),
      previewSize: const Size(200, 200),
      builder: (_) => const Text('preview'),
      onIntent: () => intents++,
      onDismissIntent: () => dismissals++,
    );

    await tester.pump(const Duration(milliseconds: 279));
    expect(intents, 0);
    controller.dismiss();
    expect(dismissals, 0);

    controller.schedule(
      context: context,
      stableKey: 'post:1',
      layerLink: LayerLink(),
      targetRect: const Rect.fromLTWH(0, 0, 100, 100),
      previewSize: const Size(200, 200),
      builder: (_) => const Text('preview'),
      onIntent: () => intents++,
      onDismissIntent: () => dismissals++,
    );
    await tester.pump(const Duration(milliseconds: 280));
    expect(intents, 1);

    controller.dismiss();
    expect(dismissals, 1);
  });

  testWidgets('latest stable key replaces an earlier pending preview', (
    tester,
  ) async {
    final controller = ImageHoverPreviewController();
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    controller.schedule(
      context: context,
      stableKey: 'first',
      layerLink: LayerLink(),
      targetRect: const Rect.fromLTWH(0, 0, 20, 20),
      previewSize: const Size(100, 100),
      builder: (_) => const Text('first preview'),
    );
    controller.schedule(
      context: context,
      stableKey: 'second',
      layerLink: LayerLink(),
      targetRect: const Rect.fromLTWH(0, 0, 20, 20),
      previewSize: const Size(100, 100),
      builder: (_) => const Text('second preview'),
    );

    await tester.pump(const Duration(milliseconds: 281));
    expect(find.text('first preview'), findsNothing);
    expect(find.text('second preview'), findsOneWidget);
    expect(controller.activeStableKey, 'second');
  });

  testWidgets('preview stays inside safe padding and above view insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 20,
      top: 20,
      right: 20,
      bottom: 20,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);

    final controller = ImageHoverPreviewController();
    addTearDown(controller.dispose);
    final layerLink = LayerLink();
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                right: 20,
                bottom: 20,
                child: CompositedTransformTarget(
                  link: layerLink,
                  child: SizedBox(key: targetKey, width: 40, height: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final context = targetKey.currentContext!;
    final box = context.findRenderObject()! as RenderBox;
    controller.schedule(
      context: context,
      stableKey: 'safe',
      layerLink: layerLink,
      targetRect: box.localToGlobal(Offset.zero) & box.size,
      previewSize: const Size(300, 300),
      delay: const Duration(milliseconds: 1),
      builder: (_) => const SizedBox(
        key: ValueKey('safe-preview'),
        width: 300,
        height: 300,
      ),
    );
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    final rect = tester.getRect(find.byKey(const ValueKey('safe-preview')));
    expect(rect.left, greaterThanOrEqualTo(30));
    expect(rect.top, greaterThanOrEqualTo(30));
    expect(rect.right, lessThanOrEqualTo(470));
    expect(rect.bottom, lessThanOrEqualTo(290));

    tester.view.physicalSize = const Size(360, 280);
    await tester.pump();
    await tester.pump();

    final resizedRect = tester.getRect(
      find.byKey(const ValueKey('safe-preview')),
    );
    expect(resizedRect.left, greaterThanOrEqualTo(30));
    expect(resizedRect.top, greaterThanOrEqualTo(30));
    expect(resizedRect.right, lessThanOrEqualTo(330));
    expect(resizedRect.bottom, lessThanOrEqualTo(170));
  });

  testWidgets('preview hides when its source card leaves the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ImageHoverPreviewController();
    addTearDown(controller.dispose);
    final layerLink = LayerLink();
    final targetKey = GlobalKey();
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<Offset>(
          valueListenable: offset,
          builder: (context, value, child) => Transform.translate(
            offset: value,
            child: Align(
              alignment: Alignment.topLeft,
              child: CompositedTransformTarget(
                link: layerLink,
                child: SizedBox(key: targetKey, width: 40, height: 40),
              ),
            ),
          ),
        ),
      ),
    );

    final context = targetKey.currentContext!;
    final box = context.findRenderObject()! as RenderBox;
    controller.schedule(
      context: context,
      stableKey: 'offscreen',
      layerLink: layerLink,
      targetRect: box.localToGlobal(Offset.zero) & box.size,
      previewSize: const Size(180, 180),
      delay: const Duration(milliseconds: 1),
      builder: (_) => const SizedBox(
        key: ValueKey('offscreen-preview'),
        width: 180,
        height: 180,
      ),
    );
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(const ValueKey('offscreen-preview')), findsOneWidget);

    offset.value = const Offset(-600, 0);
    await tester.pump();
    controller.markNeedsBuild();
    await tester.pump();

    expect(find.byKey(const ValueKey('offscreen-preview')), findsNothing);
  });
}
