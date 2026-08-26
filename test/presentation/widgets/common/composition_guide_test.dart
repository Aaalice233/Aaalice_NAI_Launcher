import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/presentation/widgets/common/composition_guide.dart';

class _MockCanvas extends Mock implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(Offset.zero);
    registerFallbackValue(Paint());
  });

  group('CompositionGuideMode', () {
    test('存储值往返一致', () {
      for (final mode in CompositionGuideMode.values) {
        expect(CompositionGuideMode.fromStorageValue(mode.storageValue), mode);
      }
    });

    test('未设置或非法存储值回落到 none', () {
      expect(
        CompositionGuideMode.fromStorageValue(null),
        CompositionGuideMode.none,
      );
      expect(
        CompositionGuideMode.fromStorageValue(''),
        CompositionGuideMode.none,
      );
      expect(
        CompositionGuideMode.fromStorageValue('golden'),
        CompositionGuideMode.none,
      );
    });
  });

  group('CompositionGuide.linesOf', () {
    test('none 不产生任何线', () {
      final lines = CompositionGuide.linesOf(CompositionGuideMode.none);

      expect(lines.verticals, isEmpty);
      expect(lines.horizontals, isEmpty);
    });

    test('thirds 是两轴各两条三等分线', () {
      final lines = CompositionGuide.linesOf(CompositionGuideMode.thirds);

      expect(lines.verticals, [closeTo(1 / 3, 1e-9), closeTo(2 / 3, 1e-9)]);
      expect(lines.horizontals, [closeTo(1 / 3, 1e-9), closeTo(2 / 3, 1e-9)]);
    });

    test('phi 落在 0.382 与 0.618', () {
      final lines = CompositionGuide.linesOf(CompositionGuideMode.phi);

      expect(lines.verticals, [
        closeTo(0.381966, 1e-6),
        closeTo(0.618034, 1e-6),
      ]);
      expect(lines.horizontals, [
        closeTo(0.381966, 1e-6),
        closeTo(0.618034, 1e-6),
      ]);
      // 两轴独立成表，改一轴不会串到另一轴
      expect(identical(lines.verticals, lines.horizontals), isFalse);
    });

    test('grid 按列/行各产生 N-1 条内线', () {
      final lines = CompositionGuide.linesOf(
        CompositionGuideMode.grid,
        columns: 4,
        rows: 2,
      );

      expect(lines.verticals, [
        closeTo(0.25, 1e-9),
        closeTo(0.5, 1e-9),
        closeTo(0.75, 1e-9),
      ]);
      expect(lines.horizontals, [closeTo(0.5, 1e-9)]);
    });

    test('grid 的越界列/行先夹到合法区间', () {
      final tooMany = CompositionGuide.linesOf(
        CompositionGuideMode.grid,
        columns: 99,
        rows: 0,
      );

      expect(tooMany.verticals, hasLength(CompositionGuide.maxDivisions - 1));
      expect(tooMany.horizontals, hasLength(CompositionGuide.minDivisions - 1));
    });
  });

  group('CompositionGuide.clampDivisions', () {
    test('夹到 2-12', () {
      expect(
        CompositionGuide.clampDivisions(-5),
        CompositionGuide.minDivisions,
      );
      expect(CompositionGuide.clampDivisions(1), CompositionGuide.minDivisions);
      expect(CompositionGuide.clampDivisions(7), 7);
      expect(
        CompositionGuide.clampDivisions(50),
        CompositionGuide.maxDivisions,
      );
    });
  });

  group('CompositionGuidePainter', () {
    test('描边整层画完再画细线，交叉点不会被后一条咬掉', () {
      final canvas = _MockCanvas();
      const painter = CompositionGuidePainter(
        mode: CompositionGuideMode.thirds,
        columns: 3,
        rows: 3,
        devicePixelRatio: 1,
      );

      painter.paint(canvas, const Size(300, 300));

      final paints = verify(
        () => canvas.drawLine(any(), any(), captureAny()),
      ).captured.cast<Paint>();

      // 4 条线 × 描边/细线两轮
      expect(paints, hasLength(8));
      expect(
        paints
            .sublist(0, 4)
            .every((p) => identical(p, CompositionGuidePainter.halo)),
        isTrue,
      );
      expect(
        paints
            .sublist(4)
            .every((p) => identical(p, CompositionGuidePainter.stroke)),
        isTrue,
      );
    });

    test('线心对齐到设备像素中心', () {
      final canvas = _MockCanvas();
      const painter = CompositionGuidePainter(
        mode: CompositionGuideMode.grid,
        columns: 2,
        rows: 2,
        devicePixelRatio: 2,
      );

      painter.paint(canvas, const Size(101, 101));

      final starts = verify(
        () => canvas.drawLine(captureAny(), any(), any()),
      ).captured.cast<Offset>();

      // 101/2 = 50.5 → 设备像素 101 → 线心落到 101.5，回到逻辑坐标 50.75
      expect(starts.first.dx, closeTo(50.75, 1e-9));
    });

    test('档位与列行不变时不重绘', () {
      const painter = CompositionGuidePainter(
        mode: CompositionGuideMode.grid,
        columns: 3,
        rows: 3,
        devicePixelRatio: 1,
      );

      expect(
        painter.shouldRepaint(
          const CompositionGuidePainter(
            mode: CompositionGuideMode.grid,
            columns: 3,
            rows: 3,
            devicePixelRatio: 1,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const CompositionGuidePainter(
            mode: CompositionGuideMode.grid,
            columns: 4,
            rows: 3,
            devicePixelRatio: 1,
          ),
        ),
        isTrue,
      );
    });
  });

  group('CompositionGuideOverlay', () {
    final guideLayer = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CompositionGuidePainter,
    );

    Future<void> pumpOverlay(WidgetTester tester, CompositionGuideMode mode) {
      return tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: CompositionGuideOverlay(mode: mode),
        ),
      );
    }

    testWidgets('none 档位不挂 CustomPaint', (tester) async {
      await pumpOverlay(tester, CompositionGuideMode.none);

      expect(guideLayer, findsNothing);
    });

    testWidgets('开启档位后挂上不吃手势的绘制层', (tester) async {
      await pumpOverlay(tester, CompositionGuideMode.thirds);

      expect(guideLayer, findsOneWidget);
      expect(find.byType(IgnorePointer), findsOneWidget);
    });

    testWidgets('设备像素比透传给绘制层', (tester) async {
      await pumpOverlay(tester, CompositionGuideMode.thirds);

      final painter =
          tester.widget<CustomPaint>(guideLayer).painter!
              as CompositionGuidePainter;
      expect(painter.devicePixelRatio, 2);
    });
  });
}
