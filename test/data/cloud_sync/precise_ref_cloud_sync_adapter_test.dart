import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as image;
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:path/path.dart' as p;

Uint8List _pngBytes() {
  final value = image.Image(width: 16, height: 16);
  image.fill(value, color: image.ColorRgb8(30, 80, 160));
  return Uint8List.fromList(image.encodePng(value));
}

Uint8List _bmpBytes() {
  final value = image.Image(width: 16, height: 16);
  image.fill(value, color: image.ColorRgb8(160, 80, 30));
  return Uint8List.fromList(image.encodeBmp(value));
}

class _FailingPortableRenameFileSystem extends PreciseRefLibraryFileSystem {
  @override
  Future<void> rename(String from, String to) async {
    if (from.contains('.importing-') && to.endsWith('.png')) {
      throw const FileSystemException('injected portable rename failure');
    }
    await super.rename(from, to);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'round-trips stable id and original while excluding thumbnails',
    () async {
      final root = await Directory.systemTemp.createTemp('precise-sync-');
      final images = Directory(p.join(root.path, 'images'));
      Hive.init(p.join(root.path, 'hive'));
      final storage = PreciseRefLibraryStorageService(
        overrideDirectory: images.path,
      );
      addTearDown(() async {
        await storage.close();
        await Hive.close();
        await root.delete(recursive: true);
      });
      final source = await storage.importFromBytes(
        _pngBytes(),
        name: 'portable',
        type: PreciseRefType.character,
        strength: 0.7,
        fidelity: 0.8,
      );
      final adapter = PreciseRefCloudSyncAdapter(storage);
      final exported = (await adapter.exportRecords().toList()).single;
      final chunks = await exported.resource!.openRead().toList();
      final remoteBytes = chunks.expand((chunk) => chunk).toList();
      final remote = PortableSyncRecord(
        adapterId: exported.adapterId,
        id: exported.id,
        kind: exported.kind,
        data: exported.data,
        resource: PortableSyncResource(
          relativePath: exported.resource!.relativePath,
          length: remoteBytes.length,
          openRead: () => Stream.fromIterable([
            remoteBytes.sublist(0, remoteBytes.length ~/ 2),
            remoteBytes.sublist(remoteBytes.length ~/ 2),
          ]),
        ),
      );

      expect(remote.resource!.relativePath, contains('/original'));
      expect(
        remote.resource!.relativePath.toLowerCase(),
        isNot(contains('thumbnail')),
      );
      expect(
        remote.data.values.whereType<String>(),
        isNot(contains(source.imagePath)),
      );
      await storage.deleteEntry(source.id);
      await adapter.preflight([remote]);
      await adapter.apply([remote]);

      final copied = adapter.copyForConflict(
        remote,
        newPortableId: '${remote.id}-copy',
      );
      expect(copied.id, isNot(source.id));
      await adapter.preflight([copied]);
      await adapter.apply([copied]);

      final entries = await storage.getAllEntries();
      expect(
        entries.map((entry) => entry.id),
        containsAll([source.id, copied.id]),
      );
      final restored = entries.firstWhere((entry) => entry.id == source.id);
      expect(restored.id, source.id);
      expect(restored.name, 'portable');
      expect(restored.type, PreciseRefType.character);
      expect(await storage.readImageBytes(restored.id), remoteBytes);
      expect(await storage.getDisplayThumbnail(restored.id), isNotEmpty);
      expect(await storage.readImageBytes(copied.id), remoteBytes);
    },
  );

