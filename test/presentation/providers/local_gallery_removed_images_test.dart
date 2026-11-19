import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_screen_controller.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';

import '../../helpers/gallery_folder_notifications.dart';

void main() {
  late _RecordingGalleryService service;
  late RecordingGalleryFolders folders;

  setUp(() {
    service = _RecordingGalleryService(total: 3);
    folders = RecordingGalleryFolders();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        galleryCategoryNotifierProvider.overrideWith(() => folders),
        galleryServiceProvider.overrideWith(() => _StubGalleryService(service)),
      ],
    );
    addTearDown(container.dispose);
    final sidebar = container.listen(
      galleryCategoryNotifierProvider,
      (_, next) {},
    );
    addTearDown(sidebar.close);
    return container;
  }

  LocalGalleryNotifier notifierOf(ProviderContainer container) =>
      container.read(localGalleryNotifierProvider.notifier);

  for (final (background, from, to) in [
    ('收录', 0, 1),
    ('刷新', 0, 1),
    ('收录', 1, 0),
  ]) {
    test('翻到第 ${to + 1} 页期间后台$background 会重读用户请求的页', () async {
      final paged = _PagedGalleryService(51);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      if (from != 0) await notifier.loadPage(from);
      paged.loadedPages.clear();
      final oldPage = paged.records.skip(to * 50).take(50).toList();
      final pending = paged.nextPage = Completer<List<LocalImageRecord>>();
      final started = paged.pageStarted = Completer<void>();
      final turn = to == 1
          ? notifier.loadNextPage()
          : notifier.loadPreviousPage();
      try {
        await started.future;
        final added = paged.records.first.copyWith(path: 'gallery/new.png');
        paged.records.insert(0, added);
        if (background == '收录') {
          await notifier.addNewlySavedImages([added.path]);
        } else {
          await notifier.refresh(scan: false);
        }
      } finally {
        pending.complete(oldPage);
      }
      await turn;
      final after = await notifier.settledPage();
      expect(paged.loadedPages, [to, to]);
      expect(after.currentPage, to);
      expect(
        after.currentImages,
        paged.records.skip(to * 50).take(50).toList(),
      );
    });
  }

  group('removeDeletedImages', () {
    test('页面已初始化时直接移除、更新计数并重取当前页，不重新枚举目录', () async {
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      service.loadedPages.clear();

      await notifier.removeDeletedImages([r'G:\gallery\a.png']);

      expect(service.removed, [
        [r'G:\gallery\a.png'],
      ]);
      expect(service.refreshCalls, 0);
      expect(folders.notifications, service.removed);
      expect(service.loadedPages, [0]);
      expect(container.read(localGalleryNotifierProvider).totalCount, 2);
    });

    test('没有移除任何跟踪文件时不重取页面', () async {
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      service.loadedPages.clear();
      service.removableCount = 0;

      await notifier.removeDeletedImages([r'G:\gallery\unknown.png']);

      expect(service.loadedPages, isEmpty);
      expect(container.read(localGalleryNotifierProvider).totalCount, 3);
    });

    for (final index in [17, 49, 50]) {
      test('51 张中删除第 ${index + 1} 张，按更新后的顺序重取整页', () async {
        final paged = _PagedGalleryService(51);
        service = paged;
        final original = [...paged.records];
        final container = createContainer();
        final notifier = notifierOf(container);
        await notifier.initialize();
        if (index == 50) await notifier.loadPage(1);
        await notifier.removeDeletedImages([original[index].path]);

        final state = container.read(localGalleryNotifierProvider);
        expect(state.currentImages, original..removeAt(index));
        expect(state.currentPage, 0);
        expect(state.totalCount, 50);
        expect(state.filteredCount, 50);
        expect(state.totalPages, 1);
        expect(paged.refreshCalls, 0);
      });
    }

    test('清空筛选结果时保留范围外的图片', () async {
      final paged = _PagedGalleryService(4);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      await notifier.setSearchQuery('2.png');
      final before = container.read(localGalleryNotifierProvider);
      expect(before.currentImages.single.path, endsWith('2.png'));
      paged.failRead = true;
      await notifier.removeDeletedImages([before.currentImages.single.path]);
      final after = container.read(localGalleryNotifierProvider);
      expect(after.currentImages, isEmpty);
      expect(after.filteredCount, 0);
      expect(after.totalCount, 3);
      expect(after.hasFilters, isTrue);
      expect(after.error, isNull);
    });

    test('迟到的旧页不能恢复已删除的图，索引失败仍重取当前页', () async {
      final paged = _PagedGalleryService(51);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      final stale = [paged.records.last];
      final pending = paged.nextPage = Completer<List<LocalImageRecord>>();
      final started = paged.pageStarted = Completer<void>();
      final previous = notifier.loadPage(1);
      await started.future;
      paged.failMark = true;
      await expectLater(
        notifier.removeDeletedImages([stale.single.path]),
        throwsStateError,
      );
      pending.complete(stale);
      await previous;
      final after = container.read(localGalleryNotifierProvider);
      expect(after.currentPage, 0);
      expect(after.currentImages, paged.records);
      expect(after.totalCount, 50);
      expect(after.isLoading, isFalse);
      expect(folders.notifications, [
        [stale.single.path],
      ]);
    });

    test('索引无法重读时也从已有页排除消失的路径', () async {
      final paged = _PagedGalleryService(3);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      paged.failRead = true;
      await expectLater(
        notifier.removeDeletedImages([paged.records[1].path]),
        throwsStateError,
      );
      expect(
        container.read(localGalleryNotifierProvider).currentImages,
        paged.records,
      );
    });

    test('删除等待后台收录替换的首页，查看器拿到已生效的列表', () async {
      final paged = _PagedGalleryService(3);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      final oldPage = [...paged.records];
      final oldRead = paged.nextPage = Completer<List<LocalImageRecord>>();
      final oldStarted = paged.pageStarted = Completer<void>();
      var deletionDone = false;
      final deletion = notifier
          .removeDeletedImages([oldPage[1].path])
          .then((_) => deletionDone = true);
      await oldStarted.future;
      final latestRead = paged.nextPage = Completer<List<LocalImageRecord>>();
      final latestStarted = paged.pageStarted = Completer<void>();
      final added = oldPage.first.copyWith(path: 'gallery/new.png');
      paged.records.insert(0, added);
      final admission = notifier.addNewlySavedImages([added.path]);
      await latestStarted.future;
      final snapshot = notifier.settledPage();
      oldRead.complete(oldPage);
      await pumpEventQueue();
      expect(deletionDone, isFalse);
      latestRead.complete([...paged.records]);
      await admission;
      await deletion;
      expect((await snapshot).currentImages, [
        added,
        oldPage.first,
        oldPage.last,
      ]);
      expect(
        container.read(localGalleryNotifierProvider).currentImages,
        (await snapshot).currentImages,
      );
    });

    test('删除末页唯一图片时读失败保留五十张计数，重试回到第一页', () async {
      final paged = _PagedGalleryService(51);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      await notifier.loadPage(1);
      paged.failRead = true;
      await expectLater(
        notifier.removeDeletedImages([paged.records.last.path]),
        throwsStateError,
      );
      final failed = await notifier.settledPage();
      expect(failed.totalCount, 50);
      expect(failed.totalPages, 1);
      expect(failed.currentPage, 0);
      expect(failed.currentImages, isEmpty);
      expect(failed.error?.code, LocalGalleryErrorCode.databaseFailed);
      paged.failRead = false;
      await notifier.loadPage(failed.currentPage);
      final restored = await notifier.settledPage();
      expect(restored.currentImages, paged.records);
      expect(restored.error, isNull);
    });

    testWidgets('连续 PageDown 和 PageUp 按待加载页推进，迟到结果不回退', (tester) async {
      final paged = _PagedGalleryService(101);
      final container = ProviderContainer(
        overrides: [
          galleryServiceProvider.overrideWith(() => _StubGalleryService(paged)),
          shortcutConfigNotifierProvider.overrideWith(_DefaultShortcuts.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = notifierOf(container);
      LocalGalleryScreenController? controller;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                controller ??= LocalGalleryScreenController(
                  ref: ref,
                  context: () => context,
                  mounted: () => context.mounted,
                  groupedGridViewKey: GlobalKey(),
                  actions: LocalGalleryActionCoordinator(
                    ref: ref,
                    context: () => context,
                    mounted: () => context.mounted,
                  ),
                );
                return PageShortcuts(
                  contextType: ShortcutContext.gallery,
                  shortcuts: controller!.shortcuts,
                  child: const Scaffold(),
                );
              },
            ),
          ),
        ),
      );
      addTearDown(controller!.dispose);
      final ready = notifier.initialize();
      await tester.pump(Duration.zero);
      await ready;
      await tester.pump();
      for (final (key, from, to) in [
        (LogicalKeyboardKey.pageDown, 0, 2),
        (LogicalKeyboardKey.pageUp, 2, 0),
      ]) {
        final slow = paged.nextPage = Completer<List<LocalImageRecord>>();
        final started = paged.pageStarted = Completer<void>();
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(started.isCompleted, isTrue);
        expect(container.read(localGalleryNotifierProvider).currentPage, from);
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(container.read(localGalleryNotifierProvider).currentPage, to);
        slow.complete(paged.records.skip(50).take(50).toList());
        await tester.pump();
        final state = container.read(localGalleryNotifierProvider);
        expect(state.currentPage, to);
        expect(state.currentImages.first, paged.records[to * 50]);
      }
    });

    test('旧日期分组的第二批迟到不能写回首批已删图片', () async {
      final paged = _PagedGalleryService(102);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      final staleTail = paged.records.skip(100).toList();
      paged.gatedPage = 1;
      final slow = paged.nextPage = Completer<List<LocalImageRecord>>();
      final started = paged.pageStarted = Completer<void>();
      final grouping = notifier.setGroupedView(true);
      await started.future;
      await notifier.removeDeletedImages([paged.records[2].path]);
      expect(
        container.read(localGalleryNotifierProvider).groupedImages,
        paged.records,
      );
      slow.complete(staleTail);
      await grouping;
      final state = container.read(localGalleryNotifierProvider);
      expect(state.groupedImages, paged.records);
      expect(state.isGroupedLoading, isFalse);
    });

    test('索引清理过程中完成的旧翻页不改变正在查看的页', () async {
      final paged = _PagedGalleryService(101);
      service = paged;
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.initialize();
      final stale = paged.records.skip(50).take(50).toList();
      final next = paged.nextPage = Completer<List<LocalImageRecord>>();
      final started = paged.pageStarted = Completer<void>();
      final previous = notifier.loadPage(1);
      await started.future;

      final mark = paged.pendingMark = Completer<void>();
      final deletion = notifier.removeDeletedImages([paged.records[17].path]);
      next.complete(stale);
      await previous;
      expect(container.read(localGalleryNotifierProvider).currentPage, 0);
      mark.complete();
      await deletion;

      final state = container.read(localGalleryNotifierProvider);
      expect(state.currentImages, paged.records.take(50).toList());
      expect(state.currentPage, 0);
      expect(state.totalPages, 2);
    });

    test('服务就绪前的删除在就绪后补做，并取消同一路径待补收录的新图', () async {
      final container = createContainer();
      final notifier = notifierOf(container);

      await notifier.addNewlySavedImages([
        r'G:\gallery\a.png',
        r'G:\gallery\b.png',
      ]);
      await notifier.removeDeletedImages([r'G:\gallery\a.png']);
      expect(service.removed, isEmpty);

      await notifier.initialize();

      expect(service.admitted, [r'G:\gallery\b.png']);
      expect(folders.notifications, [service.admitted, ...service.removed]);
      expect(service.removed, [
        [r'G:\gallery\a.png'],
      ]);
    });
  });

  group('refresh before the page is initialized', () {
    test('共享服务已被别处初始化时仍重新读取磁盘', () async {
      final container = createContainer();
      final notifier = notifierOf(container);
      await notifier.isFavorite(r'G:\gallery\a.png');
      expect(
        container.read(localGalleryNotifierProvider).isInitialized,
        isFalse,
      );

      await notifier.refresh();

      expect(service.refreshCalls, 1);
      expect(
        container.read(localGalleryNotifierProvider).isInitialized,
        isTrue,
      );
    });

    test('服务本次才初始化时只做初始化，不重复枚举', () async {
      final container = createContainer();

      await notifierOf(container).refresh();

      expect(service.refreshCalls, 0);
      expect(
        container.read(localGalleryNotifierProvider).isInitialized,
        isTrue,
      );
    });
  });
}

