import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_labels.dart';
import 'package:path/path.dart' as p;

void main() {
  group('OnnxTaggerLabelCategory.parse', () {
    test('maps danbooru ids, tagger names and pixai style', () {
      const expectations = {
        '0': OnnxTaggerLabelCategory.general,
        'General': OnnxTaggerLabelCategory.general,
        '4': OnnxTaggerLabelCategory.character,
        'Character': OnnxTaggerLabelCategory.character,
        '3': OnnxTaggerLabelCategory.copyright,
        'Copyright': OnnxTaggerLabelCategory.copyright,
        '1': OnnxTaggerLabelCategory.artist,
        'Artist': OnnxTaggerLabelCategory.artist,
        'style': OnnxTaggerLabelCategory.artist,
        '5': OnnxTaggerLabelCategory.meta,
        'Meta': OnnxTaggerLabelCategory.meta,
        '9': OnnxTaggerLabelCategory.rating,
        'Rating': OnnxTaggerLabelCategory.rating,
        'Quality': OnnxTaggerLabelCategory.other,
        'Model': OnnxTaggerLabelCategory.other,
      };

      for (final MapEntry(key: raw, value: expected) in expectations.entries) {
        expect(OnnxTaggerLabelCategory.parse(raw), expected, reason: raw);
      }
      expect(
        OnnxTaggerLabelCategory.parse(null, name: 'rating:g'),
        OnnxTaggerLabelCategory.rating,
      );
    });

    test('defaults and prompt order follow the online gallery', () {
      expect(OnnxTaggerLabelCategory.defaultPromptCategories, {
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.character,
        OnnxTaggerLabelCategory.copyright,
      });
      expect(OnnxTaggerLabelCategory.promptOrder, [
        OnnxTaggerLabelCategory.artist,
        OnnxTaggerLabelCategory.character,
        OnnxTaggerLabelCategory.copyright,
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.meta,
      ]);
    });
  });

  group('OnnxTaggerLabelFiles.parse', () {
    test('reads the hugging face config split and its thresholds', () {
      final labelSet = OnnxTaggerLabelFiles.parse(
        jsonEncode(_splitTagConfig()),
        extension: 'json',
      );

      expect(labelSet.labels.map((label) => label.name), [
        '1girl',
        'solo',
        'hatsune_miku',
        'vocaloid',
        'kujiran',
        'highres',
        'rating:g',
      ]);
      expect(labelSet.labels.map((label) => label.labelCategory), [
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.character,
        OnnxTaggerLabelCategory.copyright,
        OnnxTaggerLabelCategory.artist,
        OnnxTaggerLabelCategory.meta,
        OnnxTaggerLabelCategory.rating,
      ]);
      expect(labelSet.recommendedThresholds, {
        OnnxTaggerLabelCategory.general: 0.17,
        OnnxTaggerLabelCategory.character: 0.27,
        OnnxTaggerLabelCategory.artist: 0.15,
        OnnxTaggerLabelCategory.copyright: 0.24,
        OnnxTaggerLabelCategory.meta: 0.17,
        OnnxTaggerLabelCategory.rating: 0.41,
      });
    });

    test('rejects a split that does not cover the tag list', () {
      final config = _splitTagConfig()
        ..['tags_split'] = [
          ['general', 2],
          ['character', 1],
        ];

      expect(
        () => OnnxTaggerLabelFiles.parse(jsonEncode(config), extension: 'json'),
        throwsFormatException,
      );
    });

    test('places category offset map tags at their model indexes', () {
      final labelSet = OnnxTaggerLabelFiles.parse(
        jsonEncode(_categoryOffsetMap()),
        extension: 'json',
      );

      expect(labelSet.labels.map((label) => label.name), [
        '1girl',
        'solo',
        'hatsune_miku',
        'kujiran',
        'rating:g',
      ]);
      expect(labelSet.categories, {
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.character,
        OnnxTaggerLabelCategory.artist,
        OnnxTaggerLabelCategory.rating,
      });
      expect(labelSet.recommendedThresholds, isEmpty);
    });

    test('rejects a category offset map that leaves outputs unnamed', () {
      final map = _categoryOffsetMap()..['num_classes'] = 6;

      expect(
        () => OnnxTaggerLabelFiles.parse(jsonEncode(map), extension: 'json'),
        throwsFormatException,
      );
    });

    test('reads pixai category ids from selected_tags.csv', () {
      final labelSet = OnnxTaggerLabelFiles.parse(
        'tag_id,name,category,count\n'
        '0,1girl,0,0\n'
        '1,kujiran,1,0\n'
        '2,vocaloid,3,0\n'
        '3,hatsune_miku,4,0\n'
        '4,highres,5,0\n'
        '5,rating:g,9,0\n',
        extension: 'csv',
      );

      expect(labelSet.labels.map((label) => label.labelCategory), [
        OnnxTaggerLabelCategory.general,
        OnnxTaggerLabelCategory.artist,
        OnnxTaggerLabelCategory.copyright,
        OnnxTaggerLabelCategory.character,
        OnnxTaggerLabelCategory.meta,
        OnnxTaggerLabelCategory.rating,
      ]);
    });

    test('keeps reading plain tag lists as uncategorized labels', () {
      final labelSet = OnnxTaggerLabelFiles.parse(
        jsonEncode({
          'tags': ['1girl', 'solo'],
        }),
        extension: 'json',
      );

      expect(labelSet.labels.map((label) => label.name), ['1girl', 'solo']);
      expect(labelSet.categories, {OnnxTaggerLabelCategory.other});
    });
  });

  group('OnnxTaggerLabelFiles.sniffFormat', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('onnx_label_sniff_');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    Future<String> write(String name, Object json) async {
      final file = File(p.join(directory.path, name));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
      return file.path;
    }

    test('finds tags_split at the end of a large sorted config', () async {
      final config = _splitTagConfig()
        ..['tags'] = [for (var index = 0; index < 4000; index++) 'tag_$index']
        ..['tags_split'] = [
          ['general', 4000],
        ];

      final path = await write('config.json', config);

      expect(await File(path).length(), greaterThan(16 * 1024));
      expect(
        await OnnxTaggerLabelFiles.sniffFormat(path),
        OnnxTaggerLabelFormat.splitTagConfig,
      );
    });

    test('recognizes category offset maps and ignores other json', () async {
      final tagMap = await write('tags.json', _categoryOffsetMap());
      final other = await write('config.json', {'architectures': []});

      expect(
        await OnnxTaggerLabelFiles.sniffFormat(tagMap),
        OnnxTaggerLabelFormat.categoryOffsetMap,
      );
      expect(
        await OnnxTaggerLabelFiles.sniffFormat(other),
        OnnxTaggerLabelFormat.other,
      );
      expect(
        await OnnxTaggerLabelFiles.sniffFormat(
          p.join(directory.path, 'x.json'),
        ),
        OnnxTaggerLabelFormat.other,
      );
    });
  });
}

