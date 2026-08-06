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
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: imageDir.path,
    );
  });

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detectImageExtension 按魔数识别 PNG/JPEG/WebP，未知回退 PNG', () {
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
      PreciseRefLibraryStorageService.detectImageExtension(
        Uint8List.fromList([1, 2, 3]),
      ),
      '.png',
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
    expect(await storage.getEntry(entry.id), isNull);
    expect(File(entry.imagePath).existsSync(), isFalse);
    expect(await storage.getDisplayThumbnail(entry.id), isNull);
    expect(await storage.deleteEntry(entry.id), isFalse);
  });

  test('toggleFavorite 与 recordUsage 持久化更新', () async {
    final entry = await storage.importFromBytes(_pngBytes(), name: 'a');

    final favored = await storage.toggleFavorite(entry.id);
    expect(favored!.isFavorite, isTrue);

    final used = await storage.recordUsage(entry.id);
    expect(used!.usedCount, 1);
    expect(used.lastUsedAt, isNotNull);

    final reloaded = await storage.getEntry(entry.id);
    expect(reloaded!.isFavorite, isTrue);
    expect(reloaded.usedCount, 1);
  });

  test('getDisplayThumbnail 小图直接返回原字节', () async {
    final bytes = _pngBytes();
    final entry = await storage.importFromBytes(bytes, name: 'a');
    final thumbnail = await storage.getDisplayThumbnail(entry.id);
    expect(thumbnail, bytes);
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
    expect(decoded.height, lessThanOrEqualTo(DisplayThumbnailUtils.maxDimension));
  });
}
