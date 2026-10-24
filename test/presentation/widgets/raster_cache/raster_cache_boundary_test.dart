import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/raster_cache/raster_cache_boundary.dart';
import 'package:nai_launcher/presentation/widgets/raster_cache/raster_cache_layer.dart';

void main() {
  RasterCacheLayer layerOf(WidgetTester tester) =>
      tester
              .renderObject<RenderRasterCacheBoundary>(
                find.byType(RasterCacheBoundary),
              )
              .debugLayer!
          as RasterCacheLayer;

  Future<void> pumpUntilCached(WidgetTester tester) async {
    final required = layerOf(tester).policy.stableFramesRequired;
    for (var frame = 0; frame < required; frame += 1) {
      await tester.pump();
    }
    expect(layerOf(tester).isCached, isTrue);
  }

  testWidgets('caches only after the subtree stays unchanged long enough', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(child: _Content()));
    final required = layerOf(tester).policy.stableFramesRequired;

    for (var frame = 1; frame < required - 1; frame += 1) {
      await tester.pump();
      expect(layerOf(tester).isCached, isFalse);
    }
    await tester.pump();

    expect(layerOf(tester).isCached, isTrue);
  });

  testWidgets('a content change goes live immediately and caches again', (
    tester,
  ) async {
    final label = ValueNotifier('first');
    addTearDown(label.dispose);
    await tester.pumpWidget(
      _Harness(
        child: ValueListenableBuilder<String>(
          valueListenable: label,
          builder: (context, value, _) => _Content(label: value),
        ),
      ),
    );
    await pumpUntilCached(tester);

    label.value = 'second';
    await tester.pump();

    expect(layerOf(tester).isCached, isFalse);
    expect(find.text('second'), findsOneWidget);
    await pumpUntilCached(tester);
  });

  testWidgets('a nested repaint boundary repainting alone invalidates', (
    tester,
  ) async {
    final color = ValueNotifier(Colors.red);
    addTearDown(color.dispose);
    await tester.pumpWidget(
      _Harness(
        child: Stack(
          children: [
            const _Content(),
            RepaintBoundary(
              child: CustomPaint(
                size: const Size(20, 20),
                painter: _SwatchPainter(color),
              ),
            ),
          ],
        ),
      ),
    );
    await pumpUntilCached(tester);

    color.value = Colors.blue;
    await tester.pump();

    expect(layerOf(tester).isCached, isFalse);
  });

  testWidgets('the scope switch disables and evicts caching', (tester) async {
    await tester.pumpWidget(const _Harness(child: _Content()));
    await pumpUntilCached(tester);

    await tester.pumpWidget(const _Harness(enabled: false, child: _Content()));
    await tester.pump();
    expect(layerOf(tester).isCached, isFalse);

    for (var frame = 0; frame < 200; frame += 1) {
      await tester.pump();
    }
    expect(layerOf(tester).isCached, isFalse);
  });

  testWidgets('external textures are never cached', (tester) async {
    await tester.pumpWidget(
      const _Harness(
        child: Stack(children: [_Content(), Texture(textureId: 7)]),
      ),
    );

    for (var frame = 0; frame < 200; frame += 1) {
      await tester.pump();
    }

    expect(layerOf(tester).isCached, isFalse);
  });

  testWidgets('going offstage releases the snapshot', (tester) async {
    await tester.pumpWidget(const _Harness(child: _Content()));
    await pumpUntilCached(tester);
    final layer = layerOf(tester);

    await tester.pumpWidget(const _Harness(offstage: true, child: _Content()));
    await tester.pump();

    expect(layer.isCached, isFalse);
  });

  testWidgets(
    'whole device pixel moves keep the snapshot, half pixels drop it',
    (tester) async {
      final dpr = tester.view.devicePixelRatio;
      await tester.pumpWidget(
        const _Harness(origin: Offset(10.3, 7.7), child: _Content()),
      );
      await pumpUntilCached(tester);

      await tester.pumpWidget(
        _Harness(origin: Offset(10.3 + 2 / dpr, 7.7), child: const _Content()),
      );
      expect(layerOf(tester).isCached, isTrue);

      await tester.pumpWidget(
        _Harness(
          origin: Offset(10.3 + 2.5 / dpr, 7.7),
          child: const _Content(),
        ),
      );
      expect(layerOf(tester).isCached, isFalse);
    },
  );

  Future<_PixelDiff> compareLiveAndCached(
    WidgetTester tester,
    Widget content, {
    required Offset origin,
  }) async {
    await tester.pumpWidget(
      _Harness(enabled: false, origin: origin, child: content),
    );
    await tester.pump();
    final live = await _capture(tester);

    await tester.pumpWidget(_Harness(origin: origin, child: content));
    await pumpUntilCached(tester);
    await tester.pump();
    expect(layerOf(tester).isCached, isTrue);
    final cached = await _capture(tester);

    expect(cached.lengthInBytes, live.lengthInBytes);
    return _PixelDiff.between(live, cached);
  }

  testWidgets('a pixel-aligned opaque region is cached bit for bit', (
    tester,
  ) async {
    final diff = await compareLiveAndCached(
      tester,
      const ColoredBox(color: Color(0xFF283848), child: _Content()),
      origin: const Offset(10, 7),
    );

    expect(diff.differingBytes, 0);
  });

  // 快照只能是 8 位预乘色：半透明像素或半像素位置的边缘一圈叠到边界外背景上时多取整一次。
  testWidgets('translucent or sub-pixel edges stay within 8-bit rounding', (
    tester,
  ) async {
    final opaqueAtSubPixel = await compareLiveAndCached(
      tester,
      const ColoredBox(color: Color(0xFF283848), child: _Content()),
      origin: const Offset(10.3, 7.7),
    );
    final translucent = await compareLiveAndCached(
      tester,
      const _Content(),
      origin: const Offset(10.3, 7.7),
    );

    expect(opaqueAtSubPixel.maxChannelDelta, lessThanOrEqualTo(2));
    expect(translucent.maxChannelDelta, lessThanOrEqualTo(2));
  });
}

