import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

void main() {
  testWidgets('waiting spinner does not repaint the whole generation card', (
    tester,
  ) async {
    var paints = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Center(
            child: RepaintBoundary(
              child: _PaintProbe(
                onPaint: () => paints++,
                child: const SizedBox(
                  width: 300,
                  height: 400,
                  child: SelectableImageCard(
                    isGenerating: true,
                    imageWidth: 832,
                    imageHeight: 1216,
                    currentImage: 1,
                    totalImages: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    paints = 0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    // The small indeterminate spinner remains active in its own paint layer.
    print('WAITING_CARD_PAINTS $paints / 30 animation frames');
    expect(paints, lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintCounter(onPaint);
}

class _PaintCounter extends RenderProxyBox {
  _PaintCounter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
