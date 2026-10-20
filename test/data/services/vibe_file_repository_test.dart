import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_file_repository.dart';
import 'package:path/path.dart' as p;

import '../../helpers/log_capture.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vibe_repository_log_');
  });

  tearDown(() => tempDir.delete(recursive: true));

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
