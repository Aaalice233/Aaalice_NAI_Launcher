import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/window_size_class.dart';

void main() {
  group('WindowSizeClass', () {
    test('uses the shared app width breakpoints', () {
      expect(WindowSizeClass.fromWidth(double.nan), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839.9), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1179.9), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1180), WindowSizeClass.wide);
      expect(WindowSizeClass.fromWidth(double.infinity), WindowSizeClass.wide);
    });
  });

  testWidgets('largest foldable pane crops global safe and IME insets', (
    tester,
  ) async {
    late MediaQueryData paneData;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(900, 800),
          padding: EdgeInsets.fromLTRB(30, 12, 20, 18),
          viewPadding: EdgeInsets.fromLTRB(30, 12, 20, 18),
          viewInsets: EdgeInsets.only(bottom: 300),
          systemGestureInsets: EdgeInsets.only(left: 16, right: 12),
          displayFeatures: [
            DisplayFeature(
              bounds: Rect.fromLTWH(400, 0, 20, 800),
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureFlat,
            ),
          ],
        ),
        child: LargestDisplayFeatureSubScreen(
          child: Builder(
            builder: (context) {
              paneData = MediaQuery.of(context);
              return const SizedBox.expand(key: Key('foldable-pane'));
            },
          ),
        ),
      ),
    );

    expect(paneData.size, const Size(480, 800));
    expect(paneData.padding, const EdgeInsets.fromLTRB(0, 12, 20, 18));
    expect(paneData.viewInsets, const EdgeInsets.only(bottom: 300));
    expect(paneData.systemGestureInsets, const EdgeInsets.only(right: 12));
    expect(tester.getTopLeft(find.byKey(const Key('foldable-pane'))).dx, 420);
  });

  testWidgets('metrics separate safe and keyboard-obscured sizes', (
    tester,
  ) async {
    late AdaptiveWindowMetrics metrics;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(900, 900),
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          viewInsets: EdgeInsets.fromLTRB(4, 0, 4, 320),
        ),
        child: Builder(
          builder: (context) {
            metrics = context.adaptiveWindow;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(metrics.paneSize, const Size(900, 900));
    expect(metrics.safeUsableSize, const Size(868, 852));
    expect(metrics.unobscuredSize, const Size(860, 532));
    expect(metrics.safePadding, const EdgeInsets.fromLTRB(16, 24, 16, 24));
    expect(metrics.viewInsets, const EdgeInsets.fromLTRB(4, 0, 4, 320));
    expect(metrics.sizeClass, WindowSizeClass.expanded);
  });
}
