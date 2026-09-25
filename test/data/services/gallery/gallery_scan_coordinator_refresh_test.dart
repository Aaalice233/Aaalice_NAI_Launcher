import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_scan_coordinator.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';

void main() {
  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  late _GatedRepository repository;
  late GalleryScanCoordinator coordinator;
  late List<List<String>> loaded;

  setUp(() {
    final dataSource = GalleryDataSource();
    repository = _GatedRepository(dataSource);
    coordinator = GalleryScanCoordinator(
      dataSource: dataSource,
      repository: repository,
    );
    loaded = [];
  });

  Future<void> refresh() => coordinator.refresh(
    scan: false,
    previousCount: 0,
    onFilesLoaded: (files) async =>
        loaded.add([for (final file in files) file.path]),
  );

  test('在途刷新期间删掉的文件会由尾随刷新移出列表', () async {
    repository.files = ['a.png', 'b.png'];
    final first = refresh();
    await pumpEventQueue();
    expect(repository.pendingListings, 1);

    repository.files = ['a.png'];
    var secondDone = false;
    final second = refresh().then((_) => secondDone = true);
    repository.releaseListing();
    await first;
    await pumpEventQueue();

    expect(loaded, [
      ['a.png', 'b.png'],
    ]);
    expect(secondDone, isFalse, reason: '不能沿用改动前就开始的那轮结果');

    repository.releaseListing();
    await second;
    expect(loaded.last, ['a.png']);
  });

  test('在途期间的多次请求合并为一轮尾随刷新', () async {
    repository.files = ['a.png'];
    final first = refresh();
    await pumpEventQueue();

    final queued = [refresh(), refresh(), refresh()];
    repository.releaseListing();
    await first;
    await pumpEventQueue();
    repository.releaseListing();
    await Future.wait(queued);

    expect(repository.listingCount, 2);
    expect(loaded, hasLength(2));
  });

  test('在途刷新失败时仍执行尾随刷新', () async {
    repository.files = ['a.png'];
    repository.failNextListing = true;
    final first = refresh();
    await pumpEventQueue();
    final second = refresh();

    repository.releaseListing();
    await expectLater(first, throwsA(isA<FileSystemException>()));
    await pumpEventQueue();
    repository.releaseListing();
    await second;

    expect(loaded, [
      ['a.png'],
    ]);
  });

  test('空闲时的刷新各自独立执行', () async {
    repository.files = ['a.png'];
    final first = refresh();
    await pumpEventQueue();
    repository.releaseListing();
    await first;

    repository.files = ['b.png'];
    final second = refresh();
    await pumpEventQueue();
    repository.releaseListing();
    await second;

    expect(loaded, [
      ['a.png'],
      ['b.png'],
    ]);
  });
}

class _GatedRepository extends LocalGalleryRepository {
  _GatedRepository(GalleryDataSource dataSource)
    : super(dataSource: dataSource);

  List<String> files = [];
  bool failNextListing = false;
  int listingCount = 0;
  final _gates = <Completer<void>>[];

  int get pendingListings => _gates.length;

  void releaseListing() => _gates.removeAt(0).complete();

  @override
  Future<List<File>> findGalleryFiles() async {
    listingCount++;
    // 枚举在开始时就看到了磁盘，挂起的只是返回，模拟大目录的慢速 stat。
    final snapshot = [for (final path in files) File(path)];
    final fail = failNextListing;
    failNextListing = false;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    if (fail) throw const FileSystemException('listing failed');
    return snapshot;
  }
}
