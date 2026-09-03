import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';

void main() {
  testWidgets('constraint changes do not enter the decoration animation', (
    tester,
  ) async {
    var bounded = true;
    late StateSetter updateHost;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Align(
                child: InputSurfaceContainer(
                  height: 40,
                  constraints: bounded
                      ? const BoxConstraints(maxWidth: 400)
                      : null,
                  child: const SizedBox(width: 200),
                ),
              );
            },
          ),
        ),
      ),
    );

    updateHost(() => bounded = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.takeException(), isNull);
  });

  testWidgets('focus outline keeps surface and child geometry stable', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: InputSurfaceContainer(
                key: const ValueKey('surface'),
                child: TextField(
                  key: const ValueKey('field'),
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restingSurface = tester.getRect(
      find.byKey(const ValueKey('surface')),
    );
    final restingField = tester.getRect(find.byKey(const ValueKey('field')));

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('surface'))),
      restingSurface,
    );
    expect(tester.getRect(find.byKey(const ValueKey('field'))), restingField);
    expect(tester.takeException(), isNull);
  });
}
