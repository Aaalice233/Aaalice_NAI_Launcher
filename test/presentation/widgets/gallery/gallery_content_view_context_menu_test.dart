import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_content_view.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  late Duration previousVisibilityUpdateInterval;

  setUp(() {
    previousVisibilityUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        previousVisibilityUpdateInterval;
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets(
    'grouped gallery coalesces pending dimension reads across rebuilds',
    (tester) async {
      final result = Completer<Size>();
      var reads = 0;
      late StateSetter rebuild;
      final record = LocalImageRecord(
        path: 'synthetic-pending.png',
        size: 1,
        modifiedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  rebuild = setState;
                  return GenericGalleryContentView<LocalImageRecord>(
                    columns: 1,
                    itemWidth: 160,
                    state: _GroupedGalleryState(record),
                    selectionState: const _InactiveSelectionState(),
                    itemBuilder: (_, __, ___, ____) => const SizedBox.shrink(),
                    idExtractor: (item) => item.path,
                    imageDimensionsLoader: (_) {
                      reads++;
                      return result.future;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      rebuild(() {});
      await tester.pump();
      rebuild(() {});
      await tester.pump();
      final readsBeforeCompletion = reads;
      result.complete(const Size(160, 320));
      await tester.pump();
      expect(readsBeforeCompletion, 1);
      expect(
        tester.widget<LocalImageCard3D>(find.byType(LocalImageCard3D)).height,
        320,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('grouped gallery forwards secondary taps to the context menu', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/grouped-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 11),
    );
    LocalImageRecord? selectedRecord;
    Offset? selectedPosition;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GenericGalleryContentView<LocalImageRecord>(
              columns: 1,
              itemWidth: 160,
              state: _GroupedGalleryState(record),
              selectionState: const _InactiveSelectionState(),
              itemBuilder: (_, __, ___, ____) => const SizedBox.shrink(),
              idExtractor: (item) => item.path,
              onContextMenu: (item, position) {
                selectedRecord = item;
                selectedPosition = position;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = find.byType(LocalImageCard3D);
    expect(card, findsOneWidget);

    await tester.tap(card, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(selectedRecord, same(record));
    expect(selectedPosition, isNotNull);
  });

  testWidgets('local card action layout follows the image aspect ratio', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/action-layout-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
    );

    Future<Axis> readDirection({
      required double width,
      required double height,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: width,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(LocalImageCard3D)),
      );
      await tester.pump();
      final direction = tester
          .widget<CardActionButtons>(find.byType(CardActionButtons))
          .direction;
      await mouse.removePointer();
      await tester.pump();
      return direction;
    }

    expect(await readDirection(width: 160, height: 220), Axis.vertical);
    expect(await readDirection(width: 220, height: 120), Axis.horizontal);
  });

  testWidgets(
    'moving away immediately after a card action does not open the image',
    (tester) async {
      final record = LocalImageRecord(
        path: 'G:/gallery/action-race-image.png',
        size: 42,
        modifiedAt: DateTime(2026, 7, 29),
      );
      var cardTapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: 160,
                  height: 220,
                  onTap: () => cardTapCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(LocalImageCard3D)),
      );
      await tester.pump();

      final copyButton = find.byIcon(Icons.copy);
      expect(copyButton, findsOneWidget);
      await mouse.moveTo(tester.getCenter(copyButton));
      await mouse.down(tester.getCenter(copyButton));
      await mouse.moveTo(const Offset(300, 300));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(cardTapCount, 0);
    },
  );

  testWidgets('touch cards expose favorite and context actions without hover', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    final record = LocalImageRecord(
      path: 'G:/gallery/touch-actions.png',
      size: 42,
      modifiedAt: DateTime(2026, 8, 2),
    );
    var cardTapCount = 0;
    var favoriteCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: InteractionPolicyScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: 160,
                  height: 220,
                  onTap: () => cardTapCount++,
                  onFavoriteToggle: () => favoriteCount++,
                  onSendAction: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _observeTouch(tester);

    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.byType(CardActionButtons), findsNothing);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Copy Prompt'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(favoriteCount, 1);
    expect(cardTapCount, 0);
  });

  testWidgets('grouped gallery send button dispatches the shared send action', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/grouped-send-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
    );
    LocalImageRecord? selectedRecord;
    LocalImageContextAction? selectedAction;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                height: 600,
                child: GenericGalleryContentView<LocalImageRecord>(
                  columns: 1,
                  itemWidth: 160,
                  state: _GroupedGalleryState(record),
                  selectionState: const _InactiveSelectionState(),
                  itemBuilder: (_, __, ___, ____) => const SizedBox.shrink(),
                  idExtractor: (item) => item.path,
                  onSendAction: (item, action) async {
                    selectedRecord = item;
                    selectedAction = action;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(LocalImageCard3D)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Send to Reverse Prompt'), findsOneWidget);
    expect(find.text('Import Image Metadata'), findsNothing);

    await tester.tap(find.text('Send to Reverse Prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selectedRecord, same(record));
    expect(selectedAction, LocalImageContextAction.sendToReversePrompt);

    selectedAction = null;
    await tester.tap(find.byIcon(Icons.text_snippet_outlined));
    await tester.pump();
    expect(selectedAction, LocalImageContextAction.copyPrompt);

    selectedAction = null;
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(selectedAction, LocalImageContextAction.delete);

    await mouse.removePointer();
    await tester.pump();
  });
}

Future<void> _observeTouch(WidgetTester tester) async {
  final position =
      tester.getBottomRight(find.byType(Scaffold)) - const Offset(1, 1);
  final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
  await touch.addPointer(location: position);
  await touch.down(position);
  await tester.pump();
  await touch.up();
  await tester.pump();
}

class _GroupedGalleryState implements GalleryState<LocalImageRecord> {
  const _GroupedGalleryState(this.record);

  final LocalImageRecord record;

  @override
  List<LocalImageRecord> get currentImages => [record];

  @override
  List<LocalImageRecord> get groupedImages => [record];

  @override
  bool get isGroupedView => true;

  @override
  bool get isPageLoading => false;

  @override
  bool get isGroupedLoading => false;

  @override
  int get currentPage => 0;

  @override
  bool get hasFilters => false;

  @override
  List<LocalImageRecord> get filteredFiles => [record];
}

class _InactiveSelectionState implements SelectionState {
  const _InactiveSelectionState();

  @override
  bool get isActive => false;

  @override
  Set<String> get selectedIds => const {};
}
