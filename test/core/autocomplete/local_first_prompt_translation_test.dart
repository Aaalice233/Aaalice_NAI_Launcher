import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/local_first_prompt_translation.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';

void main() {
  test('只把本地未命中的标签交给 AI 并按原语法合并结果', () async {
    final delegated = <List<String>>[];
    final pipeline = LocalFirstPromptTranslationPipeline(
      TagTranslationLookup.fromResolver(
        (tags) async => {
          if (tags.contains('masterpiece')) 'masterpiece': '杰作',
          if (tags.contains('worst_quality')) 'worst_quality': '最差质量',
        },
      ),
    );

    final result = await pipeline.translate(
      'masterpiece, 1.2::unknown_tag::, {worst_quality}',
      translateMissing: (tags) async {
        delegated.add(tags);
        return {'unknown_tag': '未知标签'};
      },
    );

    expect(delegated, [
      ['unknown_tag'],
    ]);
    expect(result?.text, '杰作, 1.2::未知标签::, {最差质量}');
    expect(result?.translatedTagCount, 3);
  });

  test('全部本地命中时不会调用 AI', () async {
    var called = false;
    final pipeline = LocalFirstPromptTranslationPipeline(
      TagTranslationLookup.fromResolver((tags) async => {'masterpiece': '杰作'}),
    );

    final result = await pipeline.translate(
      'masterpiece',
      translateMissing: (tags) async {
        called = true;
        return const {};
      },
    );

    expect(called, isFalse);
    expect(result?.text, '杰作');
  });

  test('完整委托未命中项由服务统一拆批调度', () async {
    final batches = <List<String>>[];
    final pipeline = LocalFirstPromptTranslationPipeline(
      TagTranslationLookup.fromResolver((tags) async => const {}),
    );
    final source = List.generate(10, (index) => 'unknown_$index').join(', ');

    final result = await pipeline.translate(
      source,
      translateMissing: (tags) async {
        batches.add(tags);
        return {for (final tag in tags) tag: '译$tag'};
      },
    );

    expect(batches.map((batch) => batch.length), [10]);
    expect(result?.translatedTagCount, 10);
  });

  test('中文输入、非中文目标和普通句子保留原通用翻译流程', () async {
    final pipeline = LocalFirstPromptTranslationPipeline(
      TagTranslationLookup.fromResolver((tags) async => const {}),
    );
    Future<Map<String, String>> unused(List<String> tags) async => const {};

    expect(
      await pipeline.translate('杰作, 女孩', translateMissing: unused),
      isNull,
    );
    expect(
      await pipeline.translate(
        'masterpiece',
        targetLanguage: 'English',
        translateMissing: unused,
      ),
      isNull,
    );
    expect(
      await pipeline.translate(
        'Please translate this sentence!',
        translateMissing: unused,
      ),
      isNull,
    );
  });
}
