import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_content_view.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  testWidgets('grouped gallery forwards secondary taps to the context menu', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
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
