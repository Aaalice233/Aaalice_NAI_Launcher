import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_models.dart';
import 'package:nai_launcher/presentation/services/generation_history_storage_service.dart';
import 'package:nai_launcher/presentation/services/stored_image_path_relocator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  late String oldRoot;
  late String newRoot;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('image-path-relocator-');
    oldRoot = p.join(sandbox.path, 'Documents', 'NAI_Launcher', 'images');
    newRoot = p.join(sandbox.path, 'D', 'NAI Launcher', 'images');
    await Directory(oldRoot).create(recursive: true);
    await Directory(newRoot).create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<String> placeMoved(String relative) async {
    final file = File(p.join(newRoot, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);
    return file.path;
  }

  StoredImagePathRelocator relocator() =>
      StoredImagePathRelocator(currentRoot: newRoot, previousRoots: [oldRoot]);

  group('resolve', () {
    test('旧路径的文件已搬到新目录时，换算成新目录下的同一相对位置', () async {
      final moved = await placeMoved(p.join('2026-10-31', 'a.png'));

      expect(
        relocator().resolve(p.join(oldRoot, '2026-10-31', 'a.png')),
        moved,
      );
    });

    test('旧路径的文件仍然存在时不改写', () async {
      final stay = File(p.join(oldRoot, 'stay.png'));
      await stay.writeAsBytes([1]);
      await placeMoved('stay.png');

      expect(relocator().resolve(stay.path), stay.path);
    });

    test('新目录里找不到对应文件时原样返回，不制造指向空文件的路径', () {
      final stored = p.join(oldRoot, '2026-10-31', 'gone.png');

      expect(relocator().resolve(stored), stored);
    });

    test('不在任何旧目录之内的路径不改写', () async {
      await placeMoved('a.png');
      final outside = p.join(sandbox.path, 'elsewhere', 'a.png');

      expect(relocator().resolve(outside), outside);
    });

    test('旧目录与当前目录相同时不处理', () async {
      final same = StoredImagePathRelocator(
        currentRoot: newRoot,
        previousRoots: [newRoot],
      );

      expect(same.previousRoots, isEmpty);
      final stored = p.join(newRoot, 'missing.png');
      expect(same.resolve(stored), stored);
    });

    test('按顺序尝试多个旧目录', () async {
      final other = p.join(sandbox.path, 'other-root');
      final moved = await placeMoved('b.png');
      final multi = StoredImagePathRelocator(
        currentRoot: newRoot,
        previousRoots: [other, oldRoot],
      );

      expect(multi.resolve(p.join(other, 'b.png')), moved);
      expect(multi.resolve(p.join(oldRoot, 'b.png')), moved);
    });
  });

  group('生成历史', () {
    late Directory hiveDirectory;

    setUp(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'history-relocate-',
      );
      Hive.init(hiveDirectory.path);
      await Hive.openBox<dynamic>(StorageKeys.historyBox);
    });

    tearDown(() async {
      await Hive.close();
      if (await hiveDirectory.exists()) {
        await hiveDirectory.delete(recursive: true);
      }
    });

    GeneratedImage image(String id, String? filePath, int byte) {
      return GeneratedImage(
        id: id,
        bytes: Uint8List.fromList([byte, byte + 1, byte + 2]),
        width: 64,
        height: 96,
        createdAt: DateTime.utc(2026, 11, 2, 12, byte),
        filePath: filePath,
      );
    }

    test('只改写搬走了的记录，图片字节、顺序和其余记录保持不变', () async {
      final moved = await placeMoved(p.join('2026-10-31', 'moved.png'));
      final service = GenerationHistoryStorageService();
      final lost = p.join(oldRoot, '2026-10-31', 'lost.png');
      await service.persistImages(
        changedImages: [
          image('moved', p.join(oldRoot, '2026-10-31', 'moved.png'), 3),
          image('lost', lost, 7),
          image('unsaved', null, 11),
        ],
        order: ['moved', 'lost', 'unsaved'],
      );
      await service.flush();

      final fixed = await relocator().repairHistory(service);

      expect(fixed, 1);
      final restored = await service.load();
      expect(restored.map((item) => item.id), ['moved', 'lost', 'unsaved']);
      expect(restored[0].filePath, moved);
      expect(restored[0].bytes, [3, 4, 5]);
      expect(restored[1].filePath, lost);
      expect(restored[2].filePath, isNull);
    });
  });

  group('词库缩略图', () {
    late Directory hiveDirectory;
    late LocalStorageService storage;

    setUp(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'library-relocate-',
      );
      Hive.init(hiveDirectory.path);
      await Hive.openBox<dynamic>(StorageKeys.settingsBox);
      storage = LocalStorageService();
    });

    tearDown(() async {
      await Hive.close();
      if (await hiveDirectory.exists()) {
        await hiveDirectory.delete(recursive: true);
      }
    });

    test('改写搬走了的缩略图，保留条目其他字段与无缩略图的条目', () async {
      final moved = await placeMoved(p.join('2026-10-27', 't.png'));
      final keepPath = p.join(sandbox.path, 'Documents', 'thumb.png');
      await File(keepPath).create(recursive: true);
      await storage.setTagLibraryEntriesJson(
        jsonEncode([
          {
            'id': 'a',
            'name': '司盈炅',
            'thumbnail': p.join(oldRoot, '2026-10-27', 't.png'),
            'thumbnailScale': 1.5,
          },
          {'id': 'b', 'name': '带自有缩略图', 'thumbnail': keepPath},
          {'id': 'c', 'name': '无缩略图'},
        ]),
      );

      final fixed = await relocator().repairTagLibrary(storage);

      expect(fixed, 1);
      final entries = (jsonDecode(storage.getTagLibraryEntriesJson()!) as List)
          .cast<Map<String, dynamic>>();
      expect(entries[0]['thumbnail'], moved);
      expect(entries[0]['name'], '司盈炅');
      expect(entries[0]['thumbnailScale'], 1.5);
      expect(entries[1]['thumbnail'], keepPath);
      expect(entries[2].containsKey('thumbnail'), isFalse);
    });

    test('没有需要修复的条目时不重写存储', () async {
      await storage.setTagLibraryEntriesJson('[{"id":"c","name":"x"}]');

      expect(await relocator().repairTagLibrary(storage), 0);
      expect(storage.getTagLibraryEntriesJson(), '[{"id":"c","name":"x"}]');
    });

    test('记录被替换的保存目录：去重、最近的在前、数量有上限', () async {
      await storage.rememberPreviousImageSavePath('a');
      await storage.rememberPreviousImageSavePath('b');
      await storage.rememberPreviousImageSavePath('a');
      expect(storage.getImageSavePathHistory(), ['a', 'b']);

      for (var i = 0; i < 10; i++) {
        await storage.rememberPreviousImageSavePath('r$i', limit: 3);
      }
      expect(storage.getImageSavePathHistory(), ['r9', 'r8', 'r7']);
    });

    test('repairAll 用默认目录与已记录目录一并修复', () async {
      final moved = await placeMoved('x.png');
      await storage.setTagLibraryEntriesJson(
        jsonEncode([
          {'id': 'a', 'thumbnail': p.join(oldRoot, 'x.png')},
        ]),
      );
      await Hive.openBox<dynamic>(StorageKeys.historyBox);

      await StoredImagePathRelocator.repairAll(
        storage: storage,
        currentRoot: newRoot,
        defaultRoot: oldRoot,
      );

      final entries = jsonDecode(storage.getTagLibraryEntriesJson()!) as List;
      expect((entries.single as Map)['thumbnail'], moved);
    });
  });
}
