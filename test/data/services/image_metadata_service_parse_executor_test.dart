import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_executor.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../helpers/fixed_tag_usage_fixture.dart';
import '../../helpers/stealth_png_fixture.dart';
import '../../helpers/webp_metadata_fixture.dart';

class _MockParseExecutor extends Mock implements MetadataParseExecutor {}

MetadataParseResult _parsed(String prompt) => MetadataParseResult.success(
  NaiImageMetadata(prompt: prompt, width: 2, height: 2),
  'test',
  '{}',
  const ['test'],
);

void _expectSameResult(MetadataParseResult actual, MetadataParseResult sync) {
  expect(actual.success, sync.success);
  expect(actual.sourceFormat, sync.sourceFormat);
  expect(actual.rawData, sync.rawData);
  expect(actual.triedParsers, sync.triedParsers);
  expect(actual.errorMessage, sync.errorMessage);
  expect(actual.metadata, sync.metadata);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late _MockParseExecutor executor;
  final service = ImageMetadataService();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metadata-executor-');
    Hive.init(directory.path);
    await service.initialize();
    service.resetStatistics();
    executor = _MockParseExecutor();
    service.debugSetParseExecutorForTesting(executor);
  });

  tearDown(() async {
    service.debugSetParseExecutorForTesting(null);
    service.clearMemoryCache();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<File> writePng(String name, String prompt) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(await novelAiPngBytes(prompt));
    return file;
  }

  group('file entries hand parsing to the executor', () {
    test('getMetadataImmediate', () async {
      final file = await writePng('immediate.png', 'embedded prompt');
      when(
        () => executor.parseFile(any()),
      ).thenAnswer((_) async => _parsed('from executor'));

      final metadata = await service.getMetadataImmediate(file.path);

      expect(metadata?.prompt, 'from executor');
      verify(() => executor.parseFile(file.path)).called(1);
      verifyNever(() => executor.parseBytes(any()));
    });

    test('getMetadata', () async {
      final file = await writePng('standard.png', 'embedded prompt');
      when(
        () => executor.parseFile(any()),
      ).thenAnswer((_) async => _parsed('from executor'));

      final metadata = await service.getMetadata(file.path);

      expect(metadata?.prompt, 'from executor');
      verify(() => executor.parseFile(file.path)).called(1);
      verifyNever(() => executor.parseBytes(any()));
    });
  });

  group('byte entries hand only the stealth decode to the executor', () {
    test('getMetadataFromBytes', () async {
      final bytes = await stealthOnlyNovelAiPng('stealth bytes');
      when(
        () => executor.parseBytes(any()),
      ).thenAnswer((_) async => _parsed('from executor'));

      final metadata = await service.getMetadataFromBytes(bytes);

      expect(metadata?.prompt, 'from executor');
      verify(() => executor.parseBytes(bytes)).called(1);
      verifyNever(() => executor.parseFile(any()));
    });

    test('getMetadataParseResultFromBytes', () async {
      final bytes = await stealthOnlyNovelAiPng('stealth parse result');
      when(
        () => executor.parseBytes(any()),
      ).thenAnswer((_) async => _parsed('from executor'));

      final result = await service.getMetadataParseResultFromBytes(bytes);

      expect(result.success, isTrue);
      expect(result.metadata?.prompt, 'from executor');
      verify(() => executor.parseBytes(bytes)).called(1);
      verifyNever(() => executor.parseFile(any()));
    });

    test('png text chunks are parsed in place like the sync parser', () async {
      final forMetadata = await novelAiPngBytes('text chunk metadata');
      final forResult = await novelAiPngBytes('text chunk result');

      final metadata = await service.getMetadataFromBytes(forMetadata);
      final result = await service.getMetadataParseResultFromBytes(forResult);

      expect(
        metadata,
        UnifiedMetadataParser.parseFromImage(forMetadata).metadata,
      );
      _expectSameResult(
        result,
        UnifiedMetadataParser.parseFromImage(forResult),
      );
      verifyNever(() => executor.parseBytes(any()));
    });

    test('webp exif is parsed in place like the sync parser', () async {
      final bytes = buildNovelAiWebpFixture(
        comment: const {'prompt': 'webp exif', 'seed': 7, 'steps': 28},
      );

      final result = await service.getMetadataParseResultFromBytes(bytes);

      expect(result.success, isTrue);
      _expectSameResult(result, UnifiedMetadataParser.parseFromImage(bytes));
      verifyNever(() => executor.parseBytes(any()));
    });

    test('the stealth decode matches the sync parser', () async {
      final bytes = await stealthOnlyNovelAiPng('stealth round trip');
      when(() => executor.parseBytes(any())).thenAnswer(
        (invocation) => const MetadataParseExecutor().parseBytes(
          invocation.positionalArguments.single as Uint8List,
        ),
      );

      final result = await service.getMetadataParseResultFromBytes(bytes);

      expect(result.sourceFormat, 'NovelAI stealth_pngcomp');
      _expectSameResult(result, UnifiedMetadataParser.parseFromImage(bytes));
      verify(() => executor.parseBytes(bytes)).called(1);
    });
  });

  test(
    'a parse result is cached so the executor runs once per image',
    () async {
      final file = await writePng('cached.png', 'embedded prompt');
      when(
        () => executor.parseFile(any()),
      ).thenAnswer((_) async => _parsed('from executor'));

      await service.getMetadataImmediate(file.path);
      final again = await service.getMetadataImmediate(file.path);

      expect(again?.prompt, 'from executor');
      verify(() => executor.parseFile(file.path)).called(1);
    },
  );

  test(
    'a joined caller times out while the owner keeps waiting for the parse',
    () async {
      final file = await writePng('slow.png', 'embedded prompt');
      final started = Completer<void>();
      final parse = Completer<MetadataParseResult>();
      when(() => executor.parseFile(any())).thenAnswer((_) {
        started.complete();
        return parse.future;
      });

      var ownerDone = false;
      final owner = service.getMetadata(
        file.path,
        timeout: const Duration(milliseconds: 20),
      )..whenComplete(() => ownerDone = true);
      await started.future;

      final joined = await service.getMetadata(file.path);

      expect(joined, isNull);
      expect(ownerDone, isFalse);
      expect(service.parseStatistics.timeoutParseCount, 1);

      parse.complete(_parsed('late result'));
      expect((await owner)?.prompt, 'late result');
      verify(() => executor.parseFile(file.path)).called(1);
    },
  );

  test('a parse cancelled mid-flight is discarded instead of cached', () async {
    final file = await writePng('cancelled.png', 'embedded prompt');
    final started = Completer<void>();
    final parse = Completer<MetadataParseResult>();
    when(() => executor.parseFile(any())).thenAnswer((_) {
      started.complete();
      return parse.future;
    });
    final token = ParseCancelToken();

    final pending = service.getMetadataImmediate(file.path, cancelToken: token);
    await started.future;
    token.cancel();
    parse.complete(_parsed('discarded'));

    expect(await pending, isNull);
    expect(service.parseStatistics.cancelledParseCount, 1);

    when(
      () => executor.parseFile(any()),
    ).thenAnswer((_) async => _parsed('fresh'));
    expect((await service.getMetadataImmediate(file.path))?.prompt, 'fresh');
    verify(() => executor.parseFile(file.path)).called(2);
  });

  test('an executor failure is recorded without caching', () async {
    final file = await writePng('broken.png', 'embedded prompt');
    when(
      () => executor.parseFile(any()),
    ).thenAnswer((_) async => throw StateError('isolate exited'));

    expect(await service.getMetadataImmediate(file.path), isNull);
    expect(service.parseStatistics.failedParseCount, 1);
  });
}
