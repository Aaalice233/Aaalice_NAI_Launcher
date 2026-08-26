import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/metadata/isolate_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

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
      await _deleteTempDirectoryWhenWorkersReleaseFiles(tempDir);
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

    test(
      'does not complete a new parse with a cancelled request response',
      () async {
        final oldFile = File('${tempDir.path}/old.png');
        final newFile = File('${tempDir.path}/new.png');

        await oldFile.writeAsBytes(
          await _pngWithNovelAiMetadata(
            prompt: 'old-prompt',
            negativePrompt: _largeText('x'),
          ),
        );
        await newFile.writeAsBytes(
          await _pngWithNovelAiMetadata(prompt: 'new-prompt'),
        );

        final oldParse = service.parseMetadata(
          oldFile.path,
          config: const IsolateParseConfig(
            timeout: Duration(seconds: 10),
            useGradualRead: false,
            useCache: false,
          ),
        );

        await _waitForActiveWorkers(service, 1);
        service.cancelAll();

        final newResult = await service.parseMetadata(
          newFile.path,
          config: const IsolateParseConfig(
            timeout: Duration(seconds: 10),
            useGradualRead: false,
            useCache: false,
          ),
        );
        final oldResult = await oldParse;

        expect(oldResult.wasCancelled, isTrue);
        expect(newResult.success, isTrue);
        expect(newResult.metadata?.prompt, 'new-prompt');
      },
    );

    test(
      'dispatches queued tasks after timed-out workers become idle',
      () async {
        final busyA = File('${tempDir.path}/busy_a.png');
        final busyB = File('${tempDir.path}/busy_b.png');
        final queuedFile = File('${tempDir.path}/queued.png');

        await busyA.writeAsBytes(
          await _pngWithNovelAiMetadata(
            prompt: 'busy-a',
            negativePrompt: _largeText('x'),
          ),
        );
        await busyB.writeAsBytes(
          await _pngWithNovelAiMetadata(
            prompt: 'busy-b',
            negativePrompt: _largeText('y'),
          ),
        );
        await queuedFile.writeAsBytes(
          await _pngWithNovelAiMetadata(prompt: 'queued-prompt'),
        );

        final first = service.parseMetadata(
          busyA.path,
          config: const IsolateParseConfig(
            timeout: Duration.zero,
            useGradualRead: false,
            useCache: false,
          ),
        );
        final second = service.parseMetadata(
          busyB.path,
          config: const IsolateParseConfig(
            timeout: Duration.zero,
            useGradualRead: false,
            useCache: false,
          ),
        );

        final queued = service.parseMetadata(
          queuedFile.path,
          config: const IsolateParseConfig(
            timeout: Duration(seconds: 2),
            useGradualRead: false,
            useCache: false,
          ),
        );

        final queuedResult = await queued;
        final timedOutResults = await Future.wait([first, second]);

        expect(queuedResult.success, isTrue);
        expect(queuedResult.metadata?.prompt, 'queued-prompt');
        expect(timedOutResults.every((result) => result.wasTimeout), isTrue);
        expect(timedOutResults.every((result) => result.retryable), isTrue);
        expect(service.getStatistics()['restartedWorkers'], 2);
      },
    );

    test('worker keeps compressed PNG text formats searchable', () async {
      final comment = _novelAiComment(prompt: 'compressed-format-prompt');
      final cases = <String, Uint8List>{
        'ztxt': _pngWithInsertedChunk(
          'zTXt',
          Uint8List.fromList([
            ...latin1.encode('Comment'),
            0,
            0,
            ...ZLibCodec().encode(latin1.encode(comment)),
          ]),
        ),
        'compressed_itxt': _pngWithInsertedChunk(
          'iTXt',
          Uint8List.fromList([
            ...latin1.encode('Comment'),
            0,
            1,
            0,
            0,
            0,
            ...ZLibCodec().encode(utf8.encode(comment)),
          ]),
        ),
      };

      for (final entry in cases.entries) {
        final file = File('${tempDir.path}/${entry.key}.png');
        await file.writeAsBytes(entry.value);

        final result = await service.parseMetadata(
          file.path,
          config: const IsolateParseConfig(
            timeout: Duration(seconds: 2),
            useGradualRead: false,
            useCache: false,
          ),
        );

        expect(result.success, isTrue, reason: entry.key);
        expect(result.metadata?.prompt, 'compressed-format-prompt');
      }
    });

    test('worker falls back to stealth_pngcomp metadata', () async {
      final image = img.Image(width: 64, height: 64, numChannels: 4);
      final basePng = Uint8List.fromList(img.encodePng(image));
      final embedded = await UnifiedMetadataParser.embedMetadata(
        basePng,
        _novelAiComment(prompt: 'stealth-only-prompt'),
        useStealth: true,
      );
      final file = File('${tempDir.path}/stealth_only.png');
      await file.writeAsBytes(_withoutPngTextChunks(embedded));

      final result = await service.parseMetadata(
        file.path,
        config: const IsolateParseConfig(
          timeout: Duration(seconds: 2),
          useGradualRead: false,
          useCache: false,
        ),
      );

      expect(result.success, isTrue);
      expect(result.metadata?.prompt, 'stealth-only-prompt');
    });

    test('coalesces concurrent first initialization', () async {
      final gate = Completer<void>();
      var workerInitializations = 0;
      final concurrentService = IsolateMetadataService.forTesting(
        workerInitializer: (_, initializeWorker) async {
          workerInitializations++;
          if (workerInitializations == 1) {
            await gate.future;
          }
          await initializeWorker();
        },
      );
      addTearDown(concurrentService.dispose);

      final first = concurrentService.initialize();
      final second = concurrentService.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(workerInitializations, 1);
      gate.complete();
      await Future.wait([first, second]);

      expect(workerInitializations, 2);
      expect(concurrentService.getStatistics()['workerCount'], 2);
    });

    test('keeps parsing disabled when worker startup fails', () async {
      final unavailableService = IsolateMetadataService.forTesting(
        maxWorkers: 1,
        workerInitializer: (_, _) async {
          throw StateError('spawn failed');
        },
      );

      addTearDown(unavailableService.dispose);

      await expectLater(unavailableService.initialize(), completes);

      final statistics = unavailableService.getStatistics();
      expect(statistics['fallbackToInlineParsing'], isFalse);
      expect(statistics['workerStartupError'], contains('spawn failed'));
      expect(statistics['reservedWorkerCount'], 0);

      final result = await unavailableService.parseMetadata(
        '${tempDir.path}/missing.png',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Metadata worker unavailable'));
      expect(result.retryable, isTrue);
    });

    test('worker exit before ready releases startup resources', () async {
      final startupService = IsolateMetadataService.forTesting(
        maxWorkers: 1,
        workerEntrypoint: _exitBeforeReady,
        workerStartupTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(startupService.dispose);

      await startupService.initialize();

      final statistics = startupService.getStatistics();
      expect(statistics['workerStartupError'], contains('exited before ready'));
      expect(statistics['workerCount'], 0);
      expect(statistics['reservedWorkerCount'], 0);
    });

    test('worker error before ready wins the startup race', () async {
      final startupService = IsolateMetadataService.forTesting(
        maxWorkers: 1,
        workerEntrypoint: _errorBeforeReady,
        workerStartupTimeout: const Duration(milliseconds: 200),
      );
      addTearDown(startupService.dispose);

      await startupService.initialize();

      final statistics = startupService.getStatistics();
      expect(statistics['workerStartupError'], contains('startup boom'));
      expect(statistics['workerCount'], 0);
      expect(statistics['reservedWorkerCount'], 0);
    });

    test('worker ready timeout releases startup resources', () async {
      final startupService = IsolateMetadataService.forTesting(
        maxWorkers: 1,
        workerEntrypoint: _neverReady,
        workerStartupTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(startupService.dispose);

      await startupService.initialize();

      final statistics = startupService.getStatistics();
      expect(
        statistics['workerStartupError'],
        contains('did not become ready'),
      );
      expect(statistics['workerCount'], 0);
      expect(statistics['reservedWorkerCount'], 0);
    });

    test('retries initialization after a temporary startup failure', () async {
      var startupAttempts = 0;
      final recoveringService = IsolateMetadataService.forTesting(
        maxWorkers: 1,
        workerInitializer: (_, initializeWorker) async {
          startupAttempts++;
          if (startupAttempts == 1) {
            throw StateError('temporary startup failure');
          }
          await initializeWorker();
        },
      );
      addTearDown(recoveringService.dispose);
      final file = File('${tempDir.path}/recovered.png');
      await file.writeAsBytes(
        await _pngWithNovelAiMetadata(prompt: 'recovered-prompt'),
      );

      await recoveringService.initialize();
      final result = await recoveringService.parseMetadata(file.path);

      expect(result.success, isTrue, reason: result.error);
      expect(result.metadata?.prompt, 'recovered-prompt');
      expect(recoveringService.getStatistics()['workerCount'], 1);
      expect(recoveringService.getStatistics()['reservedWorkerCount'], 0);
    });

    test('stale replacements cannot exceed worker capacity', () async {
      final replacementGate = Completer<void>();
      var initializationCalls = 0;
      final racingService = IsolateMetadataService.forTesting(
        maxWorkers: 2,
        workerInitializer: (_, initializeWorker) async {
          initializationCalls++;
          if (initializationCalls == 3 || initializationCalls == 4) {
            await replacementGate.future;
          }
          await initializeWorker();
        },
      );
      addTearDown(racingService.dispose);
      await racingService.initialize();

      final firstFile = File('${tempDir.path}/race_a.png');
      final secondFile = File('${tempDir.path}/race_b.png');
      await firstFile.writeAsBytes(
        await _pngWithNovelAiMetadata(prompt: 'race-a'),
      );
      await secondFile.writeAsBytes(
        await _pngWithNovelAiMetadata(prompt: 'race-b'),
      );

      final results = await Future.wait([
        racingService.parseMetadata(
          firstFile.path,
          config: const IsolateParseConfig(timeout: Duration.zero),
        ),
        racingService.parseMetadata(
          secondFile.path,
          config: const IsolateParseConfig(timeout: Duration.zero),
        ),
      ]);
      expect(results.every((result) => result.wasTimeout), isTrue);
      await _waitForReservedWorkers(racingService, 2);
      await _waitForCondition(
        () => initializationCalls >= 4,
        'Expected both replacement initializers to be waiting',
      );
      expect(racingService.getStatistics()['capacityUsage'], 2);

      racingService.dispose();
      await racingService.initialize();
      expect(racingService.getStatistics()['capacityUsage'], 2);

      replacementGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final statistics = racingService.getStatistics();
      expect(statistics['workerCount'], 2);
      expect(statistics['reservedWorkerCount'], 0);
      expect(statistics['capacityUsage'], lessThanOrEqualTo(2));
    });
  });
}

