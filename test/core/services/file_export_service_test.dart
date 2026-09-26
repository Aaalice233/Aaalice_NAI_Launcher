import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/file_export_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../helpers/fake_save_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory exportDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'file_export_service_test_',
    );
    exportDirectory = await Directory(
      p.join(tempDirectory.path, 'exports'),
    ).create();
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      tempDirectory.path,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'directory exports sanitize names and never overwrite an existing file',
    () async {
      final first = await FileExportService.writeBytesToDirectory(
        directory: exportDirectory.path,
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: '../unsafe:name.zip',
        mimeType: 'application/zip',
      );
      final second = await FileExportService.writeBytesToDirectory(
        directory: exportDirectory.path,
        bytes: Uint8List.fromList([4, 5]),
        fileName: '../unsafe:name.zip',
        mimeType: 'application/zip',
      );

      expect(p.dirname(first), exportDirectory.path);
      expect(p.dirname(second), exportDirectory.path);
      expect(first, isNot(second));
      expect(await File(first).readAsBytes(), [1, 2, 3]);
      expect(await File(second).readAsBytes(), [4, 5]);
    },
  );

  test('path exports copy without modifying the source file', () async {
    final source = await File(
      p.join(tempDirectory.path, 'source.json'),
    ).writeAsString('{"value":1}');

    final output = await FileExportService.writeFileToDirectory(
      directory: exportDirectory.path,
      sourcePath: source.path,
      fileName: 'copy.json',
      mimeType: 'application/json',
    );

    expect(await File(output).readAsString(), '{"value":1}');
    expect(await source.readAsString(), '{"value":1}');
    expect(output, isNot(source.path));
  });

  group('desktop save dialog', () {
    test('overwrites the chosen file unless protection is requested', () async {
      final chosen = await File(
        p.join(exportDirectory.path, 'chosen.png'),
      ).writeAsBytes([9]);
      useFakeFilePicker(FakeSaveFilePicker(savePath: chosen.path));

      final replaced = await FileExportService.saveBytes(
        bytes: Uint8List.fromList([1, 2]),
        fileName: 'suggested.png',
        dialogTitle: 'Save',
        mimeType: 'image/png',
        allowedExtensions: const ['png'],
      );
      final protected = await FileExportService.saveBytes(
        bytes: Uint8List.fromList([3, 4]),
        fileName: 'suggested.png',
        dialogTitle: 'Save',
        mimeType: 'image/png',
        allowedExtensions: const ['png'],
        preventOverwrite: true,
      );

      expect(replaced, chosen.path);
      expect(await chosen.readAsBytes(), [1, 2]);
      expect(protected, p.join(exportDirectory.path, 'chosen (1).png'));
      expect(await File(protected!).readAsBytes(), [3, 4]);
    });

    test('appends the allowed extension when the user omits it', () async {
      useFakeFilePicker(
        FakeSaveFilePicker(savePath: p.join(exportDirectory.path, 'plain')),
      );

      final saved = await FileExportService.saveBytes(
        bytes: Uint8List.fromList([1]),
        fileName: 'suggested.png',
        dialogTitle: 'Save',
        mimeType: 'image/png',
        allowedExtensions: const ['png'],
      );

      expect(saved, p.join(exportDirectory.path, 'plain.png'));
      expect(await File(saved!).readAsBytes(), [1]);
    });

    test('returns null without writing when the dialog is cancelled', () async {
      useFakeFilePicker(FakeSaveFilePicker());

      final saved = await FileExportService.saveBytes(
        bytes: Uint8List.fromList([1]),
        fileName: 'suggested.png',
        dialogTitle: 'Save',
        mimeType: 'image/png',
        allowedExtensions: const ['png'],
        preventOverwrite: true,
      );

      expect(saved, isNull);
      expect(exportDirectory.listSync(), isEmpty);
    });

    test(
      'protected path copies never duplicate the source chosen as target',
      () async {
        final source = await File(
          p.join(exportDirectory.path, 'source.png'),
        ).writeAsBytes([5, 6]);
        final picker = FakeSaveFilePicker(savePath: source.path);
        useFakeFilePicker(picker);

        final sameFile = await FileExportService.saveFileFromPath(
          sourcePath: source.path,
          fileName: 'source.png',
          dialogTitle: 'Save',
          mimeType: 'image/png',
          allowedExtensions: const ['png'],
          preventOverwrite: true,
        );
        final taken = await File(
          p.join(exportDirectory.path, 'taken.png'),
        ).writeAsBytes([7]);
        picker.savePath = taken.path;
        final sibling = await FileExportService.saveFileFromPath(
          sourcePath: source.path,
          fileName: 'source.png',
          dialogTitle: 'Save',
          mimeType: 'image/png',
          allowedExtensions: const ['png'],
          preventOverwrite: true,
        );

        expect(sameFile, source.path);
        expect(sibling, p.join(exportDirectory.path, 'taken (1).png'));
        expect(await File(sibling!).readAsBytes(), [5, 6]);
        expect(await taken.readAsBytes(), [7]);
        expect(exportDirectory.listSync(), hasLength(3));
      },
    );
  });

  test('non-overwriting paths skip every taken numbered sibling', () async {
    final requested = p.join(exportDirectory.path, 'image.png');
    await File(requested).writeAsBytes([1]);
    await File(p.join(exportDirectory.path, 'image (1).png')).writeAsBytes([2]);

    expect(
      await FileExportService.resolveNonOverwritingPath(requested),
      p.join(exportDirectory.path, 'image (2).png'),
    );
    expect(
      await FileExportService.resolveNonOverwritingPath(
        p.join(exportDirectory.path, 'free.png'),
      ),
      p.join(exportDirectory.path, 'free.png'),
    );
  });

  test('temporary output is removed after success and failure', () async {
    late String successfulPath;
    final result = await FileExportService.withTemporaryOutput<String>(
      fileName: 'payload.txt',
      action: (path) async {
        successfulPath = path;
        await File(path).writeAsString('payload');
        return 'done';
      },
    );

    expect(result, 'done');
    expect(await File(successfulPath).exists(), isFalse);

    late String failedPath;
    await expectLater(
      FileExportService.withTemporaryOutput<void>(
        fileName: 'failed.txt',
        action: (path) async {
          failedPath = path;
          await File(path).writeAsString('payload');
          throw StateError('injected failure');
        },
      ),
      throwsStateError,
    );
    expect(await File(failedPath).exists(), isFalse);
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