class _RecordingGalleryService extends Mock implements LocalGalleryService {
  _RecordingGalleryService({required int total}) : _total = total;

  int _total;
  int removableCount = 1;
  int refreshCalls = 0;
  final admitted = <String>[];
  final removed = <List<String>>[];
  final loadedPages = <int>[];

  @override
  bool get isInitialized => true;

  @override
  int get totalCount => _total;

  @override
  int get filteredCount => _total;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  @override
  Future<GalleryIndexAdmission> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) async {
    admitted.add(filePath);
    return GalleryIndexAdmission.added;
  }

  @override
  Future<int> removeDeletedImagesImmediately(List<String> filePaths) async {
    removed.add(filePaths);
    _total -= removableCount;
    return removableCount;
  }

  @override
  Future<void> refresh({bool scan = true}) async => refreshCalls++;

  @override
  Future<void> applyFilter(FilterCriteria criteria) async {}

  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    loadedPages.add(page);
    return const <LocalImageRecord>[];
  }

  @override
  Future<bool> isFavorite(String filePath) async => false;

  @override
  Future<void> dispose() async {}
}

class _DefaultShortcuts extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _PendingGalleryService extends Mock implements LocalGalleryService {
  @override
  bool get isInitialized => false;
}

class _PagedGalleryService extends _RecordingGalleryService {
  _PagedGalleryService(int count)
    : records = List.generate(
        count,
        (index) => LocalImageRecord(
          path: 'gallery/$index.png',
          size: index,
          modifiedAt: DateTime(2026),
        ),
      ),
      super(total: count);