void _exitBeforeReady(Object? _) {
  Isolate.exit();
}

void _errorBeforeReady(Object? _) {
  throw StateError('startup boom');
}

void _neverReady(Object? _) {
  ReceivePort().listen((_) {});
}

String _novelAiComment({required String prompt}) {
  return jsonEncode({
    'prompt': prompt,
    'uc': '',
    'width': 64,
    'height': 64,
    'seed': 1,
    'steps': 28,
    'scale': 5.0,
    'sampler': 'k_euler',
  });
}

Uint8List _pngWithInsertedChunk(String type, Uint8List data) {
  final image = img.Image(width: 8, height: 8);
  final png = Uint8List.fromList(img.encodePng(image));
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final chunkType = latin1.decode(png.sublist(offset + 4, offset + 8));
    if (chunkType == 'IEND') break;
    offset += 12 + length;
  }

  final lengthBytes = ByteData(4)..setUint32(0, data.length);
  return (BytesBuilder(copy: false)
        ..add(png.sublist(0, offset))
        ..add(lengthBytes.buffer.asUint8List())
        ..add(ascii.encode(type))
        ..add(data)
        ..add(Uint8List(4))
        ..add(png.sublist(offset)))
      .takeBytes();
}

Uint8List _withoutPngTextChunks(Uint8List png) {
  final output = BytesBuilder(copy: false)..add(png.sublist(0, 8));
  var offset = 8;
  while (offset + 12 <= png.length) {
    final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
    final end = offset + 12 + length;
    if (end > png.length) break;
    final type = latin1.decode(png.sublist(offset + 4, offset + 8));
    if (type != 'tEXt' && type != 'zTXt' && type != 'iTXt') {
      output.add(png.sublist(offset, end));
    }
    offset = end;
  }
  return output.takeBytes();
}

