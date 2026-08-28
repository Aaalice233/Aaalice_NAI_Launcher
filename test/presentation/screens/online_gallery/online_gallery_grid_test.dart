import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_grid.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen_controller.dart';

void main() {
  testWidgets(
    'derives column count from grid width rather than viewport height',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) async {},
        ),
      );
      addTearDown(controller.dispose);
      int? builtColumnCount;

      Widget subject({required double width, required double height}) {
        return MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: OnlineGalleryGrid(
                  state: const OnlineGalleryState(),
                  controller: controller,
                  itemBuilder: (context, index, itemWidth, columnCount) {
                    builtColumnCount = columnCount;
                    return const SizedBox(height: 20);
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(subject(width: 360, height: 640));
      expect(builtColumnCount, 2);

      await tester.pumpWidget(subject(width: 360, height: 1000));
      expect(builtColumnCount, 2);

      await tester.pumpWidget(subject(width: 1180, height: 900));
      expect(builtColumnCount, 7);

      await tester.pumpWidget(subject(width: 1600, height: 900));
      expect(builtColumnCount, 8);
    },
  );
}
