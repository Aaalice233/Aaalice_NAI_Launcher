import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/gallery_database_sandbox.dart';
import '../../../helpers/gallery_statistics_probe.dart';

void main() {
  final manager = GalleryCacheManager();
  final sandbox = useGalleryDatabaseSandbox('gallery_stream_scanner_statistics_');
  final statistics = useGalleryStatisticsProbe(
    imageCount: () => sandbox.dataSource.countImages(),
  );
  late IsolateMetadataService metadataService;
  late GalleryStreamScanner scanner;
  late Directory galleryDir;

  setUp(() async {
    galleryDir = await Directory(p.join(sandbox.root.path, 'gallery')).create();
    metadataService = IsolateMetadataService.forTesting();
    scanner = GalleryStreamScanner.forTesting(
      dataSource: sandbox.dataSource,
      metadataService: metadataService,
    );
  });

  tearDown(() async {
    await scanner.dispose();
    metadataService.dispose();
  });

  test('一轮扫描写入多个新文件后只失效一次，之后不再命中旧缓存', () async {
    expect((await manager.getStatistics()).l3DatabaseImageCount, 0);
    await manager.getStatistics();
    expect(statistics.computations, 1);

    // 尺寸不同：扫描器按“大小+修改时间”识别移动，同签名会被当成同一张图
    await _writePng(galleryDir, 'a.png', size: 2);
    await _writePng(galleryDir, 'b.png', size: 3);
    await scanner.startScanning(galleryDir);

    expect(statistics.invalidations, 1);
    final after = await manager.getStatistics();
    expect(statistics.computations, 2);
    expect(after.l3DatabaseImageCount, 2);

    await scanner.startScanning(galleryDir);

    expect(statistics.invalidations, 1);
  });

  test('扫描把消失的文件标记删除后失效一次', () async {
    for (final name in ['gone_a.png', 'gone_b.png']) {
      await sandbox.dataSource.upsertImage(
        filePath: p.join(galleryDir.path, name),
        fileName: name,
        fileSize: 1,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
      );
    }
    expect((await manager.getStatistics()).l3DatabaseImageCount, 2);

    await scanner.startScanning(galleryDir);

    expect(statistics.invalidations, 1);
    expect((await manager.getStatistics()).l3DatabaseImageCount, 0);
  });
}

Future<void> _writePng(Directory dir, String name, {required int size}) async {
  final image = img.Image(width: size, height: size);
  await File(p.join(dir.path, name)).writeAsBytes(img.encodePng(image));
}
