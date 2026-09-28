import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/app_state_view.dart';

void main() {
  testWidgets('empty state remains readable on a narrow scaled viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: AppStateView.empty(
              title: 'No images',
              message: 'Add an image to begin editing this collection.',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'No images. Add an image to begin editing this collection.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('error action remains usable with 3x localized text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 420);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: Scaffold(
            body: AppStateView.error(
              title: 'Could not load the complete image collection',
              message: 'Check the connection and try the operation again.',
              actionLabel: 'Retry loading the complete collection',
              onAction: () => pressed++,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.text('Retry loading the complete collection'),
    );
    await tester.pump();
    await tester.tap(find.text('Retry loading the complete collection'));
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading becomes static when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppStateView.loading(title: 'Loading data'),
        ),
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, isNotNull);
  });

  testWidgets('touch actions keep a 48dp target and remain keyboard buttons', (
    tester,
  ) async {
    var pressed = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: Scaffold(
            body: AppStateView.error(
              title: 'Could not load',
              message: 'Check the connection and try again.',
              actionLabel: 'Retry',
              onAction: () => pressed++,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Retry'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.bySemanticsLabel('Retry'));
    expect(pressed, 1);
    semantics.dispose();
  });

  testWidgets('loading action is disabled and preserves its geometry', (
    tester,
  ) async {
    var pressed = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppStateView.error(
            title: 'Could not load',
            actionLabel: 'Retry',
            actionLoading: true,
            onAction: () => pressed++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Retry, Loading…'), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(40),
    );
    await tester.tap(find.byType(FilledButton));
    expect(pressed, 0);
    semantics.dispose();
  });
}
