import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_repository.dart';
import 'package:path/path.dart' as p;

import '../../helpers/log_capture.dart';

class _MockFile extends Mock implements File {}

void main() {
  late Directory tempDir;

  setUp(() async {
    await AppLogger.initialize(
      isTestEnvironment: true,
      enableFileLogging: false,
    );
    AppLogger.debugSetMinimumLevelForTesting(Level.info);
    tempDir = await Directory.systemTemp.createTemp('vibe_repository_log_');
  });

  tearDown(() async {
    AppLogger.debugSetMinimumLevelForTesting(null);
    await tempDir.delete(recursive: true);
  });

  for (final extension in [
    '.naiv4vibe',
    '.naiv4vibebundle',
    '.private_extension',
  ]) {
    final expectedExtension = extension == '.private_extension'
        ? 'unknown'
        : extension;
    test('删除 $expectedExtension 成功时不记录 Vibe 名称或目录', () async {
      final file = await File(
        p.join(tempDir.path, 'private vibe name$extension'),
      ).writeAsString('vibe');
      final logs = await captureLogs(() async {
        expect(await VibeFileRepository().deleteVibeFile(file.path), isTrue);
      });

      final text = logs.join('\n');
      expect(text, contains('删除 Vibe 文件成功 (extension: $expectedExtension)'));
      expect(text, isNot(contains(tempDir.path)));
      expect(text, isNot(contains('private')));
      expect(await file.exists(), isFalse);
    });

    test('删除 $expectedExtension 失败时仅记录扩展名与错误码', () async {
      final path = p.join(tempDir.path, 'private vibe name$extension');
      final file = _MockFile();
      when(() => file.exists()).thenAnswer((_) async => true);
      when(() => file.delete()).thenThrow(
        FileSystemException(
          'Cannot delete private vibe name',
          path,
          const OSError('private OS error', 5),
        ),
      );
      final logs = await IOOverrides.runZoned(
        () => captureLogs(() async {
          expect(await VibeFileRepository().deleteVibeFile(path), isFalse);
        }),
        createFile: (_) => file,
      );

      final text = logs.join('\n');
      expect(text, contains('删除 Vibe 文件失败 (extension: $expectedExtension)'));
      expect(text, contains('FileSystemException(errno: 5)'));
      expect(text, isNot(contains(tempDir.path)));
      expect(text, isNot(contains('private')));
    });
  }

  const sensitiveText = 'secret lighthouse keeper';
  final brokenDocuments = <String, List<int>>{
    '读取失败': [0xff, ...sensitiveText.codeUnits],
    'JSON 无效': '{"name":"$sensitiveText",'.codeUnits,
    'JSON 不是对象': '["$sensitiveText"]'.codeUnits,
  };
  for (final MapEntry(key: scenario, value: bytes) in brokenDocuments.entries) {
    test('Vibe 单文件 $scenario 时拒绝覆盖且不泄露内容', () async {
      final file = await File(
        p.join(tempDir.path, 'broken.naiv4vibe'),
      ).writeAsBytes(bytes);
      final repository = VibeFileRepository();

      final logs = await captureLogs(() async {
        await expectLater(
          repository.overwriteVibeFile(
            file.path,
            const VibeReference(
              displayName: 'replacement',
              vibeEncoding: 'encoded',
            ),
            displayName: 'replacement',
            defaultModel: 'nai-diffusion-4-full',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              isNot(contains('lighthouse')),
            ),
          ),
        );
      });

      expect(await file.readAsBytes(), bytes);
      expect(logs.join('\n'), isNot(contains('lighthouse')));
    });
  }

  test('损坏的 Bundle 读取与覆盖失败时，日志和异常都不带出文件内容', () async {
    final bundle = File(p.join(tempDir.path, 'broken.naiv4vibebundle'))
      ..writeAsStringSync('{"vibes":[{"name":"secret lighthouse keeper",');
    final repository = VibeFileRepository();
    Object? overwriteError;

    final logs = await captureLogs(() async {
      expect(await repository.loadVibeFromFile(bundle.path), isNull);
      expect(await repository.loadImportParams(bundle.path), isNull);
      expect(await repository.extractPreviewsFromBundle(bundle.path), isEmpty);
      overwriteError = await repository
          .overwriteBundleFile(bundle.path, const [
            VibeReference(displayName: 'replacement', vibeEncoding: 'encoded'),
          ])
          .then<Object?>((_) => null, onError: (Object error) => error);
    });

    expect(overwriteError, isA<StateError>());
    expect('$overwriteError', isNot(contains('lighthouse')));
    expect(logs.where((line) => line.contains('[E]')), hasLength(4));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
