import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/gallery_database_sandbox.dart';

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_admission_retry_');
  final png = image_lib.encodePng(image_lib.Image(width: 2, height: 2));
  late Directory galleryRoot;
  late _FlakyRepository repository;
  late LocalGalleryServiceImpl service;

  Future<File> writeImage(String name) =>
      File(p.join(galleryRoot.path, name)).writeAsBytes(png);

  setUp(() async {
    galleryRoot = await Directory(
      p.join(sandbox.root.path, 'gallery'),
    ).create();
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imageSavePath, galleryRoot.path);

    // 库与磁盘张数一致且都已解析，初始化不会起后台扫描
    final existing = await writeImage('existing.png');
    await sandbox.dataSource.upsertImage(
      filePath: existing.path,
      fileName: 'existing.png',
      fileSize: png.length,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
      metadataStatus: MetadataStatus.success,
    );

    repository = _FlakyRepository(sandbox.dataSource);
    service = LocalGalleryServiceImpl.withRepository(
      dataSource: sandbox.dataSource,
      filterService: GalleryFilterService(sandbox.dataSource),
      repository: repository,
      admissionRetryDelay: Duration.zero,
    );
    await service.initialize();
    expect(repository.enumerations, 1);
  });

  tearDown(() => service.dispose());

  test('单张写索引的瞬时失败只重试这一张，不重新枚举图库', () async {
    final image = await writeImage('new.png');
    repository.failuresLeft = 1;

    final admission = await service.addNewImageImmediately(image.path);

    expect(admission, GalleryIndexAdmission.added);
    expect(repository.admittedPaths, [image.path, image.path]);
    expect(repository.enumerations, 1);
    expect(service.totalCount, 2);
    expect(await sandbox.dataSource.getImageIdByPath(image.path), isNotNull);
  });

  test('重试后仍失败时报告失败，同样不降级成全量重扫', () async {
    final image = await writeImage('broken.png');
    repository.failuresLeft = 99;

    final admission = await service.addNewImageImmediately(image.path);

    expect(admission, GalleryIndexAdmission.failed);
    expect(repository.admittedPaths, [image.path, image.path]);
    expect(repository.enumerations, 1);
    expect(service.totalCount, 1);
  });

  test('文件不存在时直接失败，不做无意义的重试', () async {
    final admission = await service.addNewImageImmediately(
      p.join(galleryRoot.path, 'missing.png'),
    );

    expect(admission, GalleryIndexAdmission.failed);
    expect(repository.admittedPaths, isEmpty);
    expect(repository.enumerations, 1);
  });
}

class _FlakyRepository extends LocalGalleryRepository {
  _FlakyRepository(GalleryDataSource dataSource)
    : super(dataSource: dataSource);

  int failuresLeft = 0;
  int enumerations = 0;
  final admittedPaths = <String>[];

  @override
  Future<List<File>> findGalleryFiles() {
    enumerations++;
    return super.findGalleryFiles();
  }

  @override
  Future<bool> addImage(File file, {NaiImageMetadata? metadata}) {
    admittedPaths.add(file.path);
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('transient index failure');
    }
    return super.addImage(file, metadata: metadata);
  }
}