  final List<LocalImageRecord> records;
  FilterCriteria filter = const FilterCriteria();
  Completer<List<LocalImageRecord>>? nextPage;
  int? gatedPage;
  Completer<void>? pageStarted;
  Completer<void>? pendingMark;
  bool failMark = false;
  bool failRead = false;
  Iterable<LocalImageRecord> get matching =>
      records.where((record) => record.path.contains(filter.searchQuery));

  @override
  int get totalCount => records.length;
  @override
  int get filteredCount => matching.length;
  @override
  FilterCriteria get currentFilter => filter;
  @override
  Future<void> applyFilter(FilterCriteria criteria) async => filter = criteria;

  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async {
    loadedPages.add(page);
    if (nextPage case final pending?
        when gatedPage == null || page == gatedPage) {
      nextPage = null;
      pageStarted!.complete();
      return pending.future;
    }
    if (failRead) throw StateError('page unavailable');
    return matching.skip(page * pageSize!).take(pageSize).toList();
  }

  @override
  Future<int> removeDeletedImagesImmediately(List<String> filePaths) async {
    final before = records.length;
    records.removeWhere((record) => filePaths.contains(record.path));
    if (pendingMark case final pending?) await pending.future;
    if (failMark) throw StateError('mark failed');
    return before - records.length;
  }
}

class _StubGalleryService extends GalleryService {
  _StubGalleryService(this.service);

  final LocalGalleryService service;
  Future<void>? _initialization;

  @override
  LocalGalleryService build() => _PendingGalleryService();

  @override
  Future<void> ensureInitialized() =>
      _initialization ??= Future(() => state = service);
}
