import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
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

  group('iOS export path', () {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    final sharedPaths = <String>[];
    final sharedMimeTypes = <String>[];
    final sharedContents = <List<int>>[];
    var shareOutcome = 'com.apple.UIKit.activity.SaveToCameraRoll';

    setUp(() {
      sharedPaths.clear();
      sharedMimeTypes.clear();
      sharedContents.clear();
      shareOutcome = 'com.apple.UIKit.activity.SaveToCameraRoll';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            if (call.method != 'shareFiles') return null;
            final arguments = (call.arguments as Map).cast<String, Object?>();
            for (final path in (arguments['paths']! as List).cast<String>()) {
              sharedPaths.add(path);
              // 读取发生在分享期间：暂存文件必须在这一刻还活着。
              sharedContents.add(await File(path).readAsBytes());
            }
            sharedMimeTypes.addAll(
              (arguments['mimeTypes']! as List).cast<String>(),
            );
            // 空串 = 用户划掉了分享面板。
            return shareOutcome;
          });
      FileExportService.debugPlatformOverride =
          PlatformCapabilities.forPlatform(TargetPlatform.iOS);
    });

    tearDown(() {
      FileExportService.debugPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });

    // 上游只有 Android / 桌面两条分支，桌面那条在 iOS 上调
    // FilePicker.saveFile 而不传 bytes，file_picker 会直接 throw ArgumentError，
    // 影响 20+ 个导出调用点。这条测试钉住 iOS 第三分支：写干净命名的暂存文件
    // + 系统分享面板，且分享结束后不留临时文件。
    test('saveBytes stages a cleanly named file and shares it', () async {
      final saved = await FileExportService.saveBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'aaalice-skills.zip',
        dialogTitle: 'export',
        mimeType: 'application/zip',
        allowedExtensions: const ['zip'],
      );

      expect(saved, isNotNull);
      expect(sharedPaths, hasLength(1));
      expect(p.basename(sharedPaths.single), 'aaalice-skills.zip');
      expect(sharedMimeTypes.single, 'application/zip');
      expect(sharedContents.single, [1, 2, 3]);
      // 暂存目录在返回前已清理，不会在「文件」App 里留下垃圾。
      expect(await File(sharedPaths.single).exists(), isFalse);
    });

    test('dismissing the share sheet reports a cancelled export', () async {
      shareOutcome = '';

      final saved = await FileExportService.saveText(
        text: '{"value":1}',
        fileName: 'profile.json',
        dialogTitle: 'export',
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
      );

      expect(saved, isNull);
    });

    test('directory-based export entry points degrade instead of throwing', () {
      // iOS 拿不到可长期写入的目录，返回 null 让调用方走「用户取消」分支。
      expect(
        FileExportService.pickExportDirectory(dialogTitle: 'pick'),
        completion(isNull),
      );
      expect(
        FileExportService.pickSaveFilePath(
          dialogTitle: 'save',
          fileName: 'images.zip',
          allowedExtensions: const ['zip'],
        ),
        completion(isNull),
      );
    });
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