class _PixelDiff {
  const _PixelDiff(this.differingBytes, this.maxChannelDelta);

  factory _PixelDiff.between(Uint8List a, Uint8List b) {
    var differing = 0;
    var maxDelta = 0;
    for (var i = 0; i < a.lengthInBytes; i += 1) {
      final delta = (a[i] - b[i]).abs();
      if (delta == 0) continue;
      differing += 1;
      if (delta > maxDelta) maxDelta = delta;
    }
    return _PixelDiff(differing, maxDelta);
  }

  final int differingBytes;
  final int maxChannelDelta;
}

Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_Harness.captureKey),
  );
  final dpr = tester.view.devicePixelRatio;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.child,
    this.enabled = true,
    this.offstage = false,
    this.origin = Offset.zero,
  });

  static const captureKey = ValueKey('raster-cache-capture');

  final Widget child;
  final bool enabled;
  final bool offstage;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RasterCacheScope(
        enabled: enabled,
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: const Color(0xFF203040),
            child: Stack(
              children: [
                Positioned(
                  left: origin.dx,
                  top: origin.dy,
                  width: 160,
                  height: 90,
                  child: Offstage(
                    offstage: offstage,
                    child: RasterCacheBoundary(child: child),
                  ),
                ),
                // 测试绑定只在有排帧时才出帧；缓存的前提正是相邻区域持续动画。
                const Positioned(right: 0, bottom: 0, child: _Spinner()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({this.label = 'first'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          colors: [Color(0x80FF8040), Color(0xCC40A0FF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)),
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(8, 8),
        painter: _SpinnerPainter(_controller),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(Colors.white, Colors.black, progress.value)!,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => false;
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.color) : super(repaint: color);

  final ValueNotifier<Color> color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.value);
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) => false;
}
