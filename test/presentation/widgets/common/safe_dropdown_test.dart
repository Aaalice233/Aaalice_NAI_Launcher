import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/safe_dropdown.dart';

void main() {
  testWidgets('touch dropdown keeps a 48dp target with 3x long text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(3)),
          child: InteractionPolicyScope(
            initialPolicy: InteractionPolicy(
              modality: InteractionModality.touch,
              touchAvailable: true,
              precisePointerAvailable: false,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: 328,
                  child: SafeDropdown<String>(
                    value: 'long',
                    items: [
                      DropdownMenuItem(
                        value: 'long',
                        child: Text('A very long localized dropdown option'),
                      ),
                    ],
                    onChanged: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(InputSurfaceContainer)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard opens and traverses dropdown options', (tester) async {
    String? value = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SafeDropdown<String>(
              value: value,
              items: const [
                DropdownMenuItem(value: 'a', child: Text('Alpha')),
                DropdownMenuItem(value: 'b', child: Text('Beta')),
              ],
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(value, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup avoids the bottom and right viewport edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 180,
              child: SafeDropdown<int>(
                value: 0,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Zero')),
                  DropdownMenuItem(value: 1, child: Text('One')),
                  DropdownMenuItem(value: 2, child: Text('Two')),
                  DropdownMenuItem(value: 3, child: Text('Three')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();

    final menuMaterial = find.descendant(
      of: find.byType(CustomSingleChildLayout),
      matching: find.byType(Material),
    );
    expect(menuMaterial, findsWidgets);
    final rect = tester.getRect(menuMaterial.last);
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.bottom, lessThanOrEqualTo(280));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });
}
