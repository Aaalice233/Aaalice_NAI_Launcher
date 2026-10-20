import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:path/path.dart' as p;

import '../../helpers/gallery_database_sandbox.dart';

void main() {
  final sandbox = useGalleryDatabaseSandbox('local_gallery_full_scan_');

  setUp(() async {
    final galleryDir = await Directory(
      p.join(sandbox.root.path, 'gallery'),
    ).create();
    final settings = await Hive.openBox<dynamic>(StorageKeys.settingsBox);
    await settings.put(StorageKeys.imageSavePath, galleryDir.path);
    GalleryStreamScanner.resetInstance();
    GalleryStreamScanner.instance(dataSource: sandbox.dataSource);
  });

  tearDown(() {
    GalleryStreamScanner.resetInstance();
    IsolateMetadataService.instance.dispose();
  });

  test('分组视图下重建索引后重载分组列表', () async {
    final service = _IndexedGalleryService();
    final container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith(
          () => _ReadyGalleryService(service),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(localGalleryNotifierProvider.notifier);
    await notifier.initialize();
    await notifier.setGroupedView(true);
    expect(container.read(localGalleryNotifierProvider).groupedImages, isEmpty);

    final indexed = LocalImageRecord(
      path: r'G:\gallery\indexed.png',
      size: 0,
      modifiedAt: DateTime(2026),
    );
    service.records.add(indexed);
    await notifier.performFullScan();

    final state = container.read(localGalleryNotifierProvider);
    expect(state.error, isNull);
    expect(state.groupedImages.map((record) => record.path), [indexed.path]);
  });
}

class _IndexedGalleryService extends Mock implements LocalGalleryService {
  final records = <LocalImageRecord>[];

  @override
  bool get isInitialized => true;

  @override
  int get totalCount => records.length;

  @override
  int get filteredCount => records.length;

  @override
  FilterCriteria get currentFilter => const FilterCriteria();

  @override
  Future<List<LocalImageRecord>> getPage(int page, {int? pageSize}) async =>
      page == 0 ? List.of(records) : const <LocalImageRecord>[];

  @override
  Future<void> dispose() async {}
}

class _ReadyGalleryService extends GalleryService {
  _ReadyGalleryService(this.service);

  final LocalGalleryService service;

  @override
  LocalGalleryService build() => service;

  @override
  Future<void> ensureInitialized() async {}
}
