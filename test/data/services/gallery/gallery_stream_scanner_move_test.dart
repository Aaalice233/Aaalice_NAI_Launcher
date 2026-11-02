import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_stream_scanner.dart'
    show GalleryStreamScanner;
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/gallery_database_sandbox.dart';

void main() {
  group('GalleryStreamScanner folder move', () {
    final sandbox = useGalleryDatabaseSandbox('gallery_stream_scanner_move_');
    late GalleryDataSource dataSource;
    late Directory tempDir;

    setUp(() async {
      dataSource = sandbox.dataSource;
      tempDir = sandbox.root;
      await ImageMetadataService().initialize();
      IsolateMetadataService.instance.dispose();
      GalleryStreamScanner.resetInstance();
    });

    tearDown(() {
      GalleryStreamScanner.resetInstance();
      IsolateMetadataService.instance.dispose();
    });

    test(
      'images stay indexed with metadata after their folder is moved',
      () async {
        final folder = await Directory(p.join(tempDir.path, 'a')).create();
        final first = await _createWrappedNovelAiPng(
          folder,
          'one.png',
          prompt: '1girl, solo',
        );
        await _createWrappedNovelAiPng(
          folder,
          'two.png',
          prompt: '2girls, long prompt to change the file size',
        );
        final scanner = GalleryStreamScanner.instance(dataSource: dataSource);
        await scanner.startScanning(tempDir);
        final originalId = await dataSource.getImageIdByPath(first.path);
        expect(originalId, isNotNull);

        final parent = await Directory(p.join(tempDir.path, 'parent')).create();
        final movedFolder = await folder.rename(p.join(parent.path, 'a'));
        final movedPath = p.join(movedFolder.path, 'one.png');

        await scanner.startScanning(tempDir);

        final movedId = await dataSource.getImageIdByPath(movedPath);
        expect(movedId, isNotNull, reason: 'moved image row is soft-deleted');
        expect(movedId, originalId, reason: 'move keeps the same row');
        final record = await dataSource.getImageById(movedId!);
        expect(record!.isDeleted, isFalse);
        expect(record.metadataStatus, MetadataStatus.success);
      },
    );

    test(
      'a deleted record left at the destination path does not block the move',
      () async {
        final folder = await Directory(p.join(tempDir.path, 'a')).create();
        final first = await _createWrappedNovelAiPng(
          folder,
          'one.png',
          prompt: '1girl, solo',
        );
        final scanner = GalleryStreamScanner.instance(dataSource: dataSource);
        await scanner.startScanning(tempDir);
        final originalId = await dataSource.getImageIdByPath(first.path);

        final parent = await Directory(p.join(tempDir.path, 'parent')).create();
        final movedPath = p.join(parent.path, 'a', 'one.png');
        // 以前在目标路径出现过又被删除的同路径文件，数据库里留着已删除的记录。
        final staleId = await dataSource.upsertImage(
          filePath: movedPath,
          fileName: 'one.png',
          fileSize: 1,
          createdAt: DateTime(2020),
          modifiedAt: DateTime(2020),
        );
        await dataSource.batchMarkAsDeleted([movedPath]);
        await folder.rename(p.join(parent.path, 'a'));

        await scanner.startScanning(tempDir);

        final movedId = await dataSource.getImageIdByPath(movedPath);
        expect(movedId, isNotNull);
        expect(movedId, originalId);
        expect(movedId, isNot(staleId));
        final record = await dataSource.getImageById(movedId!);
        expect(record!.metadataStatus, MetadataStatus.success);
      },
    );
  });
}

Future<File> _createWrappedNovelAiPng(
  Directory dir,
  String fileName, {
  required String prompt,
}) async {
  final innerComment = jsonEncode({
    'prompt': prompt,
    'uc': 'lowres, blurry',
    'seed': 42,
    'sampler': 'k_euler',
    'steps': 28,
    'scale': 6.5,
    'width': 64,
    'height': 64,
    'version': 1,
  });

  final outerComment = jsonEncode({
    'Description': prompt,
    'Software': 'NovelAI',
    'Source': 'NovelAI Diffusion V4.5 4BDE2A90',
    'Comment': innerComment,
  });

  var bytes = _buildBasePngBytes();
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Title',
    'NovelAI generated image',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Description',
    prompt,
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Software',
    'NovelAI',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Source',
    'NovelAI Diffusion V4.5 4BDE2A90',
  );
  bytes = UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Comment',
    outerComment,
  );

  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes);
  return file;
}

Uint8List _buildBasePngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}
