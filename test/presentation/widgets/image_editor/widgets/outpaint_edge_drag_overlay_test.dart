import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/canvas_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/outpaint_edge_drag_overlay.dart';

Widget _wrapOverlay({
  required CanvasController controller,
  required OutpaintEdgeDragCommitted onCommitted,
  OutpaintFrameResizeCommitted? onFrameResizeCommitted,
  OutpaintEdgeDragPreviewChanged? onPreviewChanged,
  bool enabled = true,
  Size canvasSize = const Size(128, 96),
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: OutpaintEdgeDragOverlay(
          canvasSize: canvasSize,
          controller: controller,
          onPreviewChanged: onPreviewChanged,
          onCommitted: onCommitted,
          onFrameResizeCommitted: onFrameResizeCommitted,
          enabled: enabled,
        ),
      ),
    ),
  );
}

void main() {
  late CanvasController controller;

  setUp(() {
    controller = CanvasController()
      ..setScale(0.5)
      ..setOffset(const Offset(100, 100));
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets(
    'right handle converts screen drag through scale and commits right edge',
    (tester) async {
      OutpaintEdges? committedEdges;
      OutpaintHorizontalSnapTarget? horizontalTarget;
      OutpaintVerticalSnapTarget? verticalTarget;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
                horizontalTarget = horizontalSnapTarget;
                verticalTarget = verticalSnapTarget;
              },
        ),
      );

      await tester.drag(
        find.byKey(const Key('outpaint_handle_right')),
        const Offset(32, 0),
      );
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.right, 64);
      expect(committedEdges!.left, 0);
      expect(committedEdges!.top, 0);
      expect(committedEdges!.bottom, 0);
      expect(horizontalTarget, OutpaintHorizontalSnapTarget.right);
      expect(verticalTarget, OutpaintVerticalSnapTarget.bottom);
    },
  );

  testWidgets('right edge zone exposes resize cursor and hover highlight', (
    tester,
  ) async {
    controller.setScale(1);
    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    final rightEdge = find.byKey(const Key('outpaint_edge_right'));
    expect(rightEdge, findsOneWidget);

    final edgeRegion = tester.widget<MouseRegion>(rightEdge);
    expect(edgeRegion.cursor, SystemMouseCursors.resizeLeftRight);

    final edgeRect = tester.getRect(rightEdge);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
      location: Offset(edgeRect.center.dx, edgeRect.top + 24),
    );
    await tester.pump();

    expect(find.byKey(const Key('outpaint_highlight_right')), findsOneWidget);

    await gesture.removePointer();
  });

  testWidgets('right edge zone drag inward commits a frame crop delta', (
    tester,
  ) async {
    controller.setScale(1);
    OutpaintFrameDelta? committedDelta;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
        onFrameResizeCommitted:
            (
              delta, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {
              committedDelta = delta;
            },
      ),
    );

    final rightEdge = find.byKey(const Key('outpaint_edge_right'));
    final edgeRect = tester.getRect(rightEdge);
    final gesture = await tester.startGesture(
      Offset(edgeRect.center.dx, edgeRect.top + 24),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.moveBy(const Offset(-80, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(committedDelta, isNotNull);
    expect(committedDelta!.right, equals(-80));
  });

  testWidgets(
    'left handle stays hittable near viewport edge and commits left edge',
    (tester) async {
      controller.setOffset(const Offset(-20, 100));
      OutpaintEdges? committedEdges;
      OutpaintHorizontalSnapTarget? horizontalTarget;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
                horizontalTarget = horizontalSnapTarget;
              },
        ),
      );

      final leftHandle = find.byKey(const Key('outpaint_handle_left'));
      final handleCenter = tester.getCenter(leftHandle);

      expect(handleCenter.dx, greaterThanOrEqualTo(11));

      await tester.drag(leftHandle, const Offset(-32, 0));
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.left, 64);
      expect(committedEdges!.right, 0);
      expect(horizontalTarget, OutpaintHorizontalSnapTarget.left);
    },
  );

  testWidgets(
    'top-left corner converts both axes through scale and commits left and top',
    (tester) async {
      OutpaintEdges? committedEdges;
      OutpaintHorizontalSnapTarget? horizontalTarget;
      OutpaintVerticalSnapTarget? verticalTarget;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
                horizontalTarget = horizontalSnapTarget;
                verticalTarget = verticalSnapTarget;
              },
        ),
      );

      await tester.drag(
        find.byKey(const Key('outpaint_handle_top_left')),
        const Offset(-32, -16),
      );
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.left, 64);
      expect(committedEdges!.top, 32);
      expect(committedEdges!.right, 0);
      expect(committedEdges!.bottom, 0);
      expect(horizontalTarget, OutpaintHorizontalSnapTarget.left);
      expect(verticalTarget, OutpaintVerticalSnapTarget.top);
    },
  );

  testWidgets('emits live preview and applied snapped size while dragging', (
    tester,
  ) async {
    final previews = <OutpaintEdges>[];

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onPreviewChanged: previews.add,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
    );
    await gesture.moveBy(const Offset(32, 0));
    await tester.pump();

    expect(previews, isNotEmpty);
    expect(previews.last.right, 64);
    expect(find.text('Applied: 192 x 128'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'does not emit redundant preview changes while applied size is unchanged',
    (tester) async {
      final previews = <OutpaintEdges>[];

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          canvasSize: const Size(128, 128),
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {},
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
      );
      await gesture.moveBy(const Offset(17, 0));
      await gesture.moveBy(const Offset(1, 0));
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();

      expect(find.text('Applied: 192 x 128'), findsOneWidget);
      expect(previews, hasLength(1));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'pointer up commits latest raw delta when preview frame has not fired',
    (tester) async {
      final previews = <OutpaintEdges>[];
      OutpaintEdges? committedEdges;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          canvasSize: const Size(128, 128),
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
              },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
      );
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();

      expect(previews, isEmpty);
      expect(find.text('Applied: 192 x 128'), findsNothing);

      await gesture.moveBy(const Offset(31, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.right, 64);
      expect(previews, hasLength(1));
    },
  );

  testWidgets(
    'pointer cancel commits latest raw delta when preview edges exist',
    (tester) async {
      final previews = <OutpaintEdges>[];
      OutpaintEdges? committedEdges;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
              },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
      );
      await gesture.moveBy(const Offset(17, 0));
      await tester.pump();

      expect(previews, hasLength(1));
      expect(previews.single.right, 34);

      await gesture.moveBy(const Offset(15, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.right, 64);
      expect(previews, hasLength(1));
    },
  );

  testWidgets(
    'pointer cancel commits valid raw delta before preview frame fires',
    (tester) async {
      final previews = <OutpaintEdges>[];
      OutpaintEdges? committedEdges;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                committedEdges = edges;
              },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
      );
      await gesture.moveBy(const Offset(32, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.right, 64);
      expect(previews, hasLength(1));
    },
  );

  testWidgets(
    'corner drag emits one coherent preview with both affected edges',
    (tester) async {
      final previews = <OutpaintEdges>[];

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {},
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_top_left'))),
      );
      await gesture.moveBy(const Offset(-32, -16));
      await tester.pump();

      expect(previews, hasLength(1));
      expect(previews.single.left, 64);
      expect(previews.single.top, 32);
      expect(previews.single.right, 0);
      expect(previews.single.bottom, 0);
      expect(find.text('Applied: 192 x 128'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'overlay preview geometry matches async materialization for every handle',
    (tester) async {
      final sourceImage = _sourcePng(128, 96);
      const cases = <_OverlayGeometryCase>[
        _OverlayGeometryCase(
          description: 'left',
          handleKey: Key('outpaint_handle_left'),
          dragDelta: Offset(-16.5, 0),
          expectedRequestedEdges: OutpaintEdges(left: 33),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        _OverlayGeometryCase(
          description: 'top',
          handleKey: Key('outpaint_handle_top'),
          dragDelta: Offset(0, -32),
          expectedRequestedEdges: OutpaintEdges(top: 64),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.top,
        ),
        _OverlayGeometryCase(
          description: 'right',
          handleKey: Key('outpaint_handle_right'),
          dragDelta: Offset(16.5, 0),
          expectedRequestedEdges: OutpaintEdges(right: 33),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        _OverlayGeometryCase(
          description: 'bottom',
          handleKey: Key('outpaint_handle_bottom'),
          dragDelta: Offset(0, 20.5),
          expectedRequestedEdges: OutpaintEdges(bottom: 41),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        _OverlayGeometryCase(
          description: 'top-left',
          handleKey: Key('outpaint_handle_top_left'),
          dragDelta: Offset(-16.5, -32),
          expectedRequestedEdges: OutpaintEdges(left: 33, top: 64),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.top,
        ),
        _OverlayGeometryCase(
          description: 'top-right',
          handleKey: Key('outpaint_handle_top_right'),
          dragDelta: Offset(16.5, -32),
          expectedRequestedEdges: OutpaintEdges(top: 64, right: 33),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.top,
        ),
        _OverlayGeometryCase(
          description: 'bottom-left',
          handleKey: Key('outpaint_handle_bottom_left'),
          dragDelta: Offset(-16.5, 20.5),
          expectedRequestedEdges: OutpaintEdges(left: 33, bottom: 41),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.left,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
        _OverlayGeometryCase(
          description: 'bottom-right',
          handleKey: Key('outpaint_handle_bottom_right'),
          dragDelta: Offset(16.5, 20.5),
          expectedRequestedEdges: OutpaintEdges(right: 33, bottom: 41),
          horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
          verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
        ),
      ];

      for (final testCase in cases) {
        OutpaintEdges? previewEdges;
        await tester.pumpWidget(
          _wrapOverlay(
            controller: controller,
            onPreviewChanged: (edges) {
              previewEdges = edges;
            },
            onCommitted:
                (
                  edges, {
                  required horizontalSnapTarget,
                  required verticalSnapTarget,
                }) async {},
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(testCase.handleKey)),
        );
        await gesture.moveBy(testCase.dragDelta);
        await tester.pump();

        expect(previewEdges, isNotNull, reason: testCase.description);
        final requestedEdges = previewEdges!;
        _expectEdges(
          requestedEdges,
          testCase.expectedRequestedEdges,
          reason: '${testCase.description} requested preview edges',
        );
        final requestedDelta = OutpaintFrameDelta.fromExpansionEdges(
          requestedEdges,
        );
        final resolvedGeometry = InpaintOutpaintUtils.resolveFrameGeometry(
          sourceWidth: 128,
          sourceHeight: 96,
          delta: requestedDelta,
          horizontalSnapTarget: testCase.horizontalSnapTarget,
          verticalSnapTarget: testCase.verticalSnapTarget,
        );
        final (labelWidth, labelHeight) = _appliedLabelSize(tester);

        await gesture.up();
        await tester.pumpAndSettle();

        final materialized = await tester.runAsync(
          () => InpaintOutpaintUtils.resizeFrameAsync(
            sourceImage: sourceImage,
            delta: requestedDelta,
            horizontalSnapTarget: testCase.horizontalSnapTarget,
            verticalSnapTarget: testCase.verticalSnapTarget,
          ),
        );
        expect(materialized, isNotNull, reason: testCase.description);

        expect(
          labelWidth,
          resolvedGeometry.width,
          reason: '${testCase.description} label width',
        );
        expect(
          labelHeight,
          resolvedGeometry.height,
          reason: '${testCase.description} label height',
        );
        expect(
          materialized!.width,
          resolvedGeometry.width,
          reason: '${testCase.description} materialized width',
        );
        expect(
          materialized.height,
          resolvedGeometry.height,
          reason: '${testCase.description} materialized height',
        );
        _expectEdges(
          materialized.appliedExpansionEdges,
          resolvedGeometry.appliedExpansionEdges,
          reason: '${testCase.description} materialized applied edges',
        );
        expect(
          materialized.appliedCropEdges.isEmpty,
          resolvedGeometry.appliedCropEdges.isEmpty,
          reason: '${testCase.description} materialized crop edges',
        );
      }
    },
  );

  testWidgets('oversized drag does not throw or emit invalid preview', (
    tester,
  ) async {
    final previews = <OutpaintEdges>[];
    var commitCount = 0;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        canvasSize: const Size(4096, 96),
        onPreviewChanged: previews.add,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {
              commitCount++;
            },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
    );
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(previews, isEmpty);
    expect(find.textContaining('Applied:'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(commitCount, 0);
  });

  testWidgets(
    'oversized cancel before preview frame does not throw or commit invalid edges',
    (tester) async {
      final previews = <OutpaintEdges>[];
      var commitCount = 0;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          canvasSize: const Size(4096, 96),
          onPreviewChanged: previews.add,
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) async {
                commitCount++;
              },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
      );
      await gesture.moveBy(const Offset(1, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(previews, isEmpty);
      expect(find.textContaining('Applied:'), findsNothing);
      expect(commitCount, 0);
    },
  );

  testWidgets('does not commit when drag returns to zero edges', (
    tester,
  ) async {
    var commitCount = 0;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {
              commitCount++;
            },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('outpaint_handle_right'))),
    );
    await gesture.moveBy(const Offset(32, 0));
    await gesture.moveBy(const Offset(-32, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(commitCount, 0);
  });

  testWidgets('blocks a second drag while commit is pending', (tester) async {
    final firstCommit = Completer<void>();
    var commitCount = 0;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) {
              commitCount++;
              return firstCommit.future;
            },
      ),
    );

    await tester.drag(
      find.byKey(const Key('outpaint_handle_right')),
      const Offset(32, 0),
    );
    await tester.pump();

    expect(commitCount, 1);
    expect(find.byKey(const Key('outpaint_handle_right')), findsNothing);

    await tester.dragFrom(const Offset(164, 124), const Offset(32, 0));
    await tester.pump();

    expect(commitCount, 1);

    firstCommit.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outpaint_handle_right')), findsOneWidget);
  });

  testWidgets('keeps preview visible while commit is pending', (tester) async {
    final firstCommit = Completer<void>();
    var overlayEnabled = true;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        enabled: overlayEnabled,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) {
              return firstCommit.future;
            },
      ),
    );

    await tester.drag(
      find.byKey(const Key('outpaint_handle_right')),
      const Offset(32, 0),
    );
    await tester.pump();

    expect(find.text('Applied: 192 x 128'), findsOneWidget);
    expect(find.byKey(const Key('outpaint_handle_right')), findsNothing);

    overlayEnabled = false;
    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        enabled: overlayEnabled,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) {
              return firstCommit.future;
            },
      ),
    );

    expect(find.text('Applied: 192 x 128'), findsOneWidget);
    expect(find.byKey(const Key('outpaint_handle_right')), findsNothing);

    firstCommit.complete();
    await tester.pumpAndSettle();

    expect(find.text('Applied: 192 x 128'), findsNothing);
    expect(find.byKey(const Key('outpaint_handle_right')), findsNothing);
  });

  testWidgets(
    'keeps final corner preview visible until delayed commit completes',
    (tester) async {
      final commit = Completer<void>();
      OutpaintEdges? committedEdges;

      await tester.pumpWidget(
        _wrapOverlay(
          controller: controller,
          canvasSize: const Size(128, 128),
          onCommitted:
              (
                edges, {
                required horizontalSnapTarget,
                required verticalSnapTarget,
              }) {
                committedEdges = edges;
                return commit.future;
              },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('outpaint_handle_top_left'))),
      );
      await gesture.moveBy(const Offset(-17, -17));
      await tester.pump();

      expect(find.text('Applied: 192 x 192'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      expect(committedEdges, isNotNull);
      expect(committedEdges!.left, 34);
      expect(committedEdges!.top, 34);
      expect(find.text('Applied: 192 x 192'), findsOneWidget);
      expect(find.byKey(const Key('outpaint_handle_top_left')), findsNothing);

      commit.complete();
      await tester.pumpAndSettle();

      expect(find.text('Applied: 192 x 192'), findsNothing);
      expect(find.byKey(const Key('outpaint_handle_top_left')), findsOneWidget);
    },
  );

  testWidgets('commits active left drag after idle when pointer up is lost', (
    tester,
  ) async {
    OutpaintEdges? committedEdges;
    OutpaintHorizontalSnapTarget? horizontalTarget;

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {
              committedEdges = edges;
              horizontalTarget = horizontalSnapTarget;
            },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('outpaint_handle_left'))),
    );
    await gesture.moveBy(const Offset(-32, 0));
    await tester.pump();

    expect(find.text('Applied: 192 x 128'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();

    expect(committedEdges, isNotNull);
    expect(committedEdges!.left, 64);
    expect(horizontalTarget, OutpaintHorizontalSnapTarget.left);
    expect(find.text('Applied: 192 x 128'), findsNothing);

    await gesture.up();
  });

  testWidgets('hides handles when disabled, rotated, or mirrored', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        enabled: false,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    expect(find.byKey(const Key('outpaint_handle_left')), findsNothing);
    expect(find.byKey(const Key('outpaint_handle_right')), findsNothing);

    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller..rotateRight(),
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    expect(find.byKey(const Key('outpaint_handle_top')), findsNothing);
    expect(find.byKey(const Key('outpaint_handle_bottom')), findsNothing);

    controller.resetRotation();
    controller.toggleMirrorHorizontal();
    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    expect(find.byKey(const Key('outpaint_handle_top_left')), findsNothing);
    expect(find.byKey(const Key('outpaint_handle_bottom_right')), findsNothing);
  });

  testWidgets('拖拽热区不得吞掉画布的悬停事件', (tester) async {
    final hoverPositions = <Offset>[];
    var exitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MouseRegion(
                    onExit: (_) => exitCount++,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerHover: (event) =>
                          hoverPositions.add(event.localPosition),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: OutpaintEdgeDragOverlay(
                    canvasSize: const Size(128, 96),
                    controller: controller,
                    onCommitted:
                        (
                          edges, {
                          required horizontalSnapTarget,
                          required verticalSnapTarget,
                        }) async {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    // 起点落在画布矩形与所有热区之外
    await gesture.addPointer(location: const Offset(300, 300));
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();

    hoverPositions.clear();
    exitCount = 0;

    final edgeCenter = tester.getCenter(
      find.byKey(const Key('outpaint_edge_right')),
    );
    await gesture.moveTo(edgeCenter);
    await tester.pumpAndSettle();

    expect(
      hoverPositions.last,
      edgeCenter,
      reason: '热区必须让悬停事件继续下传，否则画笔光标会在画布边缘消失',
    );
    expect(exitCount, 0, reason: '热区不得让下层 MouseRegion 收到 onExit');

    final handleCenter = tester.getCenter(
      find.byKey(const Key('outpaint_handle_right')),
    );
    await gesture.moveTo(handleCenter);
    await tester.pumpAndSettle();

    expect(hoverPositions.last, handleCenter);
    expect(exitCount, 0);
  });

  testWidgets('手柄矩形算作拖拽热区，避免同时在画布上落笔', (tester) async {
    await tester.pumpWidget(
      _wrapOverlay(
        controller: controller,
        onCommitted:
            (
              edges, {
              required horizontalSnapTarget,
              required verticalSnapTarget,
            }) async {},
      ),
    );

    const viewportSize = Size(400, 400);
    for (final key in const [
      Key('outpaint_handle_top_left'),
      Key('outpaint_handle_bottom_right'),
      Key('outpaint_handle_right'),
    ]) {
      final center = tester.getCenter(find.byKey(key));
      expect(
        OutpaintEdgeDragOverlay.isResizeInteractionPoint(
          localPosition: center,
          viewportSize: viewportSize,
          canvasSize: const Size(128, 96),
          controller: controller,
        ),
        isTrue,
        reason: '$key 的中心必须被判定为拖拽热区',
      );
    }
  });
}

class _OverlayGeometryCase {
  final String description;
  final Key handleKey;
  final Offset dragDelta;
  final OutpaintEdges expectedRequestedEdges;
  final OutpaintHorizontalSnapTarget horizontalSnapTarget;
  final OutpaintVerticalSnapTarget verticalSnapTarget;

  const _OverlayGeometryCase({
    required this.description,
    required this.handleKey,
    required this.dragDelta,
    required this.expectedRequestedEdges,
    required this.horizontalSnapTarget,
    required this.verticalSnapTarget,
  });
}

(int width, int height) _appliedLabelSize(WidgetTester tester) {
  final labelFinder = find.textContaining('Applied:');
  expect(labelFinder, findsOneWidget);
  final text = tester.widget<Text>(labelFinder);
  final match = RegExp(r'Applied: (\d+) x (\d+)').firstMatch(text.data!);
  expect(match, isNotNull);
  return (int.parse(match!.group(1)!), int.parse(match.group(2)!));
}

void _expectEdges(
  OutpaintEdges actual,
  OutpaintEdges expected, {
  required String reason,
}) {
  expect(actual.left, expected.left, reason: '$reason left');
  expect(actual.top, expected.top, reason: '$reason top');
  expect(actual.right, expected.right, reason: '$reason right');
  expect(actual.bottom, expected.bottom, reason: '$reason bottom');
}

Uint8List _sourcePng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(24, 48, 72, 255));
  return Uint8List.fromList(img.encodePng(image));
}
