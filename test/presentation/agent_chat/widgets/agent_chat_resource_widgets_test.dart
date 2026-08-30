import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_resource_widgets.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

void main() {
  for (final width in [320.0, 840.0]) {
    testWidgets(
      'local reference gallery reaches history and searches the complete library at ${width.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
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
  const _TestApp({required this.galleryOverride, required this.onSelected});

  final _FakeLocalGalleryNotifier Function() galleryOverride;
  final Future<void> Function(AgentChatResourceReference) onSelected;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        localGalleryNotifierProvider.overrideWith(galleryOverride),
        imageGenerationNotifierProvider.overrideWith(
          _FakeImageGenerationNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              onPressed: () {
                AgentChatResourcePicker.showReferenceGallery(
                  context: context,
                  ref: ref,
                  onSelected: onSelected,
                );
              },
              child: const Text('open'),
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

class _FakeImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}
