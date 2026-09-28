import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/fast_tag_service.dart';
import 'package:nai_launcher/core/autocomplete/tag_catalog_repository.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late TagCatalogRepository catalog;
  late FastTagService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE tags(id INTEGER PRIMARY KEY, name TEXT, category INTEGER, post_count INTEGER);
      CREATE TABLE aliases(id INTEGER PRIMARY KEY, tag_id INTEGER, alias TEXT);
      CREATE VIRTUAL TABLE tag_search USING fts5(term, search_key, tag_id UNINDEXED, kind UNINDEXED);
      CREATE TABLE zh_translations(tag TEXT PRIMARY KEY, zh_cn TEXT NOT NULL, mode INTEGER NOT NULL);
      INSERT INTO tags VALUES (1, 'masterpiece', 0, 1000);
      INSERT INTO tag_search VALUES ('masterpiece', 'masterpiece', 1, 0);
      INSERT INTO zh_translations VALUES ('masterpiece', '杰作', 0);
      INSERT INTO zh_translations VALUES ('extra', '额外', 1);
      INSERT INTO zh_translations VALUES ('worst_quality', '最差质量', 0);
      INSERT INTO zh_translations VALUES ('new_tag', '新标签', 0);
    ''');
    catalog = TagCatalogRepository(database: database);
    service = FastTagService(
      catalog: catalog,
      dictionary: _FakeDictionary({
        'extra': '额外插画',
        'worst_quality': '极差质量',
        'ffdkj_only': '词库翻译',
      }),
    );
  });

  tearDown(() async {
    await catalog.dispose();
  });

  test('中英文前缀都能补全内置标签并直接显示翻译', () async {
    final english = await service.search(_query('mast'));
    final chinese = await service.search(_query('杰'));

    for (final result in [english, chinese]) {
      expect(result.single.canonicalTag, 'masterpiece');
      expect(result.single.translation, '杰作');
    }
    expect(english.single.matchKind, CompletionMatchKind.englishPrefix);
    expect(chinese.single.matchKind, CompletionMatchKind.chinesePrefix);
  });

  test('覆盖项优先，ffdkj 优于普通补充项，缺失项由内置库补齐', () async {
    final result = await service.resolve([
      'extra',
      'worst quality',
      'new_tag',
      'ffdkj_only',
    ], locale: 'zh-CN');

    expect(result, {
      'extra': '额外',
      'worst_quality': '极差质量',
      'new_tag': '新标签',
      'ffdkj_only': '词库翻译',
    });
  });

  test('非中文界面不查询翻译层', () async {
    expect(await service.resolve(['extra'], locale: 'en-US'), isEmpty);
  });

  test('可选 ffdkj 数据库异常时仍保留内置补全与翻译', () async {
    final fallbackService = FastTagService(
      catalog: catalog,
      dictionary: _ThrowingDictionary(),
    );

    expect(
      (await fallbackService.search(_query('杰'))).single.canonicalTag,
      'masterpiece',
    );
    expect(
      await TagTranslationLookup.fromResolver(
        (tags) => fallbackService.resolve(tags, locale: 'zh-CN'),
        fuzzyResolver: fallbackService.resolveFuzzy,
      ).translateBatch(['new_tag', 'unknown_tag']),
      {'new_tag': '新标签'},
    );
  });
}

CompletionQuery _query(String token) => CompletionQuery(
  fullText: token,
  cursorPosition: token.length,
  token: token,
  replacementRange: TextReplacementRange(start: 0, end: token.length),
  existingTags: const {},
  limit: 20,
  locale: 'zh-CN',
);

class _FakeDictionary extends ZhDictionaryService {
  _FakeDictionary(this.values);

  final Map<String, String> values;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async =>
      const [];

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async => {
    for (final tag in canonicalTags)
      if (values[tag] case final value?) tag: value,
  };

  @override
  Future<Map<String, String>> resolveFuzzy(List<String> canonicalTags) async =>
      const {};
}

class _ThrowingDictionary extends ZhDictionaryService {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) =>
      Future.error(StateError('damaged ffdkj database'));

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) => Future.error(StateError('damaged ffdkj database'));

  @override
  Future<Map<String, String>> resolveFuzzy(List<String> canonicalTags) =>
      Future.error(StateError('damaged ffdkj database'));
}
