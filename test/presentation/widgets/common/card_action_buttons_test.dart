import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('visibility changes actions in the same pump', (tester) async {
    var visible = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return CardActionButtons(
              visible: visible,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.download), findsNothing);

    setHostState(() => visible = true);
    await tester.pump();

    expect(find.byIcon(Icons.download), findsOneWidget);

    setHostState(() => visible = false);
    await tester.pump();

    expect(find.byIcon(Icons.download), findsNothing);
  });

  testWidgets('hiding actions dismisses an active tooltip', (tester) async {
    var visible = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return CardActionButtons(
                visible: visible,
                buttons: [
                  CardActionButtonConfig(
                    icon: Icons.download,
                    tooltip: 'download',
                    onPressed: () {},
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byIcon(Icons.download)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('download'), findsOneWidget);

    setHostState(() => visible = false);
    await tester.pump();

    expect(find.text('download'), findsNothing);
  });
}
