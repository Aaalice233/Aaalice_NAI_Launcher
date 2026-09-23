import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_tool_result_file_image.dart';
import 'package:nai_launcher/presentation/widgets/gallery/draggable_image_card.dart';

void main() {
  setUp(agentChatToolResultAspectCache.clear);
  tearDown(() {
    agentChatToolResultAspectCache.clear();
    agentChatToolResultImageResolver = resolveAgentChatToolResultImage;
  });

  group('resolveAgentChatToolResultImage', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('agent_tool_image_');
    });

    tearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    String writePng(String name, {required int width, required int height}) {
      final path = '${directory.path}${Platform.pathSeparator}$name';
      File(path).writeAsBytesSync(
        image_lib.encodePng(image_lib.Image(width: width, height: height)),
      );
      return path;
    }

    test(
      'reads the encoded ratio and file stat of an existing image',
      () async {
        final path = writePng('wide.png', width: 8, height: 2);

        final info = (await resolveAgentChatToolResultImage(path))!;

        expect(info.aspect, 4.0);
        expect(info.record.path, path);
        expect(info.record.size, File(path).lengthSync());
        expect(agentChatToolResultAspectCache.get(path), 4.0);
      },
    );

    test('returns null for a missing path', () async {
      final path = '${directory.path}${Platform.pathSeparator}absent.png';

      expect(await resolveAgentChatToolResultImage(path), isNull);
      expect(agentChatToolResultAspectCache.get(path), isNull);
    });

    test('keeps a stable ratio for a file that is not an image', () async {
      final path = '${directory.path}${Platform.pathSeparator}notes.txt';
      File(path).writeAsStringSync('plain text');

      final info = (await resolveAgentChatToolResultImage(path))!;

      expect(info.aspect, 4 / 3);
    });

    test('reuses the cached ratio instead of reading the header', () async {
      final path = writePng('wide.png', width: 8, height: 2);
      agentChatToolResultAspectCache.put(path, 0.5);

      final info = (await resolveAgentChatToolResultImage(path))!;

      expect(info.aspect, 0.5);
    });
  });

  test('aspect cache drops the oldest entries beyond its bound', () {
    for (var index = 0; index < 300; index++) {
      agentChatToolResultAspectCache.put('path-$index', 1 + index / 100);
    }

    expect(agentChatToolResultAspectCache.size, 256);
    expect(agentChatToolResultAspectCache.get('path-0'), isNull);
    expect(agentChatToolResultAspectCache.get('path-43'), isNull);
    expect(agentChatToolResultAspectCache.get('path-299'), 1 + 299 / 100);
  });

  group('AgentChatToolResultFileImage', () {
    late _RecordingResolver resolver;

    setUp(() {
      resolver = _RecordingResolver();
      agentChatToolResultImageResolver = resolver.call;
    });

    Future<void> pumpCard(WidgetTester tester, String path) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AgentChatToolResultFileImage(
                key: const ValueKey('tool-result-file-image'),
                path: path,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('first frame shows the card before the probe answers', (
      tester,
    ) async {
      await pumpCard(tester, 'a.png');

      expect(find.byType(DraggableImageCard), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(_renderedAspect(tester), 4 / 3);
      expect(_record(tester).path, 'a.png');
      expect(resolver.requestedPaths, ['a.png']);
    });

    testWidgets('a cached ratio is shown before the probe answers', (
      tester,
    ) async {
      agentChatToolResultAspectCache.put('a.png', 2.5);

      await pumpCard(tester, 'a.png');

      expect(_renderedAspect(tester), 2.5);
    });

    testWidgets('the probe result replaces the placeholder record and ratio', (
      tester,
    ) async {
      await pumpCard(tester, 'a.png');

      resolver.complete('a.png', _info('a.png', aspect: 4.0, size: 4096));
      await tester.pumpAndSettle();

      expect(_renderedAspect(tester), 4.0);
      expect(_record(tester).size, 4096);
    });

    testWidgets('a missing file falls back to the not-found hint', (
      tester,
    ) async {
      await pumpCard(tester, 'a.png');

      resolver.complete('a.png', null);
      await tester.pumpAndSettle();

      expect(find.textContaining('找不到图片'), findsOneWidget);
      expect(find.byType(DraggableImageCard), findsNothing);
    });

    testWidgets('a late result for the previous path is discarded', (
      tester,
    ) async {
      await pumpCard(tester, 'a.png');
      await pumpCard(tester, 'b.png');
      expect(resolver.requestedPaths, ['a.png', 'b.png']);

      resolver.complete('b.png', _info('b.png', aspect: 0.25, size: 2048));
      await tester.pumpAndSettle();
      expect(_renderedAspect(tester), 0.25);
      expect(_record(tester).path, 'b.png');

      resolver.complete('a.png', _info('a.png', aspect: 4.0, size: 4096));
      await tester.pumpAndSettle();

      expect(_renderedAspect(tester), 0.25);
      expect(_record(tester).path, 'b.png');
    });

    testWidgets('a late missing result for the previous path is discarded', (
      tester,
    ) async {
      await pumpCard(tester, 'a.png');
      await pumpCard(tester, 'b.png');

      resolver.complete('b.png', _info('b.png', aspect: 0.25, size: 2048));
      resolver.complete('a.png', null);
      await tester.pumpAndSettle();

      expect(find.textContaining('找不到图片'), findsNothing);
      expect(_renderedAspect(tester), 0.25);
    });
  });
}

AgentChatToolResultImageInfo _info(
  String path, {
  required double aspect,
  required int size,
}) {
  return AgentChatToolResultImageInfo(
    record: LocalImageRecord(
      path: path,
      size: size,
      modifiedAt: DateTime.utc(2026, 1, 1),
    ),
    aspect: aspect,
  );
}

double _renderedAspect(WidgetTester tester) {
  return tester
      .widget<AspectRatio>(
        find
            .descendant(
              of: find.byType(AgentChatToolResultFileImage),
              matching: find.byType(AspectRatio),
            )
            .first,
      )
      .aspectRatio;
}

LocalImageRecord _record(WidgetTester tester) =>
    tester.widget<DraggableImageCard>(find.byType(DraggableImageCard)).record;

class _RecordingResolver {
  final requestedPaths = <String>[];
  final _pending = <String, Completer<AgentChatToolResultImageInfo?>>{};

  Future<AgentChatToolResultImageInfo?> call(String path) {
    requestedPaths.add(path);
    return (_pending[path] ??= Completer<AgentChatToolResultImageInfo?>())
        .future;
  }

  void complete(String path, AgentChatToolResultImageInfo? info) {
    (_pending[path] ??= Completer<AgentChatToolResultImageInfo?>()).complete(
      info,
    );
  }
}
