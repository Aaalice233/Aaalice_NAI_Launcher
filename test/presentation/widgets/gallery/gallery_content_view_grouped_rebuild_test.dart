import 'dart:async';
import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/core/cache/gallery_aspect_ratio_cache.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_content_view.dart';
import 'package:nai_launcher/presentation/widgets/gallery/grouped_gallery_card.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';

void main() {
  testWidgets('grouped scrolling keeps mounted cards without a view rebuild', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final records = List.generate(
      60,
      (index) => LocalImageRecord(
        path: 'G:/gallery/grouped-$index.png',
        size: index + 1,
        modifiedAt: DateTime(2026, 7, 1),
        metadata: const NaiImageMetadata(width: 160, height: 200),
      ),
    );

    await _pumpGroupedView(tester, records: records);
    final before = _mountedCardsByPath(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    // 跨过可见性检测的默认 500ms 批次
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final after = _mountedCardsByPath(tester);
    final retained = before.keys.where(after.containsKey).toList();
    expect(retained, isNotEmpty);
    for (final path in retained) {
      expect(after[path], same(before[path]), reason: path);
    }
    expect(after.values.first.height, 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grouped selection mode toggles the tapped record', (
    tester,
  ) async {
    final records = List.generate(
      3,
      (index) => LocalImageRecord(
        path: 'G:/gallery/select-$index.png',
        size: index + 1,
        modifiedAt: DateTime(2026, 7, 1),
        metadata: const NaiImageMetadata(width: 160, height: 160),
      ),
    );
    final toggled = <String>[];

    await _pumpGroupedView(
      tester,
      records: records,
      selection: const _SelectionState(
        active: true,
        ids: {'G:/gallery/select-1.png'},
      ),
      onSelectionToggle: (record) => toggled.add(record.path),
    );

    expect(
      tester
          .widget<LocalImageCard3D>(_cardFor('G:/gallery/select-1.png'))
          .isSelected,
      isTrue,
    );
    await tester.tap(_cardFor('G:/gallery/select-2.png'));
    await tester.pump(kDoubleTapTimeout);
    expect(toggled, ['G:/gallery/select-2.png']);
  });

  group('GroupedGalleryCard', () {
    testWidgets('reads a missing aspect ratio once and rebuilds only itself', (
      tester,
    ) async {
      final reads = <String>[];
      final pending = Completer<double>();
      final cache = GalleryAspectRatioCache(
        readFile: (path) {
          reads.add(path);
          return pending.future;
        },
      );
      final missing = LocalImageRecord(
        path: 'G:/gallery/no-metadata.png',
        size: 10,
        modifiedAt: DateTime(2026, 7, 1),
      );
      final known = LocalImageRecord(
        path: 'G:/gallery/with-metadata.png',
        size: 11,
        modifiedAt: DateTime(2026, 7, 1),
        metadata: const NaiImageMetadata(width: 100, height: 200),
      );

      for (var rebuild = 0; rebuild < 3; rebuild++) {
        await _pumpCards(tester, cache, [missing, known]);
      }
      expect(reads, ['G:/gallery/no-metadata.png']);
      expect(_probeFor(tester, missing.path).aspectRatio, 1.0);
      expect(_probeFor(tester, known.path).aspectRatio, 0.5);
      final knownBefore = _probeFor(tester, known.path);

      pending.complete(2.0);
      await tester.pumpAndSettle();

      expect(_probeFor(tester, missing.path).aspectRatio, 2.0);
      expect(_probeFor(tester, known.path), same(knownBefore));

      await _pumpCards(tester, cache, const []);
      await _pumpCards(tester, cache, [missing]);
      expect(_probeFor(tester, missing.path).aspectRatio, 2.0);
      expect(reads, hasLength(1));
    });

    testWidgets('a replaced file is measured again', (tester) async {
      final reads = <String>[];
      final cache = GalleryAspectRatioCache(
        readFile: (path) async {
          reads.add(path);
          return reads.length == 1 ? 0.5 : 2.0;
        },
      );
      final original = LocalImageRecord(
        path: 'G:/gallery/replaced.png',
        size: 10,
        modifiedAt: DateTime(2026, 7, 1),
      );

      await _pumpCards(tester, cache, [original]);
      await tester.pump();
      expect(_probeFor(tester, original.path).aspectRatio, 0.5);

      final replaced = original.copyWith(size: 20);
      await _pumpCards(tester, cache, [replaced]);
      await tester.pump();
      expect(_probeFor(tester, original.path).aspectRatio, 2.0);
      expect(reads, hasLength(2));
    });
  });

  group('GalleryAspectRatioCache', () {
    test('failed reads fall back once and are not retried', () async {
      var reads = 0;
      final cache = GalleryAspectRatioCache(
        readFile: (_) {
          reads++;
          return Future.error(const FormatException('not an image'));
        },
      );
      final record = LocalImageRecord(
        path: 'G:/gallery/broken.png',
        size: 1,
        modifiedAt: DateTime(2026, 7, 1),
      );

      final results = await Future.wait([
        cache.resolve(record),
        cache.resolve(record),
      ]);

      expect(results, [1.0, 1.0]);
      expect(reads, 1);
      expect(cache.peek(record), 1.0);
      expect(await cache.resolve(record), 1.0);
      expect(reads, 1);
    });

    test('metadata dimensions never touch the file', () async {
      final cache = GalleryAspectRatioCache(
        readFile: (_) => fail('metadata must win'),
      );
      final record = LocalImageRecord(
        path: 'G:/gallery/metadata.png',
        size: 1,
        modifiedAt: DateTime(2026, 7, 1),
        metadata: const NaiImageMetadata(width: 300, height: 150),
      );

      expect(cache.peek(record), 2.0);
      expect(await cache.resolve(record), 2.0);
    });
  });
}

Map<String, LocalImageCard3D> _mountedCardsByPath(WidgetTester tester) => {
  for (final card in tester.widgetList<LocalImageCard3D>(
    find.byType(LocalImageCard3D, skipOffstage: false),
  ))
    card.record.path: card,
};

Finder _cardFor(String path) => find.byWidgetPredicate(
  (widget) => widget is LocalImageCard3D && widget.record.path == path,
);

Future<void> _pumpGroupedView(
  WidgetTester tester, {
  required List<LocalImageRecord> records,
  SelectionState selection = const _SelectionState(),
  void Function(LocalImageRecord record)? onSelectionToggle,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GenericGalleryContentView<LocalImageRecord>(
            columns: 3,
            itemWidth: 160,
            state: _GroupedState(records),
            selectionState: selection,
            idExtractor: (item) => item.path,
            onSelectionToggle: onSelectionToggle,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpCards(
  WidgetTester tester,
  GalleryAspectRatioCache cache,
  List<LocalImageRecord> records,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final record in records)
            GroupedGalleryCard(
              key: ValueKey(record.path),
              record: record,
              aspectRatios: cache,
              builder: (context, aspectRatio) => _AspectRatioProbe(
                path: record.path,
                aspectRatio: aspectRatio,
              ),
            ),
        ],
      ),
    ),
  );
}

_AspectRatioProbe _probeFor(WidgetTester tester, String path) =>
    tester.widget<_AspectRatioProbe>(
      find.byWidgetPredicate(
        (widget) => widget is _AspectRatioProbe && widget.path == path,
      ),
    );

class _AspectRatioProbe extends StatelessWidget {
  const _AspectRatioProbe({required this.path, required this.aspectRatio});

  final String path;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

class _GroupedState implements GalleryState<LocalImageRecord> {
  const _GroupedState(this.records);

  final List<LocalImageRecord> records;

  // 与 freezed 的列表 getter 一致：每次读取都是新视图
  @override
  List<LocalImageRecord> get groupedImages => UnmodifiableListView(records);

  @override
  List<LocalImageRecord> get currentImages => records;

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
  List<LocalImageRecord> get filteredFiles => records;
}

class _SelectionState implements SelectionState {
  const _SelectionState({this.active = false, this.ids = const {}});

  final bool active;
  final Set<String> ids;

  @override
  bool get isActive => active;

  @override
  Set<String> get selectedIds => ids;
}
