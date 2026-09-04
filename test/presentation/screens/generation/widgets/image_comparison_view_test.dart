import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_comparison_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
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

    expect(sourceClip, const Rect.fromLTRB(0, 0, 200, 300));
    expect(generatedClip, const Rect.fromLTRB(200, 0, 400, 300));
    expect(sourceClip.overlaps(generatedClip), isFalse);
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
              generatedImageBytes: _imageBytes(red: 220),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Uint8List _imageBytes({required int red}) {
  final image = img.Image(width: 4, height: 3);
  image.clear(img.ColorRgba8(red, 40, 50, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Size _paintedSize(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
}