  test('streams resources beyond the former 64 MiB boundary', () async {
    final root = await Directory.systemTemp.createTemp('precise-large-sync-');
    Hive.init(p.join(root.path, 'hive'));
    final storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(root.path, 'images'),
    );
    addTearDown(() async {
      await storage.close();
      await Hive.close();
      await root.delete(recursive: true);
    });
    const chunkSize = 1024 * 1024;
    const length = 64 * chunkSize + 1;
    final headerChunk = Uint8List(chunkSize)
      ..setAll(0, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    final record = PortableSyncRecord(
      adapterId: 'precise-ref-library',
      id: '11111111-1111-4111-8111-111111111111',
      kind: 'entry',
      data: {
        'name': 'large',
        'type': PreciseRefType.character.name,
        'strength': 1.0,
        'fidelity': 1.0,
        'isFavorite': false,
        'usedCount': 0,
        'lastUsedAt': null,
        'createdAt': DateTime.utc(2025).toIso8601String(),
      },
      resource: PortableSyncResource(
        relativePath:
            'precise-ref/11111111-1111-4111-8111-111111111111/original',
        length: length,
        openRead: () async* {
          yield headerChunk;
          final zeroChunk = Uint8List(chunkSize);
          for (var index = 1; index < 64; index++) {
            yield zeroChunk;
          }
          yield const [0];
        },
      ),
    );
    final adapter = PreciseRefCloudSyncAdapter(storage);

    await adapter.preflight([record]);
    await adapter.apply([record]);

    expect(await storage.getImageLength(record.id), length);
  });

  test('extension replacement removes the old precise-ref file', () async {
    final root = await Directory.systemTemp.createTemp('precise-extension-');
    Hive.init(p.join(root.path, 'hive'));
    final storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(root.path, 'images'),
    );
    addTearDown(() async {
      await storage.close();
      await Hive.close();
      await root.delete(recursive: true);
    });
    final old = await storage.importFromBytes(_bmpBytes(), name: 'old');
    final png = _pngBytes();
    final adapter = PreciseRefCloudSyncAdapter(storage);
    final replacement = PortableSyncRecord(
      adapterId: adapter.id,
      id: old.id,
      kind: 'entry',
      data: {
        'name': 'new',
        'type': PreciseRefType.characterAndStyle.name,
        'strength': 1.0,
        'fidelity': 1.0,
        'isFavorite': false,
        'usedCount': 0,
        'lastUsedAt': null,
        'createdAt': old.createdAt.toUtc().toIso8601String(),
      },
      resource: PortableSyncResource(
        relativePath: 'precise-ref/${old.id}/original',
        length: png.length,
        openRead: () => Stream.value(png),
      ),
    );

    await adapter.apply([replacement]);

    expect(File(old.imagePath).existsSync(), isFalse);
    final replaced = (await storage.getAllEntries()).single;
    expect(p.extension(replaced.imagePath), '.png');
    expect(File(replaced.imagePath).existsSync(), isTrue);
  });

  test('failed precise-ref replacement restores the old file', () async {
    final root = await Directory.systemTemp.createTemp('precise-rollback-');
    Hive.init(p.join(root.path, 'hive'));
    final storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(root.path, 'images'),
      fileSystem: _FailingPortableRenameFileSystem(),
    );
    addTearDown(() async {
      await storage.close();
      await Hive.close();
      await root.delete(recursive: true);
    });
    final old = await storage.importFromBytes(_bmpBytes(), name: 'old');
    final png = _pngBytes();
    final adapter = PreciseRefCloudSyncAdapter(storage);
    final replacement = PortableSyncRecord(
      adapterId: adapter.id,
      id: old.id,
      kind: 'entry',
      data: {
        'name': 'new',
        'type': PreciseRefType.characterAndStyle.name,
        'strength': 1.0,
        'fidelity': 1.0,
        'isFavorite': false,
        'usedCount': 0,
        'lastUsedAt': null,
        'createdAt': old.createdAt.toUtc().toIso8601String(),
      },
      resource: PortableSyncResource(
        relativePath: 'precise-ref/${old.id}/original',
        length: png.length,
        openRead: () => Stream.value(png),
      ),
    );

    await expectLater(
      adapter.apply([replacement]),
      throwsA(isA<FileSystemException>()),
    );

    expect(File(old.imagePath).existsSync(), isTrue);
    expect((await storage.getAllEntries()).single.name, 'old');
    expect(
      Directory(
        p.dirname(old.imagePath),
      ).listSync().whereType<File>().map((file) => file.path),
      everyElement(isNot(contains('.importing-'))),
    );
  });
}
