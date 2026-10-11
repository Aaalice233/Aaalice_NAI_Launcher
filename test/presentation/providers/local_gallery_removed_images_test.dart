import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

void main() {
  late _RecordingGalleryService service;

  setUp(() {
    service = _RecordingGalleryService(total: 3);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith(() => _StubGalleryService(service)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  LocalGalleryNotifier notifierOf(ProviderContainer container) =>
      container.read(localGalleryNotifierProvider.notifier);

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

class _PendingGalleryService extends Mock implements LocalGalleryService {
  @override
  bool get isInitialized => false;
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
