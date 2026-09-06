import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/image_comparison_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'comparison keeps full images, fits initially and offers actual output pixels',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpComparison(
        tester,
        width: 320,
        height: 240,
        pixelControls: true,
        generatedSize: const Size(832, 1216),
      );
      final generated = find.byKey(
        const ValueKey('generation-comparison-generated'),
      );
      final source = find.byKey(const ValueKey('generation-comparison-source'));
      expect(tester.widget<Image>(generated).image, isA<MemoryImage>());
      expect(tester.widget<Image>(source).image, isA<MemoryImage>());
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final destination = applyBoxFit(
        BoxFit.contain,
        const Size(832, 1216),
        tester.getSize(generated),
      ).destination;
      final actualScale = 832 / (destination.width * 2);
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byKey(const ValueKey('comparison-fit-window')));
      await tester.pump();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byKey(const ValueKey('comparison-actual-pixels')));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(actualScale, 0.001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('divider motion does not rebuild decoded image widgets', (
    tester,
  ) async {
    await _pumpComparison(tester, width: 400, height: 300);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('generation-comparison-divider-handle')),
      ),
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    var imageBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget is Image) imageBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(imageBuilds, 0);
  });

  testWidgets(
    'follow mouse stays aligned after zoom and pan and can be disabled',
    (tester) async {
      await _pumpComparison(tester, width: 400, height: 300);
      final viewport = find.byKey(
        const ValueKey('generation-image-comparison'),
      );
      final origin = tester.getTopLeft(viewport);
      final line = find.byKey(
        const ValueKey('generation-comparison-divider-line'),
      );
      final toggle = find.byKey(const ValueKey('comparison-follow-mouse'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(100, 180));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(origin + const Offset(120, 180));
      await tester.pump();
      expect(tester.getCenter(line).dx, closeTo(origin.dx + 200, 0.01));
      await tester.tap(toggle);
      await tester.pump();
      await mouse.moveTo(origin + const Offset(280, 180));
      await tester.pump();
      expect(tester.getCenter(line).dx, closeTo(origin.dx + 280, 0.01));
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      transform.value = Matrix4.identity()
        ..translateByDouble(-180, -60, 0, 1)
        ..scaleByDouble(3, 3, 3, 1);
      await tester.pump();
      expect(tester.getCenter(line).dx, closeTo(origin.dx + 280, 0.01));
      final zoom = transform.value.clone();
      await mouse.moveTo(origin + const Offset(30, 180));
      await tester.pump();
      expect(tester.getCenter(line).dx, closeTo(origin.dx + 30, 0.01));
      expect(transform.value, zoom);
      expect(
        tester.getRect(viewport).contains(tester.getRect(toggle).center),
        isTrue,
      );
      await tester.tap(toggle);
      await tester.pump();
      final stoppedX = tester.getCenter(line).dx;
      await mouse.moveTo(origin + const Offset(350, 180));
      await tester.pump();
      expect(tester.getCenter(line).dx, stoppedX);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'follow toggle remains reachable with large text on a short viewport',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 360));
        await _pumpComparison(tester, width: width, height: 300, textScale: 3);
        final toggle = find.byKey(const ValueKey('comparison-follow-mouse'));
        final viewport = tester.getRect(
          find.byKey(const ValueKey('generation-image-comparison')),
        );
        final rect = tester.getRect(toggle);
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
        expect(rect.height, greaterThanOrEqualTo(44));
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('drag and keyboard move the comparison divider', (tester) async {
    await _pumpComparison(tester, width: 400, height: 300);

    final line = find.byKey(
      const ValueKey('generation-comparison-divider-line'),
    );
    final handle = find.byKey(
      const ValueKey('generation-comparison-divider-handle'),
    );
    final initialX = tester.getCenter(line).dx;

    await tester.drag(handle, const Offset(80, 0));
    await tester.pump();
    final draggedX = tester.getCenter(line).dx;
    expect(draggedX, greaterThan(initialX + 60));
    final thumb = find.byKey(
      const ValueKey('generation-comparison-divider-thumb'),
    );
    final colors = Theme.of(tester.element(thumb)).colorScheme;
    final dragFocus = FocusManager.instance.primaryFocus;
    expect(tester.widget<Material>(thumb).color, colors.surfaceContainerHigh);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(dragFocus));
    expect(tester.widget<Material>(thumb).color, colors.primary);
    expect(tester.getCenter(line).dx, lessThan(draggedX));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('both layers share zoom and double tap resets it', (
    tester,
  ) async {
    await _pumpComparison(tester, width: 400, height: 300);

    expect(
      find.byKey(const ValueKey('generation-comparison-source')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('generation-comparison-generated')),
      findsOneWidget,
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 4);

    final comparison = find.byKey(
      const ValueKey('generation-image-comparison'),
    );
    final zoomPoint = tester.getTopLeft(comparison) + const Offset(80, 80);
    await tester.tapAt(zoomPoint);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(zoomPoint);
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(zoomPoint);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(zoomPoint);
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('source and generated image clips do not overlap', (
    tester,
  ) async {
    const comparisonSize = Size(400, 300);
    await _pumpComparison(
      tester,
      width: comparisonSize.width,
      height: comparisonSize.height,
    );

    final sourceClip = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('generation-comparison-source-clip')),
        )
        .clipper!
        .getClip(comparisonSize);
    final generatedClip = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('generation-comparison-generated-clip')),
        )
        .clipper!
        .getClip(comparisonSize);

    expect(generatedClip, const Rect.fromLTRB(0, 0, 200, 300));
    expect(sourceClip, const Rect.fromLTRB(200, 0, 400, 300));
    expect(sourceClip.overlaps(generatedClip), isFalse);

    await tester.drag(
      find.byKey(const ValueKey('generation-comparison-divider-handle')),
      const Offset(80, 0),
    );
    await tester.pump();
    final expandedResult = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('generation-comparison-generated-clip')),
        )
        .clipper!
        .getClip(comparisonSize);
    final reducedSource = tester
        .widget<ClipRect>(
          find.byKey(const ValueKey('generation-comparison-source-clip')),
        )
        .clipper!
        .getClip(comparisonSize);
    expect(expandedResult.width, greaterThan(generatedClip.width));
    expect(reducedSource.width, lessThan(sourceClip.width));
    expect(expandedResult.right, reducedSource.left);
    expect(expandedResult.overlaps(reducedSource), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('divider and thumb keep a constant painted size while zooming', (
    tester,
  ) async {
    await _pumpComparison(tester, width: 400, height: 300);

    final line = find.byKey(
      const ValueKey('generation-comparison-divider-line'),
    );
    final handle = find.byKey(
      const ValueKey('generation-comparison-divider-handle'),
    );
    final thumb = find.byKey(
      const ValueKey('generation-comparison-divider-thumb'),
    );
    final initialLineSize = _paintedSize(tester, line);
    final initialHandleSize = _paintedSize(tester, handle);
    final initialThumbSize = _paintedSize(tester, thumb);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );

    viewer.transformationController!.value = Matrix4.identity()
      ..scaleByDouble(4, 4, 4, 1);
    await tester.pump();

    expect(
      _paintedSize(tester, line).width,
      closeTo(initialLineSize.width, 0.01),
    );
    expect(
      _paintedSize(tester, handle).width,
      closeTo(initialHandleSize.width, 0.01),
    );
    expect(
      _paintedSize(tester, thumb).width,
      closeTo(initialThumbSize.width, 0.01),
    );
    expect(initialLineSize.width, closeTo(2, 0.01));
    expect(initialHandleSize.width, closeTo(48, 0.01));
    expect(initialThumbSize.width, closeTo(32, 0.01));
  });

  testWidgets('comparison stays laid out across shared UI breakpoints', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [360.0, 412.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await _pumpComparison(tester, width: width, height: 600);

      expect(
        find.byKey(const ValueKey('generation-image-comparison')),
        findsOneWidget,
        reason: 'comparison should render at width $width',
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpComparison(
  WidgetTester tester, {
  required double width,
  required double height,
  bool pixelControls = false,
  double textScale = 1,
  Size generatedSize = const Size(4, 3),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: InteractionPolicyScope(child: child!),
      ),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ImageComparisonView(
              sourceImageBytes: _imageBytes(red: 30),
              generatedImageBytes: _imageBytes(red: 220, size: generatedSize),
              fit: pixelControls ? BoxFit.contain : BoxFit.cover,
              showPixelScaleControls: pixelControls,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Uint8List _imageBytes({required int red, Size size = const Size(4, 3)}) {
  final image = img.Image(
    width: size.width.toInt(),
    height: size.height.toInt(),
  );
  image.clear(img.ColorRgba8(red, 40, 50, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Size _paintedSize(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
}
