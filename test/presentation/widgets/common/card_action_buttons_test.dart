import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_surface.dart';

void main() {
  testWidgets(
    'small cards keep direct actions and a reachable hover overflow',
    (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: const ValueKey('small-card'),
              width: 96,
              height: 100,
              child: CardActionButtons(
                visible: true,
                direction: Axis.vertical,
                availableSize: const Size(96, 100),
                buttons: [
                  for (var i = 0; i < 7; i++)
                    ImageCardAction(
                      id: ImageCardActionId.values[i],
                      icon: Icons.download,
                      label: 'action $i',
                      invoke: () => selected = i,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.download), findsNWidgets(3));
      final bounds = tester.getRect(find.byKey(const ValueKey('small-card')));
      for (final button in find.byType(IconButton).evaluate()) {
        final rect = tester.getRect(find.byWidget(button.widget));
        expect(bounds.contains(rect.topLeft), isTrue);
        expect(bounds.contains(rect.bottomRight), isTrue);
      }
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('action 6'));
      await tester.pumpAndSettle();
      expect(selected, 6);
      expect(tester.takeException(), isNull);
    },
  );
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return CardActionButtons(
              visible: visible,
              buttons: [
                ImageCardAction(
                  id: ImageCardActionId.values[1],
                  icon: Icons.download,
                  label: 'download',
                  invoke: () {},
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

  testWidgets('returning from touch to mouse restores hover actions', (
    tester,
  ) async {
    var policy = InteractionPolicy.touchFirst;
    var visible = false;
    late StateSetter updateHost;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return InteractionPolicyScope(
              initialPolicy: policy,
              child: CardActionButtons(
                visible: visible,
                buttons: [
                  ImageCardAction(
                    id: ImageCardActionId.values[2],
                    icon: Icons.download,
                    label: 'download',
                    invoke: () {},
                  ),
                  ImageCardAction(
                    id: ImageCardActionId.values[3],
                    icon: Icons.more_horiz,
                    label: 'more',
                    invoke: () {},
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    updateHost(
      () => policy = policy.withPointerDevice(PointerDeviceKind.mouse),
    );
    await tester.pump();
    expect(find.byType(IconButton), findsNothing);
    updateHost(() => visible = true);
    await tester.pump();
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('desktop pointer and keyboard run the same action', (
    tester,
  ) async {
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                ImageCardAction(
                  id: ImageCardActionId.values[4],
                  icon: Icons.download,
                  label: 'download',
                  invoke: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IconButton)), const Size.square(32));

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                ImageCardAction(
                  id: ImageCardActionId.values[5],
                  icon: Icons.download,
                  label: 'download',
                  invoke: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('touch device without a mouse keeps its menu with a keyboard', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.keyboard,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: Center(
            child: CardActionButtons(
              visible: false,
              buttons: [
                ImageCardAction(
                  id: ImageCardActionId.values[6],
                  icon: Icons.download,
                  label: 'download',
                  invoke: () => pressed++,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: CardActionButtons(
            visible: true,
            buttons: [
              ImageCardAction(
                id: ImageCardActionId.values[7],
                icon: Icons.download,
                label: 'download',
                isLoading: true,
                invoke: () => pressed++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('download, Loading...'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size.square(32));
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                  ImageCardAction(
                    id: ImageCardActionId.values[8],
                    icon: index == 4 ? Icons.send : Icons.circle_outlined,
                    label: 'action $index',
                    invoke: index == 4 ? () => pressed++ : () {},
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

  testWidgets('long horizontal action groups wrap inside landscape cards', (
    tester,
  ) async {
    const cardSize = Size(200, 100);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            key: const ValueKey('landscape-card-bounds'),
            size: cardSize,
            child: CardActionButtons(
              visible: true,
              buttons: [
                for (var index = 0; index < 6; index++)
                  ImageCardAction(
                    key: ValueKey('landscape-action-$index'),
                    id: ImageCardActionId.values[index],
                    icon: Icons.circle_outlined,
                    label: 'action $index',
                    invoke: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final cardRect = tester.getRect(
      find.byKey(const ValueKey('landscape-card-bounds')),
    );
    final actionRects = [
      for (var index = 0; index < 6; index++)
        tester.getRect(find.byKey(ValueKey('landscape-action-$index'))),
    ];

    expect(actionRects, hasLength(6));
    for (final rect in actionRects) {
      expect(cardRect.contains(rect.topLeft), isTrue);
      expect(cardRect.contains(rect.bottomRight), isTrue);
    }
    expect(actionRects.last.top, greaterThan(actionRects.first.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seven pointer actions use two balanced columns', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: CardActionButtons(
            visible: true,
            direction: Axis.vertical,
            buttons: [
              for (var index = 0; index < 7; index++)
                ImageCardAction(
                  key: ValueKey('bounded-action-$index'),
                  id: ImageCardActionId.values[index],
                  icon: Icons.circle_outlined,
                  label: 'action $index',
                  invoke: () {},
                ),
            ],
          ),
        ),
      ),
    );

    final actionRects = [
      for (var index = 0; index < 7; index++)
        tester.getRect(find.byKey(ValueKey('bounded-action-$index'))),
    ];

    expect(actionRects.take(4).map((rect) => rect.left).toSet(), hasLength(1));
    expect(actionRects.skip(4).map((rect) => rect.left).toSet(), hasLength(1));
    expect(actionRects[4].left - actionRects[0].right, 4);
    expect(actionRects[4].top, actionRects[0].top);
  });

  testWidgets('hiding actions dismisses an active tooltip', (tester) async {
    var visible = true;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return CardActionButtons(
                visible: visible,
                buttons: [
                  ImageCardAction(
                    id: ImageCardActionId.values[9],
                    icon: Icons.download,
                    label: 'download',
                    invoke: () {},
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: CardActionButtons(
              visible: true,
              buttons: [
                ImageCardAction(
                  id: ImageCardActionId.values[10],
                  icon: Icons.download,
                  label: 'download',
                  invoke: () {},
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: ImageCardHoverActionBar(
            actions: [
              ImageCardAction(
                id: ImageCardActionId.copy,
                icon: Icons.copy,
                label: 'copy',
                menuLabel: 'copy',
                invoke: () {},
                group: ImageCardActionGroup.view,
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
