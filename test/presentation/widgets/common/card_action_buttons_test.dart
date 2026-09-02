import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_surface.dart';

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

  testWidgets('desktop pointer and keyboard run the same action', (
    tester,
  ) async {
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: Center(
            child: CardActionButtons(
              visible: true,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IconButton)), const Size.square(40));

    await tester.tap(find.byIcon(Icons.download));
    expect(pressed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 2);
  });

  testWidgets('observed touch capability keeps pointer targets touch-safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: true,
            precisePointerAvailable: true,
          ),
          child: Center(
            child: CardActionButtons(
              visible: true,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
  });

  testWidgets('touch alternative survives a later keyboard modality', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.keyboard,
            touchAvailable: true,
            precisePointerAvailable: true,
          ),
          child: Center(
            child: CardActionButtons(
              visible: false,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    await tester.tap(find.text('download'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });

  testWidgets('loading actions preserve geometry and cannot activate', (
    tester,
  ) async {
    var pressed = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CardActionButtons(
            visible: true,
            buttons: [
              CardActionButtonConfig(
                icon: Icons.download,
                tooltip: 'download',
                isLoading: true,
                onPressed: () => pressed++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('download, Loading…'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size.square(40));
    await tester.tap(find.byType(IconButton));
    expect(pressed, 0);
    semantics.dispose();
  });

  testWidgets('long vertical action groups remain inside their card', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 160,
            height: 160,
            child: CardActionButtons(
              visible: true,
              direction: Axis.vertical,
              buttons: [
                for (var index = 0; index < 5; index++)
                  CardActionButtonConfig(
                    icon: index == 4 ? Icons.send : Icons.circle_outlined,
                    tooltip: 'action $index',
                    onPressed: index == 4 ? () => pressed++ : () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.send));
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
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

  testWidgets('图像覆盖按钮在明暗主题下都使用高对比半透明样式', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: CardActionButtons(
              visible: true,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final button = tester.widget<IconButton>(find.byType(IconButton));
      final style = button.style!;
      expect(
        style.backgroundColor!.resolve(const {}),
        ImageOverlayControlStyle.surface,
      );
      expect(
        style.backgroundColor!.resolve(const {WidgetState.hovered}),
        ImageOverlayControlStyle.hoveredSurface,
      );
      expect(
        style.foregroundColor!.resolve(const {}),
        ImageOverlayControlStyle.foreground,
      );
      expect(
        style.side!.resolve(const {})!.color,
        ImageOverlayControlStyle.border,
      );
    }
  });

  testWidgets('工作台图像卡片底栏复用半透明图像覆盖层', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ImageCardHoverActionBar(
            actions: [
              ImageCardAction(
                id: ImageCardActionId.copy,
                icon: Icons.copy,
                label: 'copy',
                menuLabel: 'copy',
                invoke: () {},
                group: 0,
                showOnHover: true,
              ),
            ],
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('image-card-hover-action-bar-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, ImageOverlayControlStyle.toolbarSurface);
    expect(
      (decoration.border! as Border).top.color,
      ImageOverlayControlStyle.border,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.copy)).color, isNull);
    final actionButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      actionButton.style!.foregroundColor!.resolve(const {}),
      ImageOverlayControlStyle.foreground,
    );
  });
}