Map<String, Object?> _splitTagConfig() => {
  'model_type': 'cls_vitdet',
  'num_classes': 7,
  'tags': [
    '1girl',
    'solo',
    'hatsune_miku',
    'vocaloid',
    'kujiran',
    'highres',
    'rating:g',
  ],
  'category_best_threshold': {
    'general': 0.17,
    'character': 0.27,
    'style': 0.15,
    'copyright': 0.24,
    'meta': 0.17,
    'rating': 0.41,
  },
  'tags_best_threshold': null,
  'tags_split': [
    ['general', 2],
    ['character', 1],
    ['copyright', 1],
    ['style', 1],
    ['meta', 1],
    ['rating', 1],
  ],
};

Map<String, Object?> _categoryOffsetMap() => {
  'num_classes': 5,
  'category_order': ['general', 'character', 'style', 'rating'],
  'categories': [
    {
      'name': 'general',
      'offset': 0,
      'count': 2,
      'tags': ['1girl', 'solo'],
    },
    {
      'name': 'character',
      'offset': 2,
      'count': 1,
      'tags': ['hatsune_miku'],
    },
    {
      'name': 'style',
      'offset': 3,
      'count': 1,
      'tags': ['kujiran'],
    },
    {
      'name': 'rating',
      'offset': 4,
      'count': 1,
      'tags': ['rating:g'],
    },
  ],
};
