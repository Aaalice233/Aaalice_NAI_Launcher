import 'dart:async';

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
    service = _RecordingGalleryService();
  });

  ProviderContainer createContainer({Future<void>? gate}) {
    final container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith(
          () => _StubGalleryService(service, gate: gate),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  LocalGalleryNotifier notifierOf(ProviderContainer container) =>
      container.read(localGalleryNotifierProvider.notifier);

  test('空路径列表不产生任何索引动作', () async {
    final container = createContainer();

    final admission = await notifierOf(container).addNewlySavedImages([]);

    expect(admission, GalleryIndexAdmission.alreadyIndexed);
    expect(admission.requiresFullRescan, isFalse);
    expect(service.admitted, isEmpty);
  });

  test('底层服务已就绪时，页面未初始化也即时收录新图', () async {
    final container = createContainer();
    final notifier = notifierOf(container);

    await notifier.isFavorite(r'G:\gallery\old.png');
    expect(container.read(localGalleryNotifierProvider).isInitialized, isFalse);

    final admission = await notifier.addNewlySavedImages([
      r'G:\gallery\new.png',
    ]);

    expect(admission, GalleryIndexAdmission.added);
    expect(service.admitted, [r'G:\gallery\new.png']);
    expect(service.loadedPages, isEmpty);
    expect(container.read(localGalleryNotifierProvider).totalCount, 1);
  });

  test('服务初始化在途时保存的新图，在服务就绪后补收录', () async {
    final gate = Completer<void>();
    final container = createContainer(gate: gate.future);
    final notifier = notifierOf(container);

    final favorite = notifier.isFavorite(r'G:\gallery\old.png');
    await Future<void>.delayed(Duration.zero);

    final admission = await notifier.addNewlySavedImages([
      r'G:\gallery\new.png',
    ]);

    expect(admission, GalleryIndexAdmission.deferred);
    expect(service.admitted, isEmpty);

    gate.complete();
    await favorite;

    expect(service.admitted, [r'G:\gallery\new.png']);
  });

  test('服务与页面都未初始化时保存的新图，首次初始化后不会丢', () async {
    final container = createContainer();
    final notifier = notifierOf(container);

    final admission = await notifier.addNewlySavedImages([
      r'G:\gallery\new.png',
    ]);

    expect(admission, GalleryIndexAdmission.deferred);
    expect(service.admitted, isEmpty);

    await notifier.initialize();

    expect(service.admitted, [r'G:\gallery\new.png']);
    expect(container.read(localGalleryNotifierProvider).totalCount, 1);

    await notifier.isFavorite(r'G:\gallery\new.png');

    expect(service.admitted, [r'G:\gallery\new.png']);
  });

  test('页面已初始化的常规路径仍即时收录并重取首页', () async {
    final container = createContainer();
    final notifier = notifierOf(container);

    await notifier.initialize();
    expect(container.read(localGalleryNotifierProvider).isInitialized, isTrue);
    expect(service.loadedPages, [0]);

    final admission = await notifier.addNewlySavedImages([
      r'G:\gallery\new.png',
    ]);

    expect(admission, GalleryIndexAdmission.added);
    expect(service.admitted, [r'G:\gallery\new.png']);
    expect(service.loadedPages, [0, 0]);
  });
}

class _RecordingGalleryService extends Mock implements LocalGalleryService {
  final List<String> admitted = <String>[];
  final List<int> loadedPages = <int>[];
  int _totalCount = 0;

  @override
  bool get isInitialized => true;

  @override
  int get totalCount => _totalCount;

  @override
  int get filteredCount => _totalCount;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  @override
  Future<GalleryIndexAdmission> addNewImageImmediately(
    String filePath, {
    NaiImageMetadata? metadata,
  }) async {
    admitted.add(filePath);
    _totalCount++;
    return GalleryIndexAdmission.added;
  }

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
  _StubGalleryService(this.service, {this.gate});

  final LocalGalleryService service;
  final Future<void>? gate;
  Future<void>? _initialization;

  @override
  LocalGalleryService build() => _PendingGalleryService();

  @override
  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final pending = gate;
    if (pending != null) await pending;
    state = service;
  }
}
