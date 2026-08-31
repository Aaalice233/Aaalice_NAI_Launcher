import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/utils/display_thumbnail_utils.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:path/path.dart' as p;

Uint8List _pngBytes({int width = 8, int height = 8}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 30, 200));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _jpgBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(10, 200, 90));
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _gifBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(20, 80, 220));
  return Uint8List.fromList(img.encodeGif(image));
}

Uint8List _bmpBytes() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(220, 80, 20));
  return Uint8List.fromList(img.encodeBmp(image));
}

class _FailingRenameFileSystem extends PreciseRefLibraryFileSystem {
  bool failImportCommit = false;
  bool failDeleteStaging = false;

  @override
  Future<void> rename(String from, String to) {
    if (failImportCommit && from.contains('.importing-')) {
      throw FileSystemException('injected import rename failure', from);
    }
    if (failDeleteStaging && to.contains('.deleting-')) {
      throw FileSystemException('injected delete rename failure', from);
    }
    return super.rename(from, to);
  }
}

class _DelayedReadStorage extends PreciseRefLibraryStorageService {
  _DelayedReadStorage({required super.overrideDirectory});

  final Completer<void> readStarted = Completer<void>();
  final Completer<void> continueRead = Completer<void>();

  @override
  Future<Uint8List?> readImageBytes(String id) async {
    final bytes = await super.readImageBytes(id);
    if (!readStarted.isCompleted) {
      readStarted.complete();
    }
    await continueRead.future;
    return bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory imageDir;
  late PreciseRefLibraryStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'precise_ref_storage_test_',
    );
    imageDir = Directory(p.join(tempDir.path, 'images'));
    Hive.init(p.join(tempDir.path, 'hive'));
    storage = PreciseRefLibraryStorageService(overrideDirectory: imageDir.path);
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detectImageExtension 按魔数识别所有支持格式并拒绝未知数据', () {
    expect(
      PreciseRefLibraryStorageService.detectImageExtension(_pngBytes()),
      '.png',
    );
    expect(
      PreciseRefLibraryStorageService.detectImageExtension(_jpgBytes()),
      '.jpg',
    );
    final webp = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF
      0x57, 0x45, 0x42, 0x50, // WEBP
    ]);
    expect(PreciseRefLibraryStorageService.detectImageExtension(webp), '.webp');
    expect(
      PreciseRefLibraryStorageService.detectImageExtension(_gifBytes()),
      '.gif',
    );
    expect(
      PreciseRefLibraryStorageService.detectImageExtension(_bmpBytes()),
      '.bmp',
    );
    expect(
      () => PreciseRefLibraryStorageService.detectImageExtension(
        Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<InvalidPreciseRefImageException>()),
    );
  });

  test('init 幂等：重复调用与 Adapter 重复注册不抛异常', () async {
    await storage.init();
    await storage.init();
    final another = PreciseRefLibraryStorageService(
      overrideDirectory: imageDir.path,
    );
    await another.init();
  });

  test('init 使用 LazyBox 保存缩略图字节', () async {
    await storage.init();
    final cache = Hive.lazyBox<Uint8List>('precise_ref_library_thumbnails_v1');
    expect(cache, isA<LazyBox<Uint8List>>());
  });

  test('importFromBytes 落盘 {id}.png 并可通过 getAllEntries 取回', () async {
    final entry = await storage.importFromBytes(
      _pngBytes(),
      name: '测试参考',
      type: PreciseRefType.style,
      strength: 0.8,
      fidelity: 0.6,
    );

    expect(entry.name, '测试参考');
    expect(entry.type, PreciseRefType.style);
    expect(entry.strength, 0.8);
    expect(entry.fidelity, 0.6);
    expect(p.basename(entry.imagePath), '${entry.id}.png');
    expect(File(entry.imagePath).existsSync(), isTrue);

    final entries = await storage.getAllEntries();
    expect(entries.single.id, entry.id);
  });

  test('importFromBytes 对 JPEG 内容使用 .jpg 扩展名', () async {
    final entry = await storage.importFromBytes(_jpgBytes(), name: 'jpg');
    expect(p.extension(entry.imagePath), '.jpg');
  });

  test('importFromBytes 对 GIF 与 BMP 使用真实扩展名', () async {
    final gif = await storage.importFromBytes(_gifBytes(), name: 'gif');
    final bmp = await storage.importFromBytes(_bmpBytes(), name: 'bmp');

    expect(p.extension(gif.imagePath), '.gif');
    expect(p.extension(bmp.imagePath), '.bmp');
    expect(File(gif.imagePath).readAsBytesSync(), _gifBytes());
    expect(File(bmp.imagePath).readAsBytesSync(), _bmpBytes());
  });

  test('importFromBytes 拒绝损坏图片且不留下条目或文件', () async {
    final corruptPng = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x01,
      0x02,
      0x03,
    ]);
    await expectLater(
      storage.importFromBytes(corruptPng, name: 'bad'),
      throwsA(isA<InvalidPreciseRefImageException>()),
    );

    expect(await storage.getAllEntries(), isEmpty);
    expect(
      await imageDir.list().where((entity) => entity is File).toList(),
      isEmpty,
    );
  });

  test('导入提交重命名失败时回滚元数据和暂存文件', () async {
    final fileSystem = _FailingRenameFileSystem()..failImportCommit = true;
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: imageDir.path,
      fileSystem: fileSystem,
    );

    await expectLater(
      storage.importFromBytes(_pngBytes(), name: 'rollback'),
      throwsA(isA<FileSystemException>()),
    );

    expect(await storage.getAllEntries(), isEmpty);
    expect(
      await imageDir.list().where((entity) => entity is File).toList(),
      isEmpty,
    );
  });

  test('importFromBytes 空名称回退为 id 前缀', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: '   ');
    expect(entry.name, entry.id.substring(0, 8));
  });

  test('updateEntry 仅更新元数据，不改动磁盘文件', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');
    final originalBytes = File(entry.imagePath).readAsBytesSync();

    final updated = await storage.updateEntry(
      entry.id,
      name: 'b',
      type: PreciseRefType.character,
      strength: 0.5,
      fidelity: 0.4,
    );

    expect(updated!.name, 'b');
    expect(updated.type, PreciseRefType.character);
    expect(updated.strength, 0.5);
    expect(updated.fidelity, 0.4);
    expect(updated.imagePath, entry.imagePath);
    expect(File(entry.imagePath).readAsBytesSync(), originalBytes);

    // 空名称不覆盖原名
    final kept = await storage.updateEntry(entry.id, name: '  ');
    expect(kept!.name, 'b');
  });

  test('deleteEntry 移除元数据、缩略图缓存与磁盘文件', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');
    expect(File(entry.imagePath).existsSync(), isTrue);

    final removed = await storage.deleteEntry(entry.id);

    expect(removed, isTrue);
    expect(
      (await storage.getAllEntries()).where((item) => item.id == entry.id),
      isEmpty,
    );
    expect(File(entry.imagePath).existsSync(), isFalse);
    expect(await storage.getDisplayThumbnail(entry.id), isNull);
    expect(await storage.deleteEntry(entry.id), isFalse);
  });

  test('原图无法暂存时删除失败并保留条目与文件', () async {
    final fileSystem = _FailingRenameFileSystem();
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: imageDir.path,
      fileSystem: fileSystem,
    );
    final entry = await storage.importFromBytes(_pngBytes(), name: 'keep');
    fileSystem.failDeleteStaging = true;

    expect(await storage.deleteEntry(entry.id), isFalse);
    expect(
      (await storage.getAllEntries()).singleWhere(
        (item) => item.id == entry.id,
      ),
      entry,
    );
    expect(File(entry.imagePath).existsSync(), isTrue);
  });

  test('删除与缩略图生成并发时不会重新写回孤立缓存', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'race');
    final cache = Hive.lazyBox<Uint8List>('precise_ref_library_thumbnails_v1');
    await cache.delete(entry.id);

    // 用冷内存实例发起读取，绕开导入时预热的内存缓存，强制走生成路径
    final delayed = _DelayedReadStorage(overrideDirectory: imageDir.path);
    storage = delayed;
    final thumbnailLoad = delayed.getDisplayThumbnail(entry.id);
    await delayed.readStarted.future;
    final deletion = delayed.deleteEntry(entry.id);
    await Future<void>.delayed(Duration.zero);
    delayed.continueRead.complete();

    expect(await deletion, isTrue);
    expect(await thumbnailLoad, isNull);
    expect(await cache.get(entry.id), isNull);
    expect(delayed.peekDisplayThumbnail(entry.id), isNull);
  });

  test('启动对账恢复被中断的删除并清理孤立原图与缓存', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'recover');
    final cache = Hive.lazyBox<Uint8List>('precise_ref_library_thumbnails_v1');
    await cache.put('orphan-cache', _pngBytes());

    final tombstone = '${entry.imagePath}.deleting-crash';
    await File(entry.imagePath).rename(tombstone);
    final orphanFile = File(
      p.join(imageDir.path, '11111111-1111-4111-8111-111111111111.png'),
    );
    await orphanFile.writeAsBytes(_pngBytes(), flush: true);
    await storage.close();

    storage = PreciseRefLibraryStorageService(overrideDirectory: imageDir.path);
    await storage.init();

    expect(File(entry.imagePath).existsSync(), isTrue);
    expect(File(tombstone).existsSync(), isFalse);
    expect(orphanFile.existsSync(), isFalse);
    expect(
      await Hive.lazyBox<Uint8List>(
        'precise_ref_library_thumbnails_v1',
      ).get('orphan-cache'),
      isNull,
    );
  });

  test('toggleFavorite 与 recordUsage 持久化更新', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');

    final favored = await storage.toggleFavorite(entry.id);
    expect(favored!.isFavorite, isTrue);

    final used = await storage.recordUsage(entry.id);
    expect(used!.usedCount, 1);
    expect(used.lastUsedAt, isNotNull);

    final reloaded = (await storage.getAllEntries()).singleWhere(
      (item) => item.id == entry.id,
    );
    expect(reloaded.isFavorite, isTrue);
    expect(reloaded.usedCount, 1);
  });

  test('getDisplayThumbnail 小图直接返回原字节', () async {
    final bytes = _pngBytes();
    final entry = await storage.importFromBytes(bytes, name: 'a');
    final thumbnail = await storage.getDisplayThumbnail(entry.id);
    expect(thumbnail, bytes);
  });

  test('peekDisplayThumbnail 入库或读取后同步命中，删除后失效', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');
    expect(storage.peekDisplayThumbnail(entry.id), isNotNull);

    final other = PreciseRefLibraryStorageService(
      overrideDirectory: imageDir.path,
    );
    expect(other.peekDisplayThumbnail(entry.id), isNull);
    final loaded = await other.getDisplayThumbnail(entry.id);
    expect(other.peekDisplayThumbnail(entry.id), loaded);

    await storage.deleteEntry(entry.id);
    expect(storage.peekDisplayThumbnail(entry.id), isNull);
  });

  test('readImageBytes 在原图文件被删除后返回 null', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');
    File(entry.imagePath).deleteSync();
    expect(await storage.readImageBytes(entry.id), isNull);
  });

  test('DisplayThumbnailUtils.resizeSync 把大图压到最长边 256', () {
    final large = _pngBytes(width: 512, height: 384);
    final resized = DisplayThumbnailUtils.resizeSync(large);
    final decoded = img.decodeImage(resized!);
    expect(decoded!.width, DisplayThumbnailUtils.maxDimension);
    expect(
      decoded.height,
      lessThanOrEqualTo(DisplayThumbnailUtils.maxDimension),
    );
  });
}
