import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/shift_edges_dialog.dart';

import '../../../../../helpers/text_layout_expectations.dart';

Widget _wrapDialog({
  required int sourceWidth,
  required int sourceHeight,
  ValueChanged<ShiftEdgesResult?>? onResult,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final result = await ShiftEdgesDialog.show(
                context,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows requested and snapped outpaint size', (tester) async {
    await tester.pumpWidget(_wrapDialog(sourceWidth: 1024, sourceHeight: 1216));
    await _openDialog(tester);

    await tester.enterText(find.byKey(const Key('shift_edges_left')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_top')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_right')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_bottom')), '200');
    await tester.pump();

    expect(find.text('Requested: 1424 x 1616'), findsOneWidget);
    expect(find.text('Applied: 1472 x 1664'), findsOneWidget);
    expect(
      find.text('Applied edges: L 200, T 200, R 248, B 248'),
      findsOneWidget,
    );
  });

  testWidgets('returns requested and snapped edge payload', (tester) async {
    ShiftEdgesResult? result;
    await tester.pumpWidget(
      _wrapDialog(
        sourceWidth: 1024,
        sourceHeight: 1216,
        onResult: (value) => result = value,
      ),
    );
    await _openDialog(tester);

    await tester.enterText(find.byKey(const Key('shift_edges_left')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_top')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_right')), '200');
    await tester.enterText(find.byKey(const Key('shift_edges_bottom')), '200');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Shift Edges'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.requestedEdges.left, 200);
    expect(result!.requestedEdges.top, 200);
    expect(result!.requestedEdges.right, 200);
    expect(result!.requestedEdges.bottom, 200);
    expect(result!.appliedEdges.left, 200);
    expect(result!.appliedEdges.top, 200);
    expect(result!.appliedEdges.right, 248);
    expect(result!.appliedEdges.bottom, 248);
    expect(result!.width, 1472);
    expect(result!.height, 1664);
    expect(result!.horizontalSnapTarget, OutpaintHorizontalSnapTarget.right);
    expect(result!.verticalSnapTarget, OutpaintVerticalSnapTarget.bottom);
  });

  testWidgets('disables confirm for empty or oversized applied dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapDialog(sourceWidth: 1024, sourceHeight: 1216));
    await _openDialog(tester);

    FilledButton confirm() {
      return tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Shift Edges'),
      );
    }

    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('shift_edges_right')), '4000');
    await tester.pump();
    expect(confirm().onPressed, isNull);
  });

  testWidgets('320px, 3x text, and IME keep scrolling form actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _wrapDialog(
        sourceWidth: 1024,
        sourceHeight: 1216,
        textScaler: const TextScaler.linear(3),
        viewInsets: const EdgeInsets.only(bottom: 200),
      ),
    );
    await _openDialog(tester);

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const Key('shift_edges_scroll')), findsOneWidget);
    expect(find.byKey(const Key('shift_edges_cancel')), findsOneWidget);
    expect(find.byKey(const Key('shift_edges_confirm')), findsOneWidget);

    final confirmRect = tester.getRect(
      find.byKey(const Key('shift_edges_confirm')),
    );
    expect(confirmRect.bottom, lessThanOrEqualTo(440));
    expect(tester.takeException(), isNull);
  });

  testWidgets('escape cancels and enter confirms when valid', (tester) async {
    ShiftEdgesResult? result;
    await tester.pumpWidget(
      _wrapDialog(
        sourceWidth: 1024,
        sourceHeight: 1216,
        onResult: (value) => result = value,
      ),
    );
    await _openDialog(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Open'), findsOneWidget);

    await _openDialog(tester);
    await tester.enterText(find.byKey(const Key('shift_edges_right')), '64');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.requestedEdges.right, 64);
  });

  testWidgets(
    'invalid edge shows its error below the field at 320/600 and 3x',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final width in [320.0, 600.0]) {
        for (final scale in [1.0, 3.0]) {
          final reason = 'width=$width scale=$scale';
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            _wrapDialog(
              sourceWidth: 1024,
              sourceHeight: 1216,
              textScaler: TextScaler.linear(scale),
            ),
          );
          await _openDialog(tester);

          final left = find.byKey(const Key('shift_edges_left'));
          await tester.ensureVisible(left);
          await tester.enterText(left, '');
          await tester.pump();

          final error = find.descendant(
            of: left,
            matching: find.text('Enter a number'),
          );
          final surface = find.descendant(
            of: left,
            matching: find.byType(InputSurfaceContainer),
          );
          expect(error, findsOneWidget, reason: reason);
          expect(
            find.descendant(of: surface, matching: find.text('Enter a number')),
            findsNothing,
            reason: reason,
          );
          expect(
            tester.widget<InputSurfaceContainer>(surface).hasError,
            isTrue,
          );
          await tester.ensureVisible(error);
          await tester.pump();
          expect(
            tester.getTopLeft(error).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(surface).dy),
            reason: reason,
          );
          expectFullyVisible(tester, error, reason: reason);
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
    },
  );
}
