import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_archive_service.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:path/path.dart' as p;

import '../../helpers/shared_compute_gate.dart';

class _FailingCommitStorage extends PreciseRefLibraryStorageService {
  var imports = 0;
  final deletedIds = <String>[];

  @override
  Future<PreciseRefLibraryEntry> importPortableEntryStream(
    Stream<List<int>> bytes, {
    required int expectedLength,
    required String id,
    required String name,
    required PreciseRefType type,
    required double strength,
    required double fidelity,
    required bool isFavorite,
    required int usedCount,
    required DateTime? lastUsedAt,
    required DateTime createdAt,
  }) async {
    if (imports++ == 1) throw const FileSystemException('commit failed');
    return PreciseRefLibraryEntry(
      id: id,
      name: name,
      imagePath: '$id.png',
      typeIndex: type.index,
      strength: strength,
      fidelity: fidelity,
      isFavorite: isFavorite,
      usedCount: usedCount,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }

  @override
  Future<bool> deleteEntry(String id) async {
    deletedIds.add(id);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late PreciseRefLibraryStorageService storage;
  late PreciseRefLibraryArchiveService archives;
  late Directory stagingRoot;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('precise_ref_archive_');
    Hive.init(p.join(tempDir.path, 'hive'));
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(tempDir.path, 'images'),
    );
    stagingRoot = Directory(p.join(tempDir.path, 'staging'));
    archives = PreciseRefLibraryArchiveService(
      storage,
      stagingRootPath: stagingRoot.path,
    );
  });

  Future<void> expectNoStagingLeft() async {
    expect(await stagingRoot.list().toList(), isEmpty);
  }

  tearDown(() async {
    await storage.close();
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('配置包往返保留配置并以新 UUID 导入副本', () async {
    final source = await storage.importFromBytes(
      _pngBytes(),
      name: '参考图',
      type: PreciseRefType.style,
      strength: 0.65,
      fidelity: 0.35,
    );
    await storage.updateEntry(source.id, isFavorite: true);
    await storage.recordUsage(source.id);
    final exported = (await storage.getAllEntries()).single;
    final path = p.join(tempDir.path, 'refs.naipreciseref');

    await archives.exportToPath(entries: [exported], outputPath: path);
    final imported = (await archives.importFromPath(path)).single;

    expect(imported.id, isNot(source.id));
    expect(imported.name, source.name);
    expect(imported.type, PreciseRefType.style);
    expect(imported.strength, 0.65);
    expect(imported.fidelity, 0.35);
    expect(imported.isFavorite, isTrue);
    expect(imported.usedCount, 1);
    expect(await File(imported.imagePath).readAsBytes(), _pngBytes());

    final duplicate = (await archives.importFromPath(path)).single;
    expect(duplicate.id, isNot(anyOf(source.id, imported.id)));
    expect(await storage.getAllEntries(), hasLength(3));
    await expectNoStagingLeft();
  });

  test('解压与校验经过共享计算闸门在后台完成', () async {
    final path = await _writeArchive(
      tempDir,
      resource: 'images/11111111-1111-4111-8111-111111111111.png',
      fileName: 'gated.naipreciseref',
    );

    final imported = await expectQueuedBehindSharedComputeGate(
      () => archives.importFromPath(path),
    );

    expect(imported.single.name, 'source');
    expect(await File(imported.single.imagePath).readAsBytes(), _pngBytes());
    await expectNoStagingLeft();
  });

  test('后台预检保留原有错误类型且不留暂存文件', () async {
    final notImage = await _writeArchive(
      tempDir,
      resource: 'images/11111111-1111-4111-8111-111111111111.png',
      fileName: 'not-image.naipreciseref',
      resourceBytes: Uint8List.fromList(utf8.encode('not an image')),
    );
    await expectLater(
      archives.importFromPath(notImage),
      throwsA(isA<InvalidPreciseRefImageException>()),
    );

    final notZip = File(p.join(tempDir.path, 'not-zip.naipreciseref'));
    await notZip.writeAsBytes(utf8.encode('plain text'));
    await expectLater(
      archives.importFromPath(notZip.path),
      throwsA(isA<FormatException>()),
    );

    await expectLater(
      archives.importFromPath(p.join(tempDir.path, 'missing.naipreciseref')),
      throwsA(isA<FileSystemException>()),
    );

    expect(await storage.getAllEntries(), isEmpty);
    await expectNoStagingLeft();
  });

  test('接受记录了目录项的配置包', () async {
    final path = await _writeArchive(
      tempDir,
      resource: 'images/11111111-1111-4111-8111-111111111111.png',
      fileName: 'listed.naipreciseref',
      directories: const ['images/'],
    );

    final imported = (await archives.importFromPath(path)).single;

    expect(imported.name, 'source');
    expect(await File(imported.imagePath).readAsBytes(), _pngBytes());
  });

  test('完整预检拒绝未知版本且不写入任何条目', () async {
    final path = await _writeArchive(
      tempDir,
      version: 999,
      resource: 'images/11111111-1111-4111-8111-111111111111.png',
    );

    await expectLater(
      archives.importFromPath(path),
      throwsA(isA<FormatException>()),
    );
    expect(await storage.getAllEntries(), isEmpty);
  });

  test('完整预检拒绝哈希错误和路径穿越且不写入', () async {
    final badHash = await _writeArchive(
      tempDir,
      resource: 'images/11111111-1111-4111-8111-111111111111.png',
      shaOverride: List.filled(64, '0').join(),
      fileName: 'bad-hash.naipreciseref',
    );
    await expectLater(
      archives.importFromPath(badHash),
      throwsA(isA<FormatException>()),
    );

    final traversal = await _writeArchive(
      tempDir,
      resource: '../11111111-1111-4111-8111-111111111111.png',
      fileName: 'traversal.naipreciseref',
    );
    await expectLater(
      archives.importFromPath(traversal),
      throwsA(isA<FormatException>()),
    );
    expect(await storage.getAllEntries(), isEmpty);
    await expectNoStagingLeft();
  });

  test('提交阶段失败会回滚本包已创建条目', () async {
    final first = await storage.importFromBytes(_pngBytes(), name: 'first');
    final second = await storage.importFromBytes(_pngBytes(), name: 'second');
    final path = p.join(tempDir.path, 'rollback.naipreciseref');
    await archives.exportToPath(entries: [first, second], outputPath: path);
    final failingStorage = _FailingCommitStorage();

    await expectLater(
      PreciseRefLibraryArchiveService(
        failingStorage,
        stagingRootPath: stagingRoot.path,
      ).importFromPath(path),
      throwsA(isA<FileSystemException>()),
    );

    expect(failingStorage.imports, 2);
    expect(failingStorage.deletedIds, hasLength(1));
    await expectNoStagingLeft();
  });
}

Uint8List _pngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(12, 34, 56));
  return Uint8List.fromList(img.encodePng(image));
}

Future<String> _writeArchive(
  Directory directory, {
  int version = 1,
  required String resource,
  String? shaOverride,
  String fileName = 'invalid.naipreciseref',
  List<String> directories = const [],
  Uint8List? resourceBytes,
}) async {
  final bytes = resourceBytes ?? _pngBytes();
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'nai-precise-reference-library',
      'version': version,
      'entries': [
        {
          'id': '11111111-1111-4111-8111-111111111111',
          'name': 'source',
          'type': PreciseRefType.characterAndStyle.name,
          'strength': 1.0,
          'fidelity': 1.0,
          'isFavorite': false,
          'usedCount': 0,
          'lastUsedAt': null,
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'resource': resource,
          'length': bytes.length,
          'sha256': shaOverride ?? sha256.convert(bytes).toString(),
        },
      ],
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  for (final name in directories) {
    archive.addFile(ArchiveFile(name, 0, <int>[])..isFile = false);
  }
  archive.addFile(ArchiveFile(resource, bytes.length, bytes));
  final path = p.join(directory.path, fileName);
  await File(path).writeAsBytes(ZipEncoder().encode(archive)!);
  return path;
}
