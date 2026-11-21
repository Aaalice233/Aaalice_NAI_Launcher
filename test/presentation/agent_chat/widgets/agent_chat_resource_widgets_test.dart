import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_resource_widgets.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';

void main() {
  testWidgets('generated resource picker ignores chunks but updates history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        galleryOverride: () =>
            _FakeLocalGalleryNotifier(_FakeLocalGalleryService()),
        onSelected: (_) async {},
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FilledButton).first),
    );
    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final image = GeneratedImage(
      id: 'generated',
      bytes: Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4))),
      width: 400,
      height: 100,
    );
    notifier.state = notifier.state.copyWith(
      status: GenerationStatus.generating,
      history: [image],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final itemFinder = find.byKey(
      const ValueKey('agent-chat-gallery-generated'),
    );
    final searchFinder = find.byKey(
      const ValueKey('agent-chat-resource-search'),
    );
    final item = tester.widget(itemFinder);
    final search = tester.widget(searchFinder);

    notifier.state = notifier.state.copyWith(
      progress: 0.5,
      streamPreview: image.bytes,
    );
    await tester.pump();
    expect(tester.widget(itemFinder), same(item));
    expect(tester.widget(searchFinder), same(search));

    notifier.state = notifier.state.copyWith(
      history: [
        GeneratedImage(id: 'new', bytes: image.bytes, width: 400, height: 100),
        image,
      ],
    );
    await tester.pump();
    expect(itemFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('agent-chat-gallery-new')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the resource picker keeps one history subscription', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      _TestApp(
        galleryOverride: () =>
            _FakeLocalGalleryNotifier(_FakeLocalGalleryService()),
        onSelected: (_) async {},
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );
    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    final history = [
      GeneratedImage(id: 'recent', bytes: bytes, width: 400, height: 100),
      GeneratedImage(id: 'older', bytes: bytes, width: 200, height: 100),
    ];
    notifier.state = ImageGenerationState(
      status: GenerationStatus.generating,
      history: history,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const ValueKey('adaptive-bottom-sheet')),
      matching: find.byType(ListView),
    );
    final drag = await tester.startGesture(tester.getCenter(list));
    await drag.moveBy(const Offset(0, 24));
    await tester.pump();
    for (var step = 0; step < 4; step++) {
      final previousHeight = tester.getSize(list).height;
      await drag.moveBy(const Offset(0, 32));
      await tester.pump();
      expect(tester.getSize(list).height, lessThan(previousHeight));
    }

    final chunk = _CountingHistoryState(history: history, streamPreview: bytes);
    notifier.state = chunk;
    expect(
      chunk.historyReads,
      1,
      reason: 'The history projection reads this field once per subscription.',
    );
    await tester.pump();

    final recent = find.text('400 × 100');
    final older = find.text('200 × 100');
    expect(recent, findsOneWidget);
    expect(older, findsOneWidget);
    expect(tester.getTopLeft(recent).dy, lessThan(tester.getTopLeft(older).dy));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0]) {
    testWidgets(
      'local reference gallery reaches history and searches the complete library at ${width.toInt()}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final service = _FakeLocalGalleryService();
        late _FakeLocalGalleryNotifier gallery;
        AgentChatResourceReference? selected;

        await tester.pumpWidget(
          _TestApp(
            galleryOverride: () => gallery = _FakeLocalGalleryNotifier(service),
            onSelected: (reference) async => selected = reference,
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-chat-resource-search')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('adaptive-bottom-sheet')),
          width < 840 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('adaptive-centered-form')),
          width >= 840 ? findsOneWidget : findsNothing,
        );

        await tester.tap(find.text('本地图库'));
        await tester.pumpAndSettle();

        expect(gallery.initializeCalls, 1);
        expect(find.text('today.png'), findsOneWidget);
        expect(find.text('archived-needle.png'), findsOneWidget);
        expect(
          service.requests,
          contains(const _QueryRequest(page: 1, searchQuery: '')),
        );

        final search = find.byKey(const ValueKey('agent-chat-resource-search'));
        await tester.enterText(search, 'needle');
        await tester.pump(const Duration(milliseconds: 260));
        await tester.pumpAndSettle();

        expect(find.text('today.png'), findsNothing);
        expect(find.text('archived-needle.png'), findsOneWidget);
        expect(
          service.requests,
          contains(const _QueryRequest(page: 0, searchQuery: 'needle')),
        );

        await tester.tap(find.text('archived-needle.png'));
        await tester.pumpAndSettle();

        expect(selected?.kind, AgentChatResourceKind.localGalleryImage);
        expect(selected?.resourceId, '92');
        expect(selected?.display['name'], 'archived-needle.png');
        expect(gallery.state.currentPage, 3);
        expect(gallery.state.filterCriteria.searchQuery, 'main-gallery-filter');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'attachment and resource pickers fit a 320x568 3x viewport with IME and preserve back dismissal',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(960, 1704);
      tester.view.viewInsets = const FakeViewPadding(bottom: 720);
      tester.view.padding = const FakeViewPadding(top: 60, bottom: 90);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.view.resetPadding();
      });

      AgentChatResourceReference? selected;
      await tester.pumpWidget(
        _TestApp(
          galleryOverride: () =>
              _FakeLocalGalleryNotifier(_FakeLocalGalleryService()),
          onSelected: (reference) async => selected = reference,
          textScale: 3,
        ),
      );

      final sheet = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(tester.getRect(sheet).top, greaterThanOrEqualTo(20));
      expect(tester.getRect(sheet).bottom, lessThanOrEqualTo(328));
      expect(tester.takeException(), isNull, reason: 'attachment picker');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(selected, isNull);

      await tester.tap(find.text('open resource'));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(tester.getRect(sheet).top, greaterThanOrEqualTo(20));
      expect(tester.getRect(sheet).bottom, lessThanOrEqualTo(328));
      expect(tester.takeException(), isNull, reason: 'resource picker');

      final resource = find.text('测试资源');
      await tester.ensureVisible(resource);
      await tester.tap(resource);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(selected?.kind, AgentChatResourceKind.tagLibraryEntry);
      expect(selected?.resourceId, 'tag-1');
    },
  );

  testWidgets('both resource managers use a centered dialog at 1180', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    AgentChatResourceReference? selected;
    await tester.pumpWidget(
      _TestApp(
        galleryOverride: () =>
            _FakeLocalGalleryNotifier(_FakeLocalGalleryService()),
        onSelected: (reference) async => selected = reference,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.text('生成历史'), findsOneWidget);
    expect(find.text('本地图库'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('open resource'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.text('标签词库'), findsOneWidget);
    expect(find.text('Vibe 库'), findsOneWidget);
    expect(find.text('精准参考库'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('agent-chat-resource-search')),
      'long_hair',
    );
    await tester.pump();
    await tester.tap(find.text('测试资源'));
    await tester.pumpAndSettle();

    expect(selected?.kind, AgentChatResourceKind.tagLibraryEntry);
    expect(selected?.resourceId, 'tag-1');
    expect(find.byKey(const ValueKey('adaptive-centered-form')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local history exposes an initialization error and retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeLocalGalleryService()..failNextQuery = true;

    await tester.pumpWidget(
      _TestApp(
        galleryOverride: () => _FakeLocalGalleryNotifier(service),
        onSelected: (_) async {},
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地图库'));
    await tester.pumpAndSettle();

    expect(find.textContaining('错误'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('today.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference gallery can be cancelled while local history loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeLocalGalleryService()..delayQueries = true;

    await tester.pumpWidget(
      _TestApp(
        galleryOverride: () => _FakeLocalGalleryNotifier(service),
        onSelected: (_) async {},
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本地图库'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    service.completeDelayedQuery();
    await tester.pump();

    expect(find.text('本地图库'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.galleryOverride,
    required this.onSelected,
    this.textScale = 1,
  });

  final _FakeLocalGalleryNotifier Function() galleryOverride;
  final Future<void> Function(AgentChatResourceReference) onSelected;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        localGalleryNotifierProvider.overrideWith(galleryOverride),
        imageGenerationNotifierProvider.overrideWith(
          _FakeImageGenerationNotifier.new,
        ),
        tagLibraryPageNotifierProvider.overrideWith(
          _FakeTagLibraryPageNotifier.new,
        ),
        vibeLibraryNotifierProvider.overrideWith(_FakeVibeLibraryNotifier.new),
        preciseRefLibraryNotifierProvider.overrideWith(
          _FakePreciseRefLibraryNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                FilledButton(
                  onPressed: () {
                    AgentChatResourcePicker.showReferenceGallery(
                      context: context,
                      ref: ref,
                      onSelected: onSelected,
                    );
                  },
                  child: const Text('open'),
                ),
                FilledButton(
                  onPressed: () {
                    AgentChatResourcePicker.showResourceLibrary(
                      context: context,
                      ref: ref,
                      onSelected: onSelected,
                    );
                  },
                  child: const Text('open resource'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeLocalGalleryNotifier extends LocalGalleryNotifier {
  _FakeLocalGalleryNotifier(this.service);

  final LocalGalleryService service;
  int initializeCalls = 0;

  @override
  LocalGalleryState build() => LocalGalleryState(
    isInitialized: true,
    currentPage: 3,
    totalPages: 8,
    filterCriteria: const FilterCriteria(searchQuery: 'main-gallery-filter'),
    currentImages: [
      LocalImageRecord(
        path: 'C:/main-gallery/current-page.png',
        size: 1,
        modifiedAt: DateTime(2026),
      ),
    ],
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<LocalGalleryService> getService() async => service;
}

class _FakeLocalGalleryService implements LocalGalleryService {
  final requests = <_QueryRequest>[];
  final _delayedQuery = Completer<LocalGalleryQueryPage>();
  bool delayQueries = false;
  bool failNextQuery = false;

  final today = LocalImageRecord(
    path: 'C:/gallery/today.png',
    size: 42,
    modifiedAt: DateTime(2026, 8, 30),
  );
  final archived = LocalImageRecord(
    path: 'C:/gallery/archived-needle.png',
    size: 84,
    modifiedAt: DateTime(2025),
  );

  void completeDelayedQuery() {
    if (!_delayedQuery.isCompleted) {
      _delayedQuery.complete(
        const LocalGalleryQueryPage(
          records: [],
          page: 0,
          pageSize: 50,
          totalCount: 0,
        ),
      );
    }
  }

  @override
  bool get isInitialized => true;

  @override
  int get filteredCount => 1;

  @override
  int get totalCount => 2;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  @override
  Future<List<File>> initialize() async => const [];

  @override
  Future<LocalGalleryQueryPage> queryPage({
    required int page,
    int pageSize = 50,
    String searchQuery = '',
  }) async {
    requests.add(_QueryRequest(page: page, searchQuery: searchQuery));
    if (delayQueries) return _delayedQuery.future;
    if (failNextQuery) {
      failNextQuery = false;
      throw StateError('query failed');
    }
    if (searchQuery == 'needle') {
      return LocalGalleryQueryPage(
        records: [archived],
        page: 0,
        pageSize: 50,
        totalCount: 1,
      );
    }
    if (page == 0) {
      return LocalGalleryQueryPage(
        records: [today],
        page: 0,
        pageSize: 1,
        totalCount: 2,
      );
    }
    return LocalGalleryQueryPage(
      records: [archived],
      page: 1,
      pageSize: 1,
      totalCount: 2,
    );
  }

  @override
  Future<int?> getImageIdByPath(String filePath) async =>
      filePath == archived.path ? 92 : 91;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QueryRequest {
  const _QueryRequest({required this.page, required this.searchQuery});

  final int page;
  final String searchQuery;

  @override
  bool operator ==(Object other) =>
      other is _QueryRequest &&
      other.page == page &&
      other.searchQuery == searchQuery;

  @override
  int get hashCode => Object.hash(page, searchQuery);
}

class _CountingHistoryState extends ImageGenerationState {
  _CountingHistoryState({required super.history, required super.streamPreview})
    : super(status: GenerationStatus.generating, progress: 0.5);

  int historyReads = 0;

  @override
  List<GeneratedImage> get history {
    historyReads++;
    return super.history;
  }
}

class _FakeImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

class _FakeTagLibraryPageNotifier extends TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() => TagLibraryPageState(
    entries: [
      TagLibraryEntry.create(
        name: '测试资源',
        content: 'long hair',
      ).copyWith(id: 'tag-1'),
    ],
  );
}

class _FakeVibeLibraryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();

  @override
  Future<void> initialize() async {}
}

class _FakePreciseRefLibraryNotifier extends PreciseRefLibraryNotifier {
  @override
  PreciseRefLibraryState build() => const PreciseRefLibraryState();

  @override
  Future<void> initialize() async {}
}
