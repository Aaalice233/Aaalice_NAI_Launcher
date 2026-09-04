import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/import_models.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/services/tag_library_import_planner.dart';
import 'package:nai_launcher/data/services/tag_library_io_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _entryId = '11111111-1111-4111-8111-111111111111';
const _otherEntryId = '33333333-3333-4333-8333-333333333333';
const _categoryId = '22222222-2222-4222-8222-222222222222';
const _pngBytes = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late Directory workspace;
  late PathProviderPlatform previousPlatform;
  late TagLibraryIOService service;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('tag-library-docs-');
    workspace = await Directory.systemTemp.createTemp('tag-library-package-');
    previousPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _PathProvider(documents.path);
    service = TagLibraryIOService();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPlatform;
    await documents.delete(recursive: true);
    await workspace.delete(recursive: true);
  });

  Directory thumbnailsRoot() =>
      Directory(p.join(documents.path, 'tag_library_thumbnails'));

  List<String> documentEntryNames() =>
      documents.listSync().map((e) => p.basename(e.path)).toList()..sort();

  List<String> thumbnailNames() {
    final root = thumbnailsRoot();
    if (!root.existsSync()) return const [];
    return root.listSync().map((e) => p.basename(e.path)).toList()..sort();
  }

  Future<ImportResult> runImport(File package, ImportPreview preview) =>
      service.executeImport(
        zipFile: package,
        plan: const TagLibraryImportPlanner().plan(
          preview: preview,
          selectedEntryIds: preview.entries.map((e) => e.id).toSet(),
          selectedCategoryIds: preview.categories.map((c) => c.id).toSet(),
          conflicts: const [],
          conflictResolutions: const {},
          existingEntries: const [],
          existingCategories: const [],
          renameSuffix: ' (导入)',
        ),
      );

  group('归档成员校验', () {
    test('拒绝穿越缩略图目录的成员并且不落盘', () async {
      final entry = _entry(id: _entryId, thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/$_entryId.json', entry.toJson()),
        _binary('thumbnails/../escaped.png', _pngBytes),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runImport(package, _preview(entries: [entry])),
        throwsA(isA<FormatException>()),
      );
      expect(File(p.join(documents.path, 'escaped.png')).existsSync(), isFalse);
      expect(thumbnailNames(), isEmpty);
    });

    test('拒绝绝对路径成员', () async {
      final package = _writePackage(workspace, [
        _manifest(entryCount: 0),
        _binary('/etc/escaped.png', _pngBytes),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝仅大小写不同的重复成员', () async {
      final entry = _entry(id: _entryId, thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/$_entryId.json', entry.toJson()),
        _binary('thumbnails/$_entryId.png', _pngBytes),
        _binary('thumbnails/${_entryId.toUpperCase()}.PNG', _pngBytes),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝同一条目携带多张预览图', () async {
      final entry = _entry(id: _entryId, thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/$_entryId.json', entry.toJson()),
        _binary('thumbnails/$_entryId.png', _pngBytes),
        _binary('thumbnails/$_entryId.jpg', _pngBytes),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝符号链接成员', () async {
      final entry = _entry(id: _entryId, thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/$_entryId.json', entry.toJson()),
        _binary('thumbnails/$_entryId.png', utf8.encode('../../escaped.png')),
      ], symbolicLinkMember: 'thumbnails/$_entryId.png');

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runImport(package, _preview(entries: [entry])),
        throwsA(isA<FormatException>()),
      );
      expect(thumbnailNames(), isEmpty);
    });

    test('拒绝伪装成预览图的可执行文件与文本', () async {
      for (final extension in const ['.exe', '.txt']) {
        final entry = _entry(id: _entryId, thumbnail: '/exported/thumb.png');
        final package = _writePackage(workspace, [
          _manifest(),
          _json('entries/$_entryId.json', entry.toJson()),
          _binary('thumbnails/$_entryId$extension', _pngBytes),
        ], fileName: 'payload$extension.zip');

        await expectLater(
          service.parseImportFile(package),
          throwsA(isA<FormatException>()),
          reason: '扩展名 $extension 应被拒绝',
        );
        await expectLater(
          runImport(package, _preview(entries: [entry])),
          throwsA(isA<FormatException>()),
          reason: '扩展名 $extension 应被拒绝',
        );
      }
      expect(thumbnailNames(), isEmpty);
    });
  });

  group('标识符校验', () {
    test('拒绝穿越目录的条目 ID 且不写出目录外文件', () async {
      final entry = _entry(id: '../escaped', thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/payload.json', entry.toJson()),
        _binary('thumbnails/$_entryId.png', _pngBytes),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runImport(package, _preview(entries: [entry])),
        throwsA(isA<FormatException>()),
      );
      expect(File(p.join(documents.path, 'escaped.png')).existsSync(), isFalse);
      expect(documentEntryNames(), isEmpty);
    });

    test('拒绝含盘符与反斜杠的条目 ID', () async {
      for (final id in const [
        r'C:\Windows\Temp\escaped',
        'C:/Windows/Temp/escaped',
        r'..\escaped',
      ]) {
        final entry = _entry(id: id, thumbnail: '/exported/thumb.png');
        final package = _writePackage(workspace, [
          _manifest(),
          _json('entries/payload.json', entry.toJson()),
        ], fileName: 'package-${id.hashCode}.zip');

        await expectLater(
          service.parseImportFile(package),
          throwsA(isA<FormatException>()),
          reason: 'ID $id 应被拒绝',
        );
        await expectLater(
          runImport(package, _preview(entries: [entry])),
          throwsA(isA<FormatException>()),
          reason: 'ID $id 应被拒绝',
        );
      }
      expect(documentEntryNames(), isEmpty);
    });

    test('拒绝非法的分类 ID 与引用', () async {
      final category = TagLibraryCategory(
        id: _categoryId,
        name: '分类',
        parentId: '../escaped',
        createdAt: DateTime.utc(2026),
      );
      final entry = _entry(id: _entryId, categoryId: '../escaped');
      final package = _writePackage(workspace, [
        _manifest(categoryCount: 1),
        _json('categories.json', [category.toJson()]),
        _json('entries/$_entryId.json', entry.toJson()),
      ]);

      await expectLater(
        service.parseImportFile(package),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runImport(package, _preview(entries: [entry], categories: [category])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('预览图定位', () {
    test('同名前缀成员不会被当作该条目的预览图', () async {
      final entry = _entry(id: 'abc', thumbnail: '/exported/thumb.png');
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/abc.json', entry.toJson()),
        _binary('thumbnails/abcd.png', _pngBytes),
      ]);

      final preview = await service.parseImportFile(package);
      final result = await runImport(package, preview);

      expect(result.success, isTrue);
      expect(result.updatedEntries['abc']!.thumbnail, isNull);
      expect(thumbnailNames(), isEmpty);
    });

    test('正常预览图落在缩略图目录内且内容一致', () async {
      final entry = _entry(
        id: _entryId,
        thumbnail: '/exported/tag_library_thumbnails/$_entryId.png',
      );
      final package = _writePackage(workspace, [
        _manifest(),
        _json('entries/$_entryId.json', entry.toJson()),
        _binary('thumbnails/$_entryId.png', _pngBytes),
      ]);

      final preview = await service.parseImportFile(package);
      final result = await runImport(package, preview);

      final imported = result.updatedEntries[_entryId]!.thumbnail!;
      expect(result.success, isTrue);
      expect(p.isWithin(thumbnailsRoot().path, imported), isTrue);
      expect(File(imported).readAsBytesSync(), _pngBytes);
      expect(thumbnailNames(), [p.basename(imported)]);
      expect(documentEntryNames(), ['tag_library_thumbnails']);
    });

    test('包内未携带预览图时丢弃导出机器的外部路径', () async {
      final foreign = _entry(
        id: _entryId,
        thumbnail: p.join(workspace.path, 'foreign.png'),
      );
      final local = _entry(
        id: _otherEntryId,
        thumbnail: p.join(thumbnailsRoot().path, '$_otherEntryId.png'),
      );
      final package = _writePackage(workspace, [
        _manifest(entryCount: 2),
        _json('entries/$_entryId.json', foreign.toJson()),
        _json('entries/$_otherEntryId.json', local.toJson()),
      ]);

      final preview = await service.parseImportFile(package);
      final result = await runImport(package, preview);

      expect(result.updatedEntries[_entryId]!.thumbnail, isNull);
      expect(
        result.updatedEntries[_otherEntryId]!.thumbnail,
        p.join(thumbnailsRoot().path, '$_otherEntryId.png'),
      );
    });
  });
}

TagLibraryEntry _entry({
  required String id,
  String? thumbnail,
  String? categoryId,
}) => TagLibraryEntry(
  id: id,
  name: '条目',
  content: '1girl',
  thumbnail: thumbnail,
  categoryId: categoryId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ImportPreview _preview({
  List<TagLibraryEntry> entries = const [],
  List<TagLibraryCategory> categories = const [],
}) => ImportPreview(
  version: '1.0',
  exportDate: DateTime.utc(2026),
  entries: entries,
  categories: categories,
  hasThumbnails: true,
);

ArchiveFile _manifest({int entryCount = 1, int categoryCount = 0}) =>
    _json('manifest.json', {
      'version': '1.0',
      'exportDate': DateTime.utc(2026).toIso8601String(),
      'appVersion': '1.0.0',
      'entryCount': entryCount,
      'categoryCount': categoryCount,
      'includeThumbnails': true,
    });

ArchiveFile _json(String name, Object? value) =>
    _binary(name, utf8.encode(jsonEncode(value)));

ArchiveFile _binary(String name, List<int> bytes) =>
    ArchiveFile(name, bytes.length, bytes);

File _writePackage(
  Directory directory,
  List<ArchiveFile> files, {
  String fileName = 'library.zip',
  String? symbolicLinkMember,
}) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  var bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
  if (symbolicLinkMember != null) {
    bytes = _markSymbolicLink(bytes, symbolicLinkMember);
  }
  return File(p.join(directory.path, fileName))..writeAsBytesSync(bytes);
}

// ZipEncoder 只写 MS-DOS 归档，符号链接位必须直接改中央目录的 versionMadeBy 与外部属性
Uint8List _markSymbolicLink(Uint8List zip, String memberName) {
  final data = ByteData.sublistView(zip);
  var directoryEnd = zip.length - 22;
  while (directoryEnd >= 0 &&
      data.getUint32(directoryEnd, Endian.little) != 0x06054b50) {
    directoryEnd--;
  }
  if (directoryEnd < 0) {
    throw StateError('未找到中央目录结尾记录');
  }

  final count = data.getUint16(directoryEnd + 10, Endian.little);
  var offset = data.getUint32(directoryEnd + 16, Endian.little);
  for (var index = 0; index < count; index++) {
    final nameLength = data.getUint16(offset + 28, Endian.little);
    final extraLength = data.getUint16(offset + 30, Endian.little);
    final commentLength = data.getUint16(offset + 32, Endian.little);
    final name = utf8.decode(
      zip.sublist(offset + 46, offset + 46 + nameLength),
    );
    if (name == memberName) {
      data.setUint16(offset + 4, (3 << 8) | 20, Endian.little);
      data.setUint32(offset + 38, 0xa1ff0000, Endian.little);
      return zip;
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  throw StateError('未找到归档成员：$memberName');
}

class _PathProvider extends PathProviderPlatform {
  _PathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
