import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_segmented_control.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        '$width / ${scale}x keeps all modes horizontal and selectable',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 480);
          addTearDown(tester.view.reset);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StatefulBuilder(
                      builder: (context, setState) =>
                          HorizontalSegmentedControl(
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                  icon: Icon(Icons.add),
                                  label: Text('Create'),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  icon: Icon(Icons.playlist_add),
                                  label: Text('Append'),
                                ),
                                ButtonSegment(
                                  value: 2,
                                  icon: Icon(Icons.find_replace),
                                  label: Text('Overwrite'),
                                ),
                              ],
                              selected: {selected},
                              showSelectedIcon: false,
                              onSelectionChanged: (value) =>
                                  setState(() => selected = value.single),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final firstRect = tester.getRect(find.text('Create'));
          final secondRect = tester.getRect(find.text('Append'));
          final thirdRect = tester.getRect(find.text('Overwrite'));
          expect(secondRect.center.dy, closeTo(firstRect.center.dy, 0.1));
          expect(thirdRect.center.dy, closeTo(firstRect.center.dy, 0.1));
          expect(firstRect.right, lessThan(secondRect.left));
          expect(secondRect.right, lessThan(thirdRect.left));
          for (final (index, label) in [
            'Create',
            'Append',
            'Overwrite',
          ].indexed) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(selected, index);
          }
          tester.view.physicalSize = Size(width, 320);
          tester.view.viewInsets = const FakeViewPadding(bottom: 100);
          await tester.pumpAndSettle();
          expect(selected, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
