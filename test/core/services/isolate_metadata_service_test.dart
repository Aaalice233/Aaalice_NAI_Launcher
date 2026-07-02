import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';

void main() {
  group('IsolateMetadataService', () {
    late Directory tempDir;
    late IsolateMetadataService service;

    setUpAll(() async {
      await AppLogger.initialize(isTestEnvironment: true);
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'isolate_metadata_service_test_',
      );
      service = IsolateMetadataService.instance;
      service.dispose();
      await service.initialize();
      service.resetStatistics();
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'queued parse returns the worker result instead of queue placeholder',
      () async {
        final slowBytes = Uint8List(8 * 1024 * 1024);
        slowBytes.setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

        final busyFileA = File('${tempDir.path}/busy_a.png');
        final busyFileB = File('${tempDir.path}/busy_b.png');
        final queuedFile = File('${tempDir.path}/queued_missing.png');

        await busyFileA.writeAsBytes(slowBytes);
        await busyFileB.writeAsBytes(slowBytes);

        final first = service.parseMetadata(
          busyFileA.path,
          config: const IsolateParseConfig(timeout: Duration(seconds: 10)),
        );
        final second = service.parseMetadata(
          busyFileB.path,
          config: const IsolateParseConfig(timeout: Duration(seconds: 10)),
        );
        final queued = service.parseMetadata(
          queuedFile.path,
          config: const IsolateParseConfig(timeout: Duration(seconds: 10)),
        );

        await _waitForQueuedTask(service);

        final queuedResult = await queued;
        await Future.wait([first, second]);

        expect(queuedResult.success, isFalse);
        expect(queuedResult.error, isNot('Task in queue'));
        expect(queuedResult.error, contains('File not found'));
      },
    );

    test('falls back to inline parsing when worker startup fails', () async {
      final fallbackService = IsolateMetadataService.forTesting(
        workerInitializer: (_, _) async {
          throw StateError('spawn failed');
        },
      );

      addTearDown(fallbackService.dispose);

      await expectLater(fallbackService.initialize(), completes);

      final statistics = fallbackService.getStatistics();
      expect(statistics['fallbackToInlineParsing'], isTrue);
      expect(statistics['workerStartupError'], contains('spawn failed'));

      final result = await fallbackService.parseMetadata(
        '${tempDir.path}/missing.png',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('File not found'));
    });
  });
}

Future<void> _waitForQueuedTask(IsolateMetadataService service) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 3)) {
    if ((service.getStatistics()['queuedTasks'] as int) > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected a metadata parse task to be queued');
}
