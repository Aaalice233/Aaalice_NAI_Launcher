import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/gallery_hover_controller.dart';

void main() {
  testWidgets('hover intent starts after delay and is cancelled on dismiss', (
    tester,
  ) async {
    final controller = GalleryHoverController();
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
}
