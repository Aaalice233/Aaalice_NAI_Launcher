import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/services/image_save_as_service.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_save_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 26, 8, 5, 3);
  const seededMetadata = NaiImageMetadata(prompt: 'own prompt', seed: 42);
  final plainPng = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 2)),
  );
  late Directory tempDirectory;
  late Directory galleryDirectory;
  late Directory exportDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'image_save_as_service_test_',
    );
    Hive.init(p.join(tempDirectory.path, 'hive'));
    galleryDirectory = await Directory(
      p.join(tempDirectory.path, 'gallery'),
    ).create();
    exportDirectory = await Directory(
      p.join(tempDirectory.path, 'exports'),
    ).create();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<Uint8List> failingLoad() async =>
      throw StateError('bytes must not be loaded for gallery copies');

  Map<String, dynamic> commentOf(Uint8List bytes) =>
      jsonDecode(UnifiedMetadataParser.extractPngTextData(bytes)['Comment']!)
          as Map<String, dynamic>;

  group('writeToDirectory', () {
    test('copies a saved gallery file without loading bytes', () async {
      final galleryFile = await File(
        p.join(galleryDirectory.path, '07-00-00-7.png'),
      ).writeAsBytes([1, 2, 3]);

      final output = await ImageSaveAsService.writeToDirectory(
        ImageSaveAsSource.deferred(
          loadBytes: failingLoad,
          filePath: galleryFile.path,
        ),
        directory: exportDirectory.path,
      );

      expect(output, p.join(exportDirectory.path, '07-00-00-7.png'));
      expect(await File(output).readAsBytes(), [1, 2, 3]);
      expect(await galleryFile.readAsBytes(), [1, 2, 3]);
    });

    test('writes the same bytes and name the gallery Save would', () async {
      final saved = await ImageSaveUtils.saveResultImage(
        rootPath: galleryDirectory.path,
        imageBytes: plainPng,
        preserveOriginalBytes: false,
        metadata: seededMetadata,
        now: now,
      );

      final output = await ImageSaveAsService.writeToDirectory(
        ImageSaveAsSource(bytes: plainPng, metadata: seededMetadata),
        directory: exportDirectory.path,
        now: now,
      );

      final exported = await File(output).readAsBytes();
      expect(p.basename(output), '08-05-03-42.png');
      expect(p.basename(output), p.basename(saved.path));
      expect(exported, orderedEquals(saved.bytes));
      expect(commentOf(exported)['seed'], 42);
    });

    test('keeps original bytes when the image asks for them', () async {
      final output = await ImageSaveAsService.writeToDirectory(
        ImageSaveAsSource(
          bytes: plainPng,
          filePath: p.join(galleryDirectory.path, 'external.png'),
          metadata: seededMetadata,
          preserveOriginalBytes: true,
        ),
        directory: exportDirectory.path,
      );

      expect(await File(output).readAsBytes(), orderedEquals(plainPng));
    });

    test('falls back to memory when the gallery file was deleted', () async {
      final output = await ImageSaveAsService.writeToDirectory(
        ImageSaveAsSource(
          bytes: Uint8List.fromList([6]),
          filePath: p.join(galleryDirectory.path, 'deleted.png'),
        ),
        directory: exportDirectory.path,
      );

      expect(p.basename(output), 'deleted.png');
      expect(await File(output).readAsBytes(), [6]);
    });

    test('numbers name conflicts instead of overwriting', () async {
      final source = ImageSaveAsSource(
        bytes: plainPng,
        metadata: seededMetadata,
      );

      final first = await ImageSaveAsService.writeToDirectory(
        source,
        directory: exportDirectory.path,
        now: now,
      );
      final second = await ImageSaveAsService.writeToDirectory(
        source,
        directory: exportDirectory.path,
        now: now,
      );

      expect(p.basename(first), '08-05-03-42.png');
      expect(p.basename(second), '08-05-03-42 (1).png');
    });

    test('rejects empty image bytes', () async {
      await expectLater(
        ImageSaveAsService.writeToDirectory(
          ImageSaveAsSource(bytes: Uint8List(0), metadata: seededMetadata),
          directory: exportDirectory.path,
        ),
        throwsStateError,
      );
      expect(exportDirectory.listSync(), isEmpty);
    });
  });

  group('saveOne', () {
    test('suggests the gallery name and restricts the dialog to PNG', () async {
      final target = p.join(exportDirectory.path, 'picked.png');
      final picker = FakeSaveFilePicker(savePath: target);
      useFakeFilePicker(picker);

      final saved = await ImageSaveAsService.saveOne(
        ImageSaveAsSource(bytes: plainPng, metadata: seededMetadata),
        dialogTitle: 'Save image as',
        now: now,
      );

      expect(saved, target);
      expect(commentOf(await File(target).readAsBytes())['seed'], 42);
      expect(picker.saveRequests.single.fileName, '08-05-03-42.png');
      expect(picker.saveRequests.single.allowedExtensions, ['png']);
    });

    test('suggests the gallery file name for saved images', () async {
      final galleryFile = await File(
        p.join(galleryDirectory.path, '06-00-00-6.png'),
      ).writeAsBytes([1]);
      final target = p.join(exportDirectory.path, 'renamed.png');
      final picker = FakeSaveFilePicker(savePath: target);
      useFakeFilePicker(picker);

      final saved = await ImageSaveAsService.saveOne(
        ImageSaveAsSource.deferred(
          loadBytes: failingLoad,
          filePath: galleryFile.path,
        ),
        dialogTitle: 'Save image as',
      );

      expect(saved, target);
      expect(picker.saveRequests.single.fileName, '06-00-00-6.png');
      expect(await File(target).readAsBytes(), [1]);
    });

    test('keeps an existing target when overwrite protection is on', () async {
      final existing = await File(
        p.join(exportDirectory.path, 'existing.png'),
      ).writeAsBytes([0]);
      useFakeFilePicker(FakeSaveFilePicker(savePath: existing.path));

      final saved = await ImageSaveAsService.saveOne(
        ImageSaveAsSource(bytes: plainPng, metadata: seededMetadata),
        dialogTitle: 'Save image as',
        preventOverwrite: true,
      );

      expect(saved, p.join(exportDirectory.path, 'existing (1).png'));
      expect(await existing.readAsBytes(), [0]);
    });

    test('returns null and writes nothing when cancelled', () async {
      useFakeFilePicker(FakeSaveFilePicker());

      final saved = await ImageSaveAsService.saveOne(
        ImageSaveAsSource(bytes: plainPng, metadata: seededMetadata),
        dialogTitle: 'Save image as',
      );

      expect(saved, isNull);
      expect(exportDirectory.listSync(), isEmpty);
    });
  });
}
