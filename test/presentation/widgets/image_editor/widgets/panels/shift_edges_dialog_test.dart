import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/inpaint_outpaint_utils.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/shift_edges_dialog.dart';

Widget _wrapDialog({
  required int sourceWidth,
  required int sourceHeight,
  ValueChanged<ShiftEdgesResult?>? onResult,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
}