String _largeText(String char) => ''.padRight(6 * 1024 * 1024, char);

Future<void> _deleteTempDirectoryWhenWorkersReleaseFiles(
  Directory directory,
) async {
  const attempts = 50;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    if (!await directory.exists()) return;

    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == attempts) {
        // A synchronously killed isolate can retain its Windows file handle
        // until the Dart test process exits, even after onExit is delivered.
        // Hosted runners are ephemeral, so leave that isolated temp directory
        // for the operating system to reclaim at process shutdown.
        if (Platform.isWindows) return;
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

Future<Uint8List> _pngWithNovelAiMetadata({
  required String prompt,
  String negativePrompt = '',
}) async {
  final baseImage = img.Image(width: 8, height: 8);
  final basePng = Uint8List.fromList(img.encodePng(baseImage));
  return UnifiedMetadataParser.embedMetadata(
    basePng,
    jsonEncode({
      'prompt': prompt,
      'uc': negativePrompt,
      'width': 8,
      'height': 8,
      'seed': 1,
      'steps': 28,
      'scale': 5.0,
      'sampler': 'k_euler',
    }),
  );
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

Future<void> _waitForCondition(
  bool Function() condition,
  String failureMessage,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 3)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail(failureMessage);
}

Future<void> _waitForReservedWorkers(
  IsolateMetadataService service,
  int count,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 3)) {
    if ((service.getStatistics()['reservedWorkerCount'] as int) >= count) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected at least $count reserved metadata workers');
}

Future<void> _waitForActiveWorkers(
  IsolateMetadataService service,
  int count,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 3)) {
    if ((service.getStatistics()['activeWorkers'] as int) >= count) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Expected at least $count active metadata workers');
}
