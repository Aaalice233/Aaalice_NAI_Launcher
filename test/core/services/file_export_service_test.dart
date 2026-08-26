import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/file_export_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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
