import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/official_wordlist.dart';
import 'package:nai_launcher/data/services/wordlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String assetContent;

  setUpAll(() async {
    assetContent = await File(officialWordlistAssetPath).readAsString();
  });

  test(
    'loads every official record, array, field, duplicate, and profile',
    () async {
      final service = WordlistService(
        assetBundle: _StringAssetBundle(assetContent),
      );

      await service.loadAllWordlists();

      final data = service.data!;
      expect(data.schemaVersion, officialWordlistSchemaVersion);
      expect(data.totalEntryCount, officialWordlistTotalEntryCount);
      expect(data.generators.length, 3);
      expect(
        data.generators.fold<int>(0, (sum, item) => sum + item.groups.length),
        officialWordlistTotalGroupCount,
      );
      expect(data.sourceFileName, '1741-909f971ef51889d8.js.下载');
      expect(
        data.sourceSha256,
        'e832224acd91d2aec14c9ebd705423b4b909a957a48121d847fe5fe3311317d8',
      );

      for (final type in WordlistType.values) {
        final generator = await service.getOfficialWordlist(type);
        expect(
          generator.entryCount,
          officialWordlistGeneratorEntryCounts[type.generatorId],
        );
        expect(service.getAllEntries(type), hasLength(generator.entryCount));
      }

      final duplicateRecords = data.generatorsById['legacyAnime']!
          .group(r'l$')
          .entries
          .where((entry) => entry.text == 'jaggy lines')
          .toList();
      expect(duplicateRecords, hasLength(2));
      expect(duplicateRecords.map((entry) => entry.raw), [
        ['jaggy lines', 5],
        ['jaggy lines', 5],
      ]);
    },
  );

  test('coalesces concurrent profile loads into one asset read', () async {
    final bundle = _StringAssetBundle(assetContent);
    final service = WordlistService(assetBundle: bundle);

    await Future.wait([
      service.loadWordlist(WordlistType.legacy),
      service.loadWordlist(WordlistType.furry),
      service.loadWordlist(WordlistType.v4),
    ]);

    expect(bundle.loadCount, 1);
  });

  test('rejects mismatched source metadata and generator order', () async {
    final invalidSource = jsonDecode(assetContent) as Map<String, dynamic>;
    (invalidSource['source'] as Map<String, dynamic>)['sha256'] = 'invalid';
    await expectLater(
      WordlistService(
        assetBundle: _StringAssetBundle(jsonEncode(invalidSource)),
      ).loadAllWordlists(),
      throwsA(isA<FormatException>()),
    );

    final reordered = jsonDecode(assetContent) as Map<String, dynamic>;
    final generators = reordered['generators'] as List<dynamic>;
    final first = generators.removeAt(0);
    generators.add(first);
    await expectLater(
      WordlistService(
        assetBundle: _StringAssetBundle(jsonEncode(reordered)),
      ).loadAllWordlists(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects a truncated official asset instead of silently degrading',
    () async {
      final json = jsonDecode(assetContent) as Map<String, dynamic>;
      final generators = json['generators'] as List<dynamic>;
      final firstGenerator = generators.first as Map<String, dynamic>;
      final firstGroup =
          (firstGenerator['groups'] as List<dynamic>).first
              as Map<String, dynamic>;
      (firstGroup['entries'] as List<dynamic>).removeLast();
      final service = WordlistService(
        assetBundle: _StringAssetBundle(jsonEncode(json)),
      );

      await expectLater(
        service.loadAllWordlists(),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.content);

  final String content;
  var loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    final bytes = Uint8List.fromList(utf8.encode(content));
    return ByteData.sublistView(bytes);
  }
}
